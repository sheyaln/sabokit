# User Activation Notification Policy
# Sends email and webhook notifications when a user is activated.
#
# Template variables (rendered by Terraform templatefile()):
#   - webhook_url:                   URL for the lifecycle webhook (may be empty)
#   - tools_domain:                  base apps domain (e.g. example.org)
#   - identity_domain:                Authentik gateway hostname (e.g. auth.example.org)
#   - org_name:                      Organization display name
#   - test_mode:                     "True" or "False" — controls recipient set
#   - target_groups_json:            JSON list of group names notified in normal mode
#   - test_target_groups_json:       JSON list of group names notified in test mode
#   - support_contact_instructions:  one-line instruction shown to the user
#   - welcome_message:               welcome line shown to the user

from django.core.mail import send_mail
from django.db import transaction
from authentik.core.models import User, Group, UserSourceConnection
from authentik.events.models import Event
import json
import urllib.request
import urllib.error

# Attribute keys used internally by the notification policies; not forwarded
# to the webhook payload so downstream automations don't see bookkeeping flags.
_INTERNAL_ATTR_KEYS = {
    "activation_notification_sent",
    "enrollment_notification_sent",
    "signup_correlation_id",
    "signup_method",
}

WEBHOOK_URL = "${webhook_url}"

# =============================================================================
# CONFIGURATION
# =============================================================================
# When True, only the admin-tier group(s) are notified (for verifying wiring).
TEST_MODE = ${test_mode}

def send_webhook_notification(event_type, user_data):
    """POST the event to the configured webhook (skipped if no URL)."""
    if not WEBHOOK_URL:
        ak_logger.warning("Webhook URL not configured, skipping webhook notification")
        return False

    payload = {
        "event": event_type,
        "user": user_data,
        "gateway_url": "https://${identity_domain}"
    }

    try:
        data = json.dumps(payload).encode('utf-8')
        req = urllib.request.Request(
            WEBHOOK_URL,
            data=data,
            headers={'Content-Type': 'application/json'}
        )
        urllib.request.urlopen(req, timeout=10)
        ak_logger.info(f"Sent {event_type} webhook notification for {user_data.get('email', 'unknown')}")
        return True
    except Exception as e:
        ak_logger.error(f"Failed to send webhook notification: {e}")
        return False

# Get the event from context - in notification rules, this is passed as the Event object
event = request.context.get("event", None)
if not event:
    ak_logger.debug("No event in context, skipping")
    return False

# Handle both Event model instances and serialized event references
# In notification rules, we may receive a serialized reference that we need to look up
# NOTE: The Event model's 'user' field is a JSONField (dict), not a ForeignKey!
event_action = None
event_context = {}
event_user_info = {}

def extract_user_info_from_dict(user_dict):
    """Extract user info from a dict (Event.user is a JSONField)"""
    if not user_dict or not isinstance(user_dict, dict):
        return {}
    return {
        "email": user_dict.get("email", ""),
        "name": user_dict.get("name", "") or user_dict.get("username", "")
    }

if isinstance(event, Event):
    # Direct Event model instance - user is a JSONField (dict)
    event_action = event.action
    event_context = event.context or {}
    event_user_info = extract_user_info_from_dict(event.user)
elif isinstance(event, dict):
    # Serialized event reference - need to look up the actual event
    event_pk = event.get("pk")
    if event_pk:
        actual_event = Event.objects.filter(pk=event_pk).first()
        if actual_event:
            event_action = actual_event.action
            event_context = actual_event.context or {}
            event_user_info = extract_user_info_from_dict(actual_event.user)
        else:
            ak_logger.warning(f"Could not find event with pk {event_pk}")
            return False
    else:
        ak_logger.warning(f"Event dict has no pk: {event}")
        return False
else:
    # Try to access as object with attributes - user is still a dict
    event_action = getattr(event, 'action', None)
    event_context = getattr(event, 'context', {}) or {}
    event_user_dict = getattr(event, 'user', None)
    event_user_info = extract_user_info_from_dict(event_user_dict)

# Check if the event action is model_updated
if event_action != "model_updated":
    ak_logger.debug(f"Event action is {event_action}, not model_updated, skipping")
    return False

# Check if the model is a user
model_info = event_context.get("model", {})
model_app = model_info.get("app", "")
model_name = model_info.get("model_name", "")

if model_app != "authentik_core" or model_name != "user":
    ak_logger.debug(f"Event model is {model_app}.{model_name}, not authentik_core.user, skipping")
    return False

# Get the user object
user_pk = model_info.get("pk")
if not user_pk:
    ak_logger.warning("No user pk in event model info")
    return False

user = User.objects.filter(pk=user_pk).first()
if not user:
    ak_logger.warning(f"User with pk {user_pk} not found")
    return False

ak_logger.info(f"Processing activation check for user {user.email} (pk={user_pk}, is_active={user.is_active})")

# Check if user is now active
if not user.is_active:
    ak_logger.debug(f"User {user.email} is not active, skipping")
    return False

# Don't send to users without email
if not user.email:
    ak_logger.warning(f"User {user.username} has no email address")
    return False

# Atomically claim the activation lock. Authentik can fire several
# model_updated events in rapid succession when a user is activated
# (the activation save itself plus auxiliary writes such as last_login
# bumps and group syncs); without a row lock both invocations pass a
# naive idempotency check and the workflow fires twice.
#
# Reserve-then-do (at-most-once) is intentional: an extra rare missed
# notification on a transient failure beats spamming admins on every
# activation.
try:
    with transaction.atomic():
        locked = User.objects.select_for_update().get(pk=user_pk)
        if locked.attributes.get("activation_notification_sent", False):
            ak_logger.debug(f"Activation notification already sent for {locked.email}")
            return False
        locked.attributes["activation_notification_sent"] = True
        locked.save()
        user = locked
except Exception as e:
    ak_logger.error(f"Failed to claim activation notification lock for {user.email}: {e}")
    return False

# Get who activated the user from event user info
activated_by = "an administrator"
activated_by_email = ""
if event_user_info.get("email"):
    activated_by = event_user_info.get("name") or event_user_info.get("email")
    activated_by_email = event_user_info.get("email")

# Detect signup method - first check user attributes (set during signup), then source connections
signup_method = "email/password"
login_instruction = ""
try:
    # First, check user attributes (stored during signup notification)
    stored_method = user.attributes.get("signup_method")
    if stored_method:
        signup_method = stored_method
        ak_logger.info(f"Using stored signup method from user attributes: {signup_method}")
    else:
        # Fallback: check source connections
        source_connections = UserSourceConnection.objects.filter(user=user)
        if source_connections.exists():
            source = source_connections.first().source
            signup_method = source.name if source else "social login"
            ak_logger.info(f"Detected signup method from source connection: {signup_method}")
    
    # Set login instruction based on signup method
    if signup_method != "email/password":
        login_instruction = f"\nLog in using {signup_method}."
    else:
        login_instruction = f"\nLog in with your email address: {user.email}"
except Exception as e:
    ak_logger.warning(f"Could not determine signup method: {e}")

user_display = user.name if user.name else user.username

ak_logger.info(f"Sending activation notifications for {user.email} (name={user_display}, activated_by={activated_by})")

# =========================================================================
# 1. SEND EMAIL TO USER (activation confirmation)
# =========================================================================
email_to_user_sent = False
try:
    user_subject = "Your ${org_name} account has been activated"
    user_body = f"""Hello {user_display},

Your account on the ${org_name} Gateway has been activated.

You can now log in at: https://${identity_domain}/{login_instruction}

${support_contact_instructions}

${welcome_message}

--
${org_name} Gateway
"""
    send_mail(
        subject=user_subject,
        message=user_body,
        from_email=None,
        recipient_list=[user.email],
        fail_silently=False
    )
    ak_logger.info(f"Sent activation email to user {user.email}")
    email_to_user_sent = True
except Exception as e:
    ak_logger.error(f"Failed to send activation email to {user.email}: {e}")

# =========================================================================
# 2. SEND EMAIL TO ADMINS/DELEGATES (notification)
# =========================================================================
email_to_admins_sent = False
try:
    admin_recipients = set()
    # Use TEST_MODE to control which groups receive notifications
    notification_groups = ${test_target_groups_json} if TEST_MODE else ${target_groups_json}
    for group_name in notification_groups:
        try:
            group = Group.objects.get(name=group_name)
            for member in group.users.filter(is_active=True):
                if member.email and member.email != user.email:
                    admin_recipients.add(member.email)
        except Group.DoesNotExist:
            pass

    if admin_recipients:
        admin_subject = f"Re: New User Enrollment: {user.email}"
        admin_body = f"""User has been ACTIVATED - no action needed.

Activated User:
  Name: {user_display}
  Email: {user.email}

Activated By: {activated_by}

This user can now log in. No further action required.

--
${org_name} Gateway
"""
        send_mail(
            subject=admin_subject,
            message=admin_body,
            from_email=None,
            recipient_list=list(admin_recipients),
            fail_silently=False
        )
        ak_logger.info(f"Sent activation notification to {len(admin_recipients)} admin-tier recipients")
        email_to_admins_sent = True
except Exception as e:
    ak_logger.error(f"Failed to send admin activation email: {e}")

# =========================================================================
# 3. SEND WEBHOOK NOTIFICATION (independent of email)
# =========================================================================
# Optional thread correlation key carried from the signup notification.
signup_correlation_id = user.attributes.get("signup_correlation_id", "")

custom_attributes = {
    k: v for k, v in (user.attributes or {}).items()
    if k not in _INTERNAL_ATTR_KEYS
}

webhook_sent = send_webhook_notification("user_activation", {
    "email": user.email,
    "username": user.username,
    "name": user_display,
    "signup_method": signup_method,
    "activated_by": activated_by,
    "activated_by_email": activated_by_email,
    "signup_correlation_id": signup_correlation_id,
    "attributes": custom_attributes,
})

ak_logger.info(f"Activation notifications completed for {user.email}: email_user={email_to_user_sent}, email_admins={email_to_admins_sent}, webhook={webhook_sent}")

# Return True to indicate policy passed (doesn't affect notification delivery)
return True
