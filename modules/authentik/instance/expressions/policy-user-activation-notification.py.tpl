# User Activation Notification Policy
# Sends email and Slack notifications when a user is activated
#
# Template variables:
#   - n8n_webhook_url: URL for n8n webhook
#   - tools_domain: Domain for tools (e.g., example.org)
#   - org_name: Organization name
#   - test_mode: "true" or "false" - controls notification recipients

from django.core.mail import send_mail
from authentik.core.models import User, Group, UserSourceConnection
from authentik.events.models import Event
import json
import urllib.request
import urllib.error

N8N_WEBHOOK_URL = "${n8n_webhook_url}"

# =============================================================================
# CONFIGURATION
# =============================================================================
# Set to True to only notify admin group (for testing)
# Set to False to notify both admin and union-delegate groups (production)
TEST_MODE = ${test_mode}

def send_n8n_notification(event_type, user_data):
    """Send Slack notification via n8n webhook (separate from email)"""
    if not N8N_WEBHOOK_URL:
        ak_logger.warning("N8N webhook URL not configured, skipping Slack notification")
        return False
    
    payload = {
        "event": event_type,
        "user": user_data,
        "gateway_url": "https://gateway.${tools_domain}"
    }
    
    try:
        data = json.dumps(payload).encode('utf-8')
        req = urllib.request.Request(
            N8N_WEBHOOK_URL,
            data=data,
            headers={'Content-Type': 'application/json'}
        )
        urllib.request.urlopen(req, timeout=10)
        ak_logger.info(f"Sent {event_type} Slack notification to n8n for {user_data.get('email', 'unknown')}")
        return True
    except Exception as e:
        ak_logger.error(f"Failed to send n8n Slack notification: {e}")
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

# Check if we already sent an activation notification (idempotency)
if user.attributes.get("activation_notification_sent", False):
    ak_logger.debug(f"Activation notification already sent for {user.email}")
    return False

# Don't send to users without email
if not user.email:
    ak_logger.warning(f"User {user.username} has no email address")
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

You can now log in at: https://gateway.${tools_domain}/{login_instruction}

If you have any questions, please contact your union delegate.

Welcome aboard, fellow worker!

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
    notification_groups = ["admin"] if TEST_MODE else ["admin", "union-delegate"]
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
        ak_logger.info(f"Sent activation notification to {len(admin_recipients)} admins/delegates")
        email_to_admins_sent = True
except Exception as e:
    ak_logger.error(f"Failed to send admin activation email: {e}")

# =========================================================================
# 3. SEND SLACK NOTIFICATION VIA N8N (independent of email)
# =========================================================================
# Get slack_thread_ts from user attributes (stored during signup)
slack_thread_ts = user.attributes.get("slack_thread_ts", "")

slack_sent = send_n8n_notification("user_activation", {
    "email": user.email,
    "username": user.username,
    "name": user_display,
    "signup_method": signup_method,
    "activated_by": activated_by,
    "activated_by_email": activated_by_email,
    "slack_thread_ts": slack_thread_ts
})

# Mark as sent if at least one notification succeeded
if email_to_user_sent or email_to_admins_sent or slack_sent:
    user.attributes["activation_notification_sent"] = True
    user.save()
    ak_logger.info(f"Activation notifications completed for {user.email}: email_user={email_to_user_sent}, email_admins={email_to_admins_sent}, slack={slack_sent}")

# Return True to indicate policy passed (doesn't affect notification delivery)
return True
