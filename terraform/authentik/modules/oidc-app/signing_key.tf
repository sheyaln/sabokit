
resource "tls_private_key" "rsa_signing_key" {
  count     = var.generate_rsa_signing_key ? 1 : 0
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_self_signed_cert" "rsa_signing_key" {
  count           = var.generate_rsa_signing_key ? 1 : 0
  private_key_pem = tls_private_key.rsa_signing_key[0].private_key_pem

  subject {
    common_name  = var.gateway_domain
    organization = var.org_name
  }
  allowed_uses          = ["key_encipherment", "digital_signature", "server_auth"]
  validity_period_hours = 48
}

resource "authentik_certificate_key_pair" "rsa_signing_key" {
  count            = var.generate_rsa_signing_key ? 1 : 0
  name             = "${var.application_slug}-rsa-signing-key"
  certificate_data = tls_self_signed_cert.rsa_signing_key[0].cert_pem
  key_data         = tls_private_key.rsa_signing_key[0].private_key_pem
}
