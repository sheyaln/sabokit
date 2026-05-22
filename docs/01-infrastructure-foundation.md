---
layout: default
title: "Part 1: Infrastructure Foundation"
---

# Part 1: Infrastructure Foundation (Terraform Scaleway)

The `terraform-scaleway-infra/` directory contains Terraform code that creates cloud resources: servers, networks, databases, storage, DNS records, and secrets.

## 1.1 Terraform Basics

Terraform is infrastructure-as-code. You describe resources in configuration files, Terraform creates them.

Commands:
```bash
terraform init    # Initialize, download providers, connect to backend
terraform plan    # Preview changes
terraform apply   # Apply changes
```

Run `plan` before `apply`. Read the output.

State is stored in S3:
- Bucket: `{project}-terraform-state-prod-0`
- Key: `scaleway/terraform.tfstate`

## 1.2 Directory Structure

```
terraform-scaleway-infra/
├── main.tf              # Loads secrets module
├── providers.tf         # Provider config, S3 backend
├── variables.tf         # Variable definitions
├── terraform.tfvars     # Variable values
├── outputs.tf           # Exported values
├── compute.tf           # Server instances
├── compute-groups.tf    # Security groups
├── network.tf           # VPC private network
├── storage.tf           # S3 buckets, PostgreSQL
├── dns.tf               # DNS records
├── kubernetes.tf        # K8s cluster (disabled)
├── modules/
│   ├── compute/
│   └── storage/
│       ├── object_bucket/
│       └── postgres/
└── secrets/             # Secret Manager resources
    ├── authentik.tf
    ├── outline.tf
    ├── decidim.tf
    └── [app].tf
```

## 1.3 Servers

### tools-prod

Production applications: Decidim, EspoCRM, Outline, Nextcloud, OnlyOffice, Leantime.

Type: DEV1-L (4 vCPU, 8GB RAM, 50GB SSD)

### management

Monitoring and infrastructure: Grafana, Prometheus, Loki, Zabbix, Wobbler, n8n.

Type: DEV1-M (3 vCPU, 4GB RAM, 40GB SSD)

### authentik-prod

SSO/Identity: Authentik, OAuth2/OIDC provider.

Type: DEV1-M (3 vCPU, 4GB RAM, 30GB SSD)

### Server Definition

In `compute.tf`:

```hcl
module "tools_prod" {
  source = "./modules/compute"

  instance_name      = "tools-prod"
  instance_type      = var.prod_type
  image              = var.image
  disk_size          = 50
  disk_type          = "sbs_volume"
  private_network_id = scaleway_vpc_private_network.main_network.id
  tags               = ["tools", "prod"]
  protected          = true
  security_group_id  = scaleway_instance_security_group.http_ssh_group.id
}
```

## 1.4 Networking

### Private Network

All servers connect via VPC:

```hcl
resource "scaleway_vpc_private_network" "network_prod" {
  name   = "network-prod"
  region = var.region
}
```

Private IPs (assigned by your cloud provider's VPC):
- tools-prod: 10.0.0.3
- management: 10.0.0.5
- authentik-prod: 10.0.0.2

Used for internal communication: metrics scraping, log shipping, database connections.

### Security Groups

In `compute-groups.tf`. Default deny inbound, allow outbound.

Allowed inbound:
- 80, 443: HTTP/HTTPS
- 22: SSH
- 9100: Node Exporter (from management only)
- 8080: cAdvisor (from management only)
- 1514, 1515: Wazuh

## 1.5 PostgreSQL Database

Managed PostgreSQL in `storage.tf`:

```hcl
module "postgres_db" {
  source = "./modules/storage/postgres"

  instance_name     = "{project}-postgres-prod"
  database_engine   = "PostgreSQL-16"
  psql_default_user = "{project}-admin"

  databases = [
    "outline",
    "authentik",
    "nextcloud",
    "onlyoffice",
    "decidim",
    "odoo",
    "zammad",
    "zabbix",
    "n8n",
  ]

  network = {
    enable_ipam = true
    ip_net      = "10.0.0.0/22"
    pn_id       = scaleway_vpc_private_network.main_network.id
    port        = 5432
  }
}
```

The postgres module creates:
1. PostgreSQL instance
2. Database for each name
3. User for each database with random password
4. Secret in Scaleway Secret Manager

Secret name format: `postgres-{dbname}-credentials`

Secret content:
```json
{
  "dbname": "outline",
  "engine": "PostgreSQL-16",
  "username": "outline",
  "password": "generated-password",
  "host": "10.0.0.x",
  "port": "5432"
}
```

Adding a database:
1. Add name to `databases` list
2. Run `terraform apply`
3. Credentials available in Secret Manager

## 1.6 Object Storage

### {project}-appdata-prod-0

Application data. Used by Outline for attachments, Restic for backups.

```hcl
module "appdata_bucket" {
  source = "./modules/storage/object_bucket"
  name   = "{project}-appdata-prod-0"
  acl    = "public-read"
}
```

### {project}-traefik-acme-prod-0

Let's Encrypt certificates. Private.

### {project}-terraform-state-prod-0

Terraform state. Not managed by Terraform.

> Note: Replace `{project}` with your project name prefix throughout.

## 1.7 DNS

In `dns.tf`. Manages your domain zone.

Application records:
```hcl
resource "scaleway_domain_record" "wiki" {
  dns_zone = scaleway_domain_zone.your_domain.id
  name     = "wiki"
  type     = "A"
  data     = module.tools_prod.public_ip  # Or your tools-prod IP
  ttl      = 3600
}
```

Wildcard:
```hcl
resource "scaleway_domain_record" "catch_all" {
  dns_zone = scaleway_domain_zone.your_domain.id
  name     = "*"
  type     = "A"
  data     = module.tools_prod.public_ip  # Or your tools-prod IP
  ttl      = 3600
}
```

Email records (MX, SPF, DKIM, DMARC) for ProtonMail. Don't modify.

Adding a subdomain:
1. Add record in `dns.tf`
2. Run `terraform apply`
3. Wait for propagation

## 1.8 Secrets

The `secrets/` directory creates entries in Scaleway Secret Manager.

Structure:
```hcl
resource "scaleway_secret" "outline_secrets" {
  name        = "outline-secret-key"
  description = "Outline secret key"
  path        = "/apps/outline"
  type        = "opaque"
}
```

Naming conventions:
- `postgres-{app}-credentials`: Database credentials
- `authentik-app-{slug}`: OAuth credentials
- `{app}-secret-key`: Application secrets
- `smtp-config`: Email configuration

Ansible reads secrets:
```yaml
OUTLINE_SECRET_KEY: "{% raw %}{{ lookup('scaleway.scaleway.scaleway_secret', 'outline-secret-key') | b64decode }}{% endraw %}"
```

## 1.9 Variables

`terraform.tfvars` contains configuration:

```hcl
access_key = "SCWxxxxxxxxxx"
secret_key = "xxxxx"
region     = "fr-par"
project_id = "your-project-id"

prod_type       = "DEV1-L"
authentik_type  = "DEV1-M"
management_type = "DEV1-M"

create_staging    = false
create_management = true
create_kubernetes = false
```

This file contains secrets and is gitignored. Copy from `terraform.tfvars.example`.

## 1.10 Common Operations

Initialize:
```bash
terraform init
```

Preview changes:
```bash
terraform plan
```

Apply changes:
```bash
terraform apply
```

View state:
```bash
terraform state list
terraform state show module.tools_prod
```

Import existing resource:
```bash
terraform import scaleway_instance_server.my_server fr-par-1/instance-id
```
