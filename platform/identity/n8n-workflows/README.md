# identity/n8n-workflows

n8n workflow JSONs that implement the **user-onboarding pipeline**. Authentik fires a webhook on user lifecycle events (signup, activation, update, deactivation); the parent dispatcher routes the event to the right downstream subworkflows (Slack notifications + threaded reply, EspoCRM Member upsert, Slack-workspace invite stub, Broadsheet mailing-list subscribe).

Lives in `platform/identity/` (not `platform/apps/n8n/`) because these workflows are **identity-flow concerns**: their inputs are Authentik user events and their outputs span identity, CRM, comms, and email — they're not part of n8n the app, they happen to run on it.

The n8n role does NOT auto-import these. They're versioned JSON artifacts an operator imports once via the n8n UI. The pipeline expects all four to be present.

## Files

| File | Type | Webhook path / Trigger | Calls |
|------|------|------------------------|-------|
| `authentik-user-onboarding.json` | Parent dispatcher | `POST /webhook/authentik-user-onboarding` | All three subworkflows below |
| `broadsheet-allmembers-subscribe.json` | Subworkflow (executeWorkflowTrigger) | called by parent | Broadsheet `/api/lists.*` + `/api/contacts.upsert` |
| `espocrm-member-upsert.json` | Subworkflow (executeWorkflowTrigger) | called by parent | EspoCRM `/api/v1/Member` (GET/POST/PUT) |
| `slack-invite-stub.json` | Subworkflow (executeWorkflowTrigger) | called by parent | no-op (TODO; Slack Free has no invite API) |

## Required env vars

All values come from the n8n container's environment. The n8n bundle takes an `extra_env_vars` map TF input; the consumer-template wires the values from other bundles (broadsheet, espocrm) + consumer-supplied inputs (Slack channels).

| Env var | Provided by | Used by |
|---------|-------------|---------|
| `SLACK_CHANNEL_NEW_SIGNUPS` | consumer var | parent (Slack Signup, Slack Activation) |
| `SLACK_CHANNEL_ADMIN_ALERTS` | consumer var | espocrm-member-upsert (duplicate-member alert) |
| `BROADSHEET_BASE_URL` | broadsheet bundle `app_url` | broadsheet-allmembers-subscribe |
| `BROADSHEET_WORKSPACE_ID` | consumer var | broadsheet-allmembers-subscribe |
| `BROADSHEET_ALL_MEMBERS_LIST_ID` | consumer var (default `allmembers`) | broadsheet-allmembers-subscribe |
| `BROADSHEET_ALL_MEMBERS_LIST_NAME` | consumer var (default `All Members`) | broadsheet-allmembers-subscribe |
| `ESPOCRM_BASE_URL` | espocrm bundle `app_url` | espocrm-member-upsert |
| `WORKFLOW_ID_BROADSHEET_SUBSCRIBE` | post-import, see below | parent (executeWorkflow refs) |
| `WORKFLOW_ID_ESPOCRM_UPSERT` | post-import, see below | parent |
| `WORKFLOW_ID_SLACK_INVITE_STUB` | post-import, see below | parent |

The parent references its subworkflow children by n8n workflow ID via env var. n8n assigns those IDs at import time; the operator captures them after first import and feeds them back to the n8n container's `extra_env_vars` before activating the parent.

## Required n8n credentials

Credentials are referenced by **name** (not ID), so an operator can name their own credential as listed and the workflows will bind without manual rebinding.

| Credential name | Type | Used by |
|-----------------|------|---------|
| `Slack account` | `slackApi` | parent, espocrm-member-upsert |
| `Broadsheet API` | `httpHeaderAuth` (name: `Authorization`, value: `Bearer <JWT>`) | broadsheet-allmembers-subscribe |
| `EspoCRM API` | `httpHeaderAuth` (name: `X-Api-Key`, value: the API key) | espocrm-member-upsert |

The Broadsheet JWT is issued from Broadsheet (Settings → API keys → service account named `n8n` of type `api_key`). The Authentik bundle ships a service-account user that can sign in to Broadsheet via OIDC; create the API-key user there manually.

## Manual import sequence

1. Provision the env vars (consumer-template `extra_env_vars` map + redeploy n8n) BEFORE importing — the Broadsheet subworkflow throws if `BROADSHEET_BASE_URL` is unset.
2. Create the three n8n credentials with the names above.
3. Import the three subworkflows first (in any order):
   - `broadsheet-allmembers-subscribe.json`
   - `espocrm-member-upsert.json`
   - `slack-invite-stub.json`
   Activate each.
4. Capture each subworkflow's ID from the n8n URL after import (`/workflow/<ID>`).
5. Add the three `WORKFLOW_ID_*` env vars to the n8n container's `extra_env_vars` and redeploy.
6. Import `authentik-user-onboarding.json`. Activate. Copy its webhook URL (`/webhook/authentik-user-onboarding`) and set it as the `notification_webhook_url` input on the identity bundle. Redeploy identity TF.

## Webhook payload contract

The identity bundle's `expressions/policy-new-user-notification.py.tpl` and `expressions/policy-user-activation-notification.py.tpl` emit the webhook. Body shape:

```json
{
  "event": "user_signup" | "user_activation" | "user_update" | "user_deactivate",
  "user": {
    "email": "...",
    "username": "...",
    "name": "First Last",
    "signup_method": "email/password" | "google" | ...,
    "needs_activation": true,
    "status": "PENDING ACTIVATION" | "ACTIVE",
    "activated_by": "admin@example.org",
    "activated_by_email": "admin@example.org",
    "signup_correlation_id": "<slack thread ts>",
    "attributes": { "x_number": "...", ... }
  },
  "gateway_url": "https://auth.example.org"
}
```

The parent's `Route By Event` Switch maps `body.event` to one of:

- `user_signup` → Slack top-level post + thread-ts store + Broadsheet subscribe
- `user_activation` → Slack thread reply + EspoCRM upsert + Slack invite stub + Broadsheet subscribe
- `user_update` → silent: EspoCRM upsert + Broadsheet subscribe (no Slack)
- `user_deactivate` → silent: EspoCRM upsert + Broadsheet subscribe (no Slack)
- fallback → silent: EspoCRM upsert + Broadsheet subscribe (defensive — covers unknown new event types without spamming)

## Open items

- **AK side does not yet fire `user_update` or `user_deactivate`.** Today only `user_signup` (from the enrollment-flow prompt-stage policy) and `user_activation` (from the model_updated event rule) reach the webhook. Expanding to `user_update` requires tracking prior state in the activation expression policy and emitting a third event type when `is_active` stays true but attributes/email/name change. `user_deactivate` requires removing the `if not user.is_active: return False` early-return and emitting a fourth event type. Tracked as a follow-up — the parent workflow is already wired to handle them once they arrive.
- **Broadsheet API key user is manual.** Identity bundle could provision it via the Authentik service-account flow + OIDC sign-in into Broadsheet, but that needs Broadsheet to expose an API for issuing API-key JWTs programmatically. Today an operator clicks through Broadsheet's settings UI once.
- **Slack invite stub is a no-op.** Slack Free has no invite API; activate the stub when the org moves to Slack Business+ and replace the no-op Code node with `admin.users.invite`.
