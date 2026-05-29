# Scaleway Transactional Email Management (TEM) — outbound SMTP every app
# sends through. Writes the well-known `smtp-config` Scaleway secret that
# app bundles look up by name (`smtp_secret_name = "smtp-config"`).
#
# Lives in base because (a) every app uses it, (b) it's a managed Scaleway
# product with no host-side runtime — base already owns Scaleway resources.
# See ARCHITECTURE.md → "Tiers" for why it's base-tier vs bootstrap-tier.

locals {
  tem_sender_domain_resolved = var.tem_sender_domain != "" ? var.tem_sender_domain : var.base_domain
  tem_from_email_resolved    = var.tem_from_email != "" ? var.tem_from_email : "notify@${local.tem_sender_domain_resolved}"
  # Scaleway's DNS API rejects "@" as a record name for the zone apex — it
  # wants the empty string. Subdomains keep their label.
  tem_subdomain_label = local.tem_sender_domain_resolved == var.base_domain ? "" : replace(local.tem_sender_domain_resolved, ".${var.base_domain}", "")
  # Suffix to append to composite record names (DKIM, DMARC) so they collapse
  # cleanly at the apex (no trailing dot) instead of producing "...._dmarc.".
  tem_subdomain_suffix = local.tem_subdomain_label == "" ? "" : ".${local.tem_subdomain_label}"
}

resource "scaleway_tem_domain" "this" {
  count = var.tem_enabled ? 1 : 0

  name       = local.tem_sender_domain_resolved
  project_id = var.scaleway_project_id
  region     = var.scaleway_region
  accept_tos = true
}

# DKIM + DMARC records Scaleway TEM emits for the sending domain to pass
# receiver verification. Without these, TEM-sent mail lands in spam or gets
# rejected outright by Gmail/Microsoft/etc.
#
# SPF is intentionally NOT managed here. Real-world SPF needs to combine
# multiple sender includes (TEM + protonmail/sendgrid/etc.) into a single
# TXT record per RFC 7208; emitting a bare TEM-only record collides with
# whatever else the consumer needs to authorize. Consumers compose the
# full SPF via custom_dns_records using the spf_include output.

# DKIM selector is the project_id per Scaleway TEM convention.
# Don't use scaleway_tem_domain.this[0].dkim_name — despite its docstring it
# returns the full FQDN with trailing dot (e.g.
# "<project_id>._domainkey.example.org."), which when concatenated with the
# _domainkey suffix produces a malformed "<fqdn>.._domainkey" record name
# and forces replacement on every plan. v3.1.5 regression.
resource "scaleway_domain_record" "tem_dkim" {
  count = var.tem_enabled ? 1 : 0

  dns_zone = var.base_domain
  name     = "${var.scaleway_project_id}._domainkey${local.tem_subdomain_suffix}"
  type     = "TXT"
  data     = scaleway_tem_domain.this[0].dkim_config
  ttl      = 3600
}

resource "scaleway_domain_record" "tem_dmarc" {
  count = var.tem_enabled ? 1 : 0

  dns_zone = var.base_domain
  name     = "_dmarc${local.tem_subdomain_suffix}"
  type     = "TXT"
  data     = var.dmarc_rua_email != "" ? "v=DMARC1; p=quarantine; rua=mailto:${var.dmarc_rua_email}" : "v=DMARC1; p=quarantine"
  ttl      = 3600
}

# TEM-scoped API key. Scaleway's TEM SMTP auth uses this as the password
# (username = project_id). Stored alongside the connection info in the
# smtp-config secret apps read.

resource "scaleway_iam_application" "tem" {
  count = var.tem_enabled ? 1 : 0

  name        = "${local.name_suffix}-tem"
  description = "Scaleway TEM application for sabokit outbound SMTP"
  tags        = ["automated", "tem"]
}

resource "scaleway_iam_policy" "tem" {
  count = var.tem_enabled ? 1 : 0

  name           = "${local.name_suffix}-tem"
  description    = "Allow TEM send + management on the sabokit project"
  application_id = scaleway_iam_application.tem[0].id
  rule {
    project_ids          = [var.scaleway_project_id]
    permission_set_names = ["TransactionalEmailEmailFullAccess"]
  }
}

resource "scaleway_iam_api_key" "tem" {
  count = var.tem_enabled ? 1 : 0

  application_id     = scaleway_iam_application.tem[0].id
  description        = "TEM SMTP password for sabokit apps"
  default_project_id = var.scaleway_project_id
}

resource "scaleway_secret" "smtp_config" {
  count = var.tem_enabled ? 1 : 0

  name        = var.tem_smtp_config_secret_name
  description = "Outbound SMTP credentials apps consume by name. Written by base from Scaleway TEM."
  tags        = ["automated", "tem", "smtp-config"]
  type        = "key_value"
  project_id  = var.scaleway_project_id
}

resource "scaleway_secret_version" "smtp_config" {
  count = var.tem_enabled ? 1 : 0

  secret_id = scaleway_secret.smtp_config[0].id
  data = jsonencode({
    # TEM SMTP endpoint: implicit SSL on port 2465 — the transport sabokit uses.
    # (2587 = STARTTLS; not used. Authentik's SMTP client raises SSLError
    # WRONG_VERSION_NUMBER doing implicit SSL on a STARTTLS port — see
    # platform/identity/terraform/flows/*.tf which set use_ssl=true.) use_ssl +
    # use_tls are explicit string booleans so every consumer maps the same
    # transport. Stringified — the Scaleway secret store validates strings.
    host       = "smtp.tem.scaleway.com"
    port       = "2465"
    use_ssl    = "true"
    use_tls    = "false"
    username   = var.scaleway_project_id
    password   = scaleway_iam_api_key.tem[0].secret_key
    domain     = local.tem_sender_domain_resolved
    from_email = local.tem_from_email_resolved
  })

  lifecycle {
    # Scaleway's API doesn't return secret values on read; after `terraform
    # import` the refreshed `data` is null and re-render looks like a
    # forces_replacement diff. Lock the version. Rotate the TEM key by
    # tainting scaleway_iam_api_key.tem AND this resource together.
    ignore_changes = [data]
  }
}

locals {
  smtp_config_secret_id = var.tem_enabled ? scaleway_secret.smtp_config[0].id : null
}
