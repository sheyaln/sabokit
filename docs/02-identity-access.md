---
layout: default
title: "Part 2: Identity & Access"
---

# Part 2: Identity & Access (Terraform Authentik)

The `terraform-authentik/` directory configures Authentik, the SSO/identity provider. It defines applications, authentication flows, user groups, and stores OAuth credentials in Scaleway.

## 2.1 Key Concepts

### What is SSO?

SSO (Single Sign-On) means users log in once and get access to multiple applications without logging in again. Instead of each application having its own username/password database, they all delegate authentication to a central identity provider.

Benefits:
- Users remember one password
- Admins manage users in one place
- Revoking access is instant across all apps
- Consistent security policies

### What is Terraform?

Terraform is a tool that lets you define infrastructure using text files instead of clicking through web interfaces.

Without Terraform (ClickOps):
1. Open Authentik admin panel
2. Click "Create Application"
3. Fill out form fields
4. Click save
5. Repeat for each application
6. No record of what you did
7. Hard to replicate or recover

With Terraform:
1. Write configuration in a `.tf` file
2. Run `terraform apply`
3. Terraform creates everything
4. Configuration is version-controlled
5. Can recreate identical setup anytime
6. Changes are auditable

The tradeoff: Terraform has a learning curve, but once set up, it's faster and more reliable than clicking through UIs.

### OAuth2/OIDC

OAuth2 is a protocol that lets applications authenticate users through a third party. OIDC (OpenID Connect) is built on top of OAuth2 and adds user identity information.

Flow:
1. User visits application
2. Application redirects to Authentik
3. User logs in to Authentik
4. Authentik redirects back with a token
5. Application uses token to identify user

## 2.2 What Authentik Does

Authentik is a self-hosted identity provider. It handles:

- User authentication (login)
- User management (create, disable accounts)
- Group management (admin, member, etc.)
- OAuth2/OIDC provider for applications
- SAML provider for enterprise applications
- Social login (Google, Apple)

URL: https://gateway.example.org

Admin panel: https://gateway.example.org/if/admin/

## 2.3 Directory Structure

```
terraform-authentik/
├── providers.tf         # Terraform provider configuration
├── variables.tf         # Input variable definitions
├── terraform.tfvars     # Actual variable values (contains secrets)
├── apps.tf              # Application definitions
├── user-groups.tf       # User groups
├── roles.tf             # RBAC roles
├── auth-sources.tf      # Social login (Google, Apple)
├── brand.tf             # Logo, colors, branding
├── flows/               # Authentication flows
│   ├── authentication-stages.tf
│   ├── flow-source-enrollment.tf
│   ├── flow-manual-enrollment.tf
│   ├── flow-email-password-reset.tf
│   └── ...
├── modules/
│   ├── app/             # Reusable module for creating apps
│   └── bookmark/        # Module for external links
└── outputs.tf
```

## 2.4 User Groups

Groups control who can access what. Defined in `user-groups.tf` and `roles.tf`.

### admin

```hcl
resource "authentik_group" "admin" {
  name         = "admin"
  is_superuser = true
}
```

Infrastructure administrators. Full access to everything including Authentik admin panel.

### union-delegate

Defined in `roles.tf`. Organization leadership. Can access most applications, can manage users in Authentik.

### union-secretary-treasurer

```hcl
resource "authentik_group" "union_treasurer" {
  name         = "union-secretary-treasurer"
  is_superuser = false
}
```

Financial access.

### union-member

```hcl
resource "authentik_group" "union_member" {
  name         = "union-member"
  is_superuser = false
}
```

Standard members. Basic application access.

## 2.5 Access Levels

Applications have access levels. The module uses these to determine which groups can access:

| Level | Groups with Access |
|-------|-------------------|
| admin | admin only |
| delegate | admin, union-delegate |
| treasurer | admin, union-delegate, union-secretary-treasurer |
| member | all groups |

## 2.6 Applications

Defined in `apps.tf`. Each application uses the `app` module.

### Current Applications

| Application | Slug | Access Level | Type |
|-------------|------|--------------|------|
| Wiki - Outline | outline | member | OAuth2 |
| Grafana | grafana | delegate | OAuth2 |
| Sabo Cloud (Nextcloud) | sabo-cloud | member | OAuth2 |
| Member Tracking System | espocrm | delegate | OAuth2 |
| Wobbler | wobbler | delegate | OAuth2 |
| Zabbix | zabbix | admin | Bookmark |
| Solidarity Fund | solidarity_fund | member | Bookmark |
| Disbursement Request | disbursement_request | member | Bookmark |

### Example: Outline

```hcl
module "outline" {
  source = "./modules/app"

  application_name = "Wiki - Outline"
  application_slug = "outline"
  
  provider_type = "oauth2"
  redirect_uris = [
    {
      url = "https://wiki.example.org/auth/oidc.callback"
    }
  ]
  access_level = "member"

  oauth2_scopes = ["openid", "profile", "email", "groups", "offline_access"]

  authentication_flow_uuid = module.flows.authentication_flow_default_login
  authorization_flow_uuid  = module.flows.default_provider_authorization_implicit_consent_id
  invalidation_flow_uuid   = module.flows.default_invalidation_flow_id

  icon_name = "application-icons/outline-icon.png"

  group_ids = {
    admin           = authentik_group.admin.id
    union_delegate  = authentik_group.union_delegate.id
    union_member    = authentik_group.union_member.id
    union_treasurer = authentik_group.union_treasurer.id
  }
}
```

### Bookmark Applications

For external links that appear in the Authentik portal but don't need SSO:

```hcl
module "zabbix" {
  source = "./modules/bookmark"

  application_name = "Zabbix"
  application_slug = "zabbix"
  launch_url       = "https://zabbix.example.cc"
  access_level     = "admin"
  icon_name         = "application-icons/zabbix-icon.png"
  # ...
}
```

## 2.7 The App Module

Located at `modules/app/`. When you add an application, the module:

1. Creates an OAuth2 provider in Authentik
2. Creates the application entry
3. Sets up access policies based on groups
4. Generates a client ID and client secret
5. Stores credentials in Scaleway Secret Manager

### Credential Storage

The module stores credentials in Scaleway automatically:

Secret name: `authentik-app-{slug}`

Content:
```json
{
  "client_id": "generated-uuid",
  "client_secret": "generated-password",
  "scopes": "openid,profile,email,groups"
}
```

Ansible retrieves these when deploying applications:
```yaml
OIDC_CLIENT_ID: "{% raw %}{{ (lookup('scaleway.scaleway.scaleway_secret', 'authentik-app-outline') | b64decode | from_json).client_id }}{% endraw %}"
```

## 2.8 Authentication Flows

Flows define the login process. Located in `flows/`.

### Main Login Flow

The active flow uses `username_passkey_identification` stage:

1. User enters email
2. Social login buttons shown (Google, Apple)
3. Password authentication
4. Session created (30 days)

### Source Enrollment Flow

Handles new users from social login:

1. User clicks "Sign in with Google"
2. Google authenticates user
3. Authentik creates account (inactive by default)
4. User sees welcome message
5. Delegate must activate the account

Users created via social login are inactive until a delegate activates them in the admin panel.

### Password Reset Flow

1. User clicks "Forgot password"
2. Enters email
3. Receives reset link
4. Sets new password

## 2.9 Social Login

Configured in `auth-sources.tf`. Supports Google and Apple sign-in.

Credentials in `terraform.tfvars`:
```hcl
google_client_id     = "xxxxx.apps.googleusercontent.com"
google_client_secret = "GOCSPX-xxxxx"

apple_client_id     = "com.example.oauth"
apple_client_secret = "-----BEGIN PRIVATE KEY-----..."
```

See Appendix A for how to obtain these credentials.

## 2.10 Adding a New Application

1. Add module in `apps.tf`:

```hcl
module "myapp" {
  source = "./modules/app"

  application_name = "My App"
  application_slug = "myapp"
  
  provider_type = "oauth2"
  redirect_uris = [
    {
      url = "https://myapp.example.org/auth/callback"
    }
  ]
  access_level = "member"

  oauth2_scopes = ["openid", "profile", "email"]

  authentication_flow_uuid = module.flows.authentication_flow_default_login
  authorization_flow_uuid  = module.flows.default_provider_authorization_implicit_consent_id
  invalidation_flow_uuid   = module.flows.default_invalidation_flow_id

  group_ids = {
    admin           = authentik_group.admin.id
    union_delegate  = authentik_group.union_delegate.id
    union_member    = authentik_group.union_member.id
    union_treasurer = authentik_group.union_treasurer.id
  }
}
```

2. Run:
```bash
cd terraform-authentik
terraform plan
terraform apply
```

3. Credentials are now in Scaleway as `authentik-app-myapp`

4. Configure your application's Ansible role to read credentials (see Part 3)

## 2.11 Variables

`terraform.tfvars` contains configuration values:

```hcl
scaleway_access_key = "xxxxx"
scaleway_secret_key = "xxxxx"

authentik_url   = "https://gateway.example.org"
authentik_token = "xxxxx"

smtp_host     = "smtp.tem.scaleway.com"
smtp_port     = "587"
smtp_username = "xxxxx"
smtp_password = "xxxxx"

google_client_id     = "xxxxx"
google_client_secret = "xxxxx"

apple_client_id     = "xxxxx"
apple_client_secret = "xxxxx"
```

The `authentik_token` is an API token from Authentik admin panel (Directory > Tokens and App passwords).

## 2.12 OIDC Endpoints

Applications use these endpoints to communicate with Authentik:

| Endpoint | URL |
|----------|-----|
| Authorization | https://gateway.example.org/application/o/authorize/ |
| Token | https://gateway.example.org/application/o/token/ |
| Userinfo | https://gateway.example.org/application/o/userinfo/ |
| End Session | https://gateway.example.org/application/o/{slug}/end-session/ |
| Discovery | https://gateway.example.org/application/o/{slug}/.well-known/openid-configuration |

The discovery URL returns all endpoints and configuration. Most OIDC libraries can auto-configure from it.

## 2.13 Common Operations

### Apply Configuration Changes

```bash
cd terraform-authentik
terraform plan    # Review changes
terraform apply   # Apply changes
```

### Get API Token

1. Go to https://gateway.example.org/if/admin/
2. Directory > Tokens and App passwords
3. Create token

### Disable an Application

Comment out or remove the module in `apps.tf`, run `terraform apply`.

### Create a User Manually

1. Go to https://gateway.example.org/if/admin/
2. Directory > Users > Create
3. Set email, name
4. Assign to group(s)
5. Save

---

## Appendix A: Obtaining Social Login Credentials

### Google OAuth Credentials

1. Go to https://console.cloud.google.com/
2. Create a project or select existing
3. APIs & Services > Credentials
4. Create Credentials > OAuth client ID
5. Application type: Web application
6. Authorized redirect URIs: `https://gateway.example.org/source/oauth/callback/google/`
7. Copy Client ID and Client Secret

Documentation: https://developers.google.com/identity/protocols/oauth2

### Apple Sign In Credentials

Apple Sign In is more complex. You need:
- Apple Developer account ($99/year)
- App ID with Sign In with Apple capability
- Service ID
- Private key

1. Go to https://developer.apple.com/
2. Certificates, Identifiers & Profiles
3. Create App ID with Sign In with Apple
4. Create Service ID, configure domain and redirect URL
5. Create private key for Sign In with Apple

Redirect URI: `https://gateway.example.org/source/oauth/callback/apple/`

Documentation: https://developer.apple.com/sign-in-with-apple/get-started/

The `apple_client_id` format is typically: `com.example.app` (your Service ID)
The `apple_client_secret` is a JWT signed with your private key. Authentik can generate this from the private key.
