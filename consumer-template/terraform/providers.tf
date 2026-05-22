provider "scaleway" {
  access_key = var.scaleway_access_key
  secret_key = var.scaleway_secret_key
  region     = var.scaleway_region
  zone       = var.scaleway_zone
  project_id = var.scaleway_project_id
}

provider "authentik" {
  url   = "https://${var.gateway_domain}"
  token = var.authentik_admin_token
}
