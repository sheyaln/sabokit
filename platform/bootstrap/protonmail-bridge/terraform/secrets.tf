# Read the consumer-provided bridge service password and write the
# imap-config secret apps consume. This is the bootstrap-tier contract:
# apps that fetch mail (typically n8n workflows polling an inbox) read
# imap-config and trust whatever this writes.

data "scaleway_secret" "bridge_login" {
  count     = var.enabled ? 1 : 0
  secret_id = var.bridge_login_secret_id
}

data "scaleway_secret_version" "bridge_login" {
  count     = var.enabled ? 1 : 0
  secret_id = data.scaleway_secret.bridge_login[0].id
  revision  = "latest"
}

resource "scaleway_secret" "imap_config" {
  count       = var.enabled ? 1 : 0
  name        = var.imap_config_secret_name
  description = "IMAP credentials apps consume. Written by the active bootstrap-mail-imap bundle."
  tags        = ["automated", local.slug, "bootstrap-mail-imap"]
  type        = "key_value"
}

resource "scaleway_secret_version" "imap_config" {
  count = var.enabled ? 1 : 0

  secret_id = scaleway_secret.imap_config[0].id
  data = jsonencode({
    # Bridge container hostname on the shared docker network. shenxn image
    # listens on 143 (IMAP) internally.
    host     = "protonmail-bridge"
    port     = 143
    username = var.imap_username
    password = data.scaleway_secret_version.bridge_login[0].data
    use_tls  = "starttls"
  })

  lifecycle {
    # Scaleway's API doesn't return secret values on read; after `terraform
    # import` the refreshed `data` is null and re-render forces replacement.
    # Lock the version. Rotate by tainting this resource.
    ignore_changes = [data]
  }
}
