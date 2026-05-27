# Identity bootstrap — secrets + database that must exist BEFORE Authentik
# starts. See platform/identity/bootstrap/README.md for the full apply-order
# story.
#
# This is a separate module call (not folded into identity.tf) because the
# goauthentik/authentik provider in identity.tf can't function until the
# Authentik container is up and reachable. Splitting the bootstrap into its
# own root-level dependency lets deploy.sh `-target=` it in an early phase.

module "identity_bootstrap" {
  source = "git::https://github.com/sheyaln/sabokit.git//platform/identity/bootstrap?ref=v3.5.0"

  org_slug    = var.org_slug
  environment = var.environment
  infra_email = var.infra_email

  postgres_instance_id = module.base.scaleway.postgres_instance_id
  postgres_endpoint    = module.base.scaleway.postgres_endpoint
  postgres_engine      = module.base.scaleway.postgres_engine


  # Optional out-of-band secrets the authentik-server role reads. Operators
  # provision the underlying Scaleway secrets (S3 creds, SMTP creds) themselves
  # and pass the IDs here; empty (default) leaves the corresponding Authentik
  # feature off. See platform/identity/bootstrap/README.md.
  media_s3_secret_id = try(var.identity.media_s3_secret_id, "")
  smtp_secret_id     = try(var.identity.smtp_secret_id, "")
}
