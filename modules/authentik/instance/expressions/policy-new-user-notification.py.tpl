# New User Notification Policy
# Sends email and Slack notifications when a new user signs up
#
# Template variables:
#   - n8n_webhook_url: URL for n8n webhook
#   - domain: Domain for tools (e.g., example.org)
#   - organisation_name: Organization name

from django.core.mail import send_mail
from authentik.core.models import Group, UserSourceConnection
import json
import urllib.request
import urllib.error

N8N_WEBHOOK_URL = "${n8n_webhook_url}"

def send_n8n_notification(event_type, user_data):
    """Send notification to n8n webhook which handles Slack threading.
    Returns the response JSON which includes thread_ts for signup events."""
    if not N8N_WEBHOOK_URL:
        ak_logger.warning("N8N webhook URL not configured")
        return None
    
    payload = {
        "event": event_type,
        "user": user_data,
        "gateway_url": "https://gateway.${domain}"
    }
    
    try:
        data = json.dumps(payload).encode('utf-8')
        req = urllib.request.Request(
            N8N_WEBHOOK_URL,
            data=data,
            headers={'Content-Type': 'application/json'}
        )
        response = urllib.request.urlopen(req, timeout=10)
        response_body = response.read().decode('utf-8')
        ak_logger.info(f"Sent {event_type} notification to n8n")
        
        # Try to parse response as JSON to get thread_ts
        try:
            return json.loads(response_body)
        except:
            return None
    except Exception as e:
        ak_logger.error(f"Failed to send n8n notification: {e}")
        return None

# Resolve user from various possible context locations
# In enrollment flows, the user is stored in flow_plan context after user_write stage
user = None

# Try request.context first (where flow plan stores pending_user)
if hasattr(request, 'context') and request.context:
    user = request.context.get('pending_user')
    if not user:
        user = request.context.get('user')

# Try direct context (passed to policy)
if not user:
    user = context.get('pending_user')
if not user:
    user = context.get('user')

# Try request.user (authenticated user)
if not user:
    req_user = getattr(request, 'user', None)
    if req_user and hasattr(req_user, 'email') and req_user.email:
        user = req_user

# If we still don't have a valid user, log what we see and abort
if not user or not hasattr(user, 'email') or not user.email:
    ak_logger.warning(f"No valid user found in context for notification. context keys: {list(context.keys())}, request.context: {getattr(request, 'context', {}).keys() if hasattr(request, 'context') else 'none'}")
    return True

# Idempotency check - prevent duplicate notifications
if user.attributes.get("enrollment_notification_sent", False):
    ak_logger.debug(f"Enrollment notification already sent for {user.email}")
    return True

# Get user details
user_email = user.email
user_username = user.username
user_name = getattr(user, 'name', user_username)

# Detect signup method - check multiple sources
signup_method = "email/password"
try:
    # First, check flow context for OAuth/SSO source (most reliable during signup)
    if hasattr(request, 'context') and request.context:
        # Check for is_sso flag
        if request.context.get('is_sso'):
            source_info = request.context.get('source', {})
            if isinstance(source_info, dict):
                signup_method = source_info.get('name', 'social login')
            elif hasattr(source_info, 'name'):
                signup_method = source_info.name
            else:
                signup_method = "social login"
            ak_logger.info(f"Detected OAuth signup from flow context: {signup_method}")
    
    # Fallback: check UserSourceConnection (may not exist yet during signup)
    if signup_method == "email/password":
        source_connections = UserSourceConnection.objects.filter(user=user)
        if source_connections.exists():
            source = source_connections.first().source
            signup_method = source.name if source else "social login"
            ak_logger.info(f"Detected signup method from source connection: {signup_method}")
    
    # Store signup method in user attributes for later use (activation notification)
    user.attributes["signup_method"] = signup_method
except Exception as e:
    ak_logger.warning(f"Could not determine signup method: {e}")

# Check if user needs activation (inactive = needs approval)
needs_activation = not user.is_active
status_text = "PENDING ACTIVATION" if needs_activation else "ACTIVE"

# Prepare email
subject = f"New User Enrollment: {user_email}"
body = f"""A new user has enrolled in the ${organisation_name} platform.

Name: {user_name}
Username: {user_username}
Email: {user_email}
Signup Method: {signup_method}
Status: {status_text}

{"Please review this user and activate their account if appropriate." if needs_activation else "User is already active."}

You can manage users at: https://gateway.${domain}/if/admin/#/identity/users
"""

# =========================================================================
# 1. SEND EMAIL TO ADMINS/DELEGATES (independent of Slack)
# =========================================================================
email_sent = False
try:
    recipients = set()
    target_groups = ["admin", "union-delegate"]

    for group_name in target_groups:
        try:
            group = Group.objects.get(name=group_name)
            for member in group.users.filter(is_active=True):
                if member.email:
                    recipients.add(member.email)
        except Group.DoesNotExist:
            ak_logger.warning(f"Group {group_name} not found when sending notifications")

    if recipients:
        send_mail(
            subject=subject,
            message=body,
            from_email=None,
            recipient_list=list(recipients),
            fail_silently=False
        )
        ak_logger.info(f"Sent enrollment email for {user_email} to {len(recipients)} recipients")
        email_sent = True
    else:
        ak_logger.warning("No recipients found for new user notification email")
except Exception as e:
    ak_logger.error(f"Failed to send enrollment email for {user_email}: {e}")

# =========================================================================
# 2. SEND SLACK NOTIFICATION VIA N8N (independent of email)
# =========================================================================
slack_sent = False
slack_thread_ts = None
try:
    n8n_response = send_n8n_notification("user_signup", {
        "email": user_email,
        "username": user_username,
        "name": user_name,
        "signup_method": signup_method,
        "needs_activation": needs_activation,
        "status": status_text
    })
    slack_sent = True
    
    # Extract thread_ts from n8n response and store in user attributes
    # This allows activation notifications to reply to the original thread
    if n8n_response and isinstance(n8n_response, dict):
        slack_thread_ts = n8n_response.get("thread_ts") or n8n_response.get("threadTs")
        if slack_thread_ts:
            user.attributes["slack_thread_ts"] = slack_thread_ts
            ak_logger.info(f"Stored Slack thread_ts {slack_thread_ts} for {user_email}")
except Exception as e:
    ak_logger.error(f"Failed to send Slack notification for {user_email}: {e}")

# Mark notification as sent if at least one succeeded
if email_sent or slack_sent:
    user.attributes["enrollment_notification_sent"] = True
    user.save()
    ak_logger.info(f"Enrollment notifications sent for {user_email}: email={email_sent}, slack={slack_sent}")

return True
