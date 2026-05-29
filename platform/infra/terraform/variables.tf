# ── Scaleway scope ──────────────────────────────────────────────────────────

variable "scaleway_project_id" {
  description = "Scaleway project ID. Everything this module creates lands in this project."
  type        = string
}

variable "scaleway_region" {
  description = "Scaleway region for regional resources (RDB, object storage, secrets)."
  type        = string
  default     = "fr-par"
}

variable "scaleway_zone" {
  description = "Scaleway zone for zonal resources (compute instances)."
  type        = string
  default     = "fr-par-1"
}

# ── Naming / tagging ────────────────────────────────────────────────────────

variable "org_slug" {
  description = "Short URL-safe slug used to name resources (e.g. \"acme\", \"fc\"). Keep it short — appears in instance names, bucket names, secret names."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,15}$", var.org_slug))
    error_message = "org_slug must be 2-16 lowercase letters/digits/hyphens and start with a letter."
  }
}

variable "environment" {
  description = "Short environment label used as a name suffix (\"prod\", \"staging\", \"dev\"). Resources are not isolated by this — it's just naming."
  type        = string
  default     = "prod"
}

variable "tags" {
  description = "Tags applied to every taggable resource."
  type        = list(string)
  default     = []
}

# ── Domains (pass-through to outputs; not used by Scaleway directly) ────────

variable "base_domain" {
  description = "Primary apps domain (e.g. \"example.org\"). Apps use this in their hostname inputs."
  type        = string
}

variable "mgmt_domain" {
  description = "Management apps domain (e.g. \"ops.example.org\"). Set equal to base_domain when there's no separate management host."
  type        = string
  default     = null
}

variable "identity_domain" {
  description = "Hostname of the Authentik gateway (e.g. \"auth.example.org\"). Used by base/authentik/."
  type        = string
  default     = null
}

# ── Network ─────────────────────────────────────────────────────────────────

variable "private_network_subnet" {
  description = "Explicit IPv4 CIDR for the private network. null = Scaleway auto-assigns. Pass an explicit CIDR (e.g. \"10.0.0.0/22\") when running managed PostgreSQL, which needs a /22 with IPAM."
  type        = string
  default     = null
}

# ── Security groups ─────────────────────────────────────────────────────────

variable "extra_inbound_rules_by_role" {
  description = "Per-role inbound rules appended to that role's static SG superset. Map of role name → list of rules (same shape as the security_group module's inbound_rules). The blueprint ships the apps/identity/ops supersets; use this to open additional ports for a role without forking. Stateful SG → only inbound need be declared."
  type = map(list(object({
    protocol   = string
    port       = optional(number)
    port_range = optional(string)
    ip_range   = optional(string, "0.0.0.0/0")
  })))
  default = {}
}

# ── Custom DNS records ──────────────────────────────────────────────────────

variable "custom_dns_records" {
  description = "Consumer-declared DNS records, keyed by zone-name. Each list entry is a record (A, AAAA, CNAME, MX, TXT, SRV). Lives at base layer so it co-exists with TEM's auto-managed SPF/DKIM/DMARC records. Common use: MX records pointing at the consumer's inbound mail provider (e.g. Proton Mail), additional TXT verifications, SRV records. Zones in keys must match base.domains.zones (records for unknown zones are silently dropped per the app_dns module convention). Example: `{ \"example.org\" = [{ subdomain = \"@\", type = \"MX\", target = \"10 mail.protonmail.ch.\" }] }`."
  type = map(list(object({
    subdomain = string
    type      = string
    target    = optional(string) # data for MX/CNAME/TXT/SRV (literal Scaleway data field)
    server    = optional(string) # server key for A/AAAA (looked up in compute_hosts)
    ttl       = optional(number, 3600)
  })))
  default = {}
}

# ── Compute hosts ───────────────────────────────────────────────────────────

variable "compute_hosts" {
  description = "Compute hosts to provision, keyed by short host name. All hosts get the default security group unless a host overrides security_group_id."
  type = map(object({
    instance_type = string
    image         = optional(string, "ubuntu_jammy")
    disk_size     = optional(number, 30)
    disk_type     = optional(string, "sbs_volume")
    role          = string
    ansible_group = string
    # Extra Ansible groups this host belongs to. Lets a single-VM staging
    # setup put one host in [apps], [identity], and a custom env group at
    # the same time. Primary group = ansible_group; extras append.
    ansible_groups    = optional(list(string), [])
    protected         = optional(bool, false)
    user_data         = optional(map(string), {})
    security_group_id = optional(string, null)
    tags              = optional(list(string), [])
  }))
  default = {}
}

# ── Gateway DNS ─────────────────────────────────────────────────────────────

variable "manage_gateway_dns" {
  description = "Whether to create the gateway A record in Scaleway DNS as part of this module's apply. When true (default), the record points at the identity host's public IP and is provisioned in the same apply as the compute host — DNS is correct by the time Traefik requests an LE cert. Set false if you manage gateway DNS out-of-band (Cloudflare, Route53, manual)."
  type        = bool
  default     = true
}

variable "gateway_compute_host_key" {
  description = "Optional explicit key in var.compute_hosts whose public IP becomes the gateway DNS record. Null (default) picks the first host with \"identity\" in its ansible_groups, then any host with role = \"identity\", then the first compute host (lexicographic). Multi-host prod usually sets this explicitly."
  type        = string
  default     = null
}

variable "gateway_dns_ttl" {
  description = "TTL (seconds) on the gateway A record. Low default (60) makes IP changes propagate fast across re-provisions."
  type        = number
  default     = 60
}

# ── Managed PostgreSQL ──────────────────────────────────────────────────────

variable "postgres_enabled" {
  description = "Whether to provision a shared managed PostgreSQL instance. Apps create their own databases inside it via modules/infrastructure/storage/postgres_database."
  type        = bool
  default     = true
}

variable "postgres_engine" {
  description = "PostgreSQL engine version."
  type        = string
  default     = "PostgreSQL-16"
}

variable "postgres_node_type" {
  description = "Scaleway RDB node type."
  type        = string
  default     = "db-dev-s"
}

variable "postgres_volume_size_in_gb" {
  description = "Postgres volume size in GB (minimum 10)."
  type        = number
  default     = 10
}

variable "postgres_high_availability" {
  description = "Whether to provision an HA Postgres cluster (doubles cost)."
  type        = bool
  default     = false
}

variable "postgres_max_connections" {
  description = "Max simultaneous Postgres connections allowed across all apps."
  type        = number
  default     = 200
}

variable "postgres_backup_schedule_frequency_hours" {
  description = "Hours between automated Postgres backups."
  type        = number
  default     = 24
}

variable "postgres_backup_schedule_retention_days" {
  description = "Days of automated Postgres backups to retain."
  type        = number
  default     = 7
}

# ── Scaleway TEM (outbound SMTP) ────────────────────────────────────────────
# Every app sends transactional mail through Scaleway TEM. Base owns the
# domain registration, DNS records (SPF/DKIM/DMARC), API key, and the
# smtp-config secret. See platform/base/terraform/tem.tf.

variable "tem_enabled" {
  description = "Whether to provision Scaleway TEM for outbound SMTP. Default true — every app expects an `smtp-config` Scaleway secret to exist. Set false ONLY if you're handling SMTP out-of-band (your own SMTP relay, etc.) AND writing smtp-config yourself."
  type        = bool
  default     = true
}

variable "tem_sender_domain" {
  description = "Domain TEM sends mail from. Must be a subdomain of (or equal to) base_domain so the SPF/DKIM/DMARC records this module creates land in the right zone. Default matches base_domain."
  type        = string
  default     = ""
}

variable "tem_from_email" {
  description = "From: address apps use as their `smtp_from_email`. Defaults to `notify@<tem_sender_domain>` when empty."
  type        = string
  default     = ""
}

variable "tem_smtp_config_secret_name" {
  description = "Name of the Scaleway secret base writes with SMTP credentials. App bundles default `smtp_secret_name` to `smtp-config` — override here only if you need a non-standard name."
  type        = string
  default     = "smtp-config"
}

variable "tem_webhook_n8n_url" {
  description = "Base URL of an n8n instance that should receive TEM delivery events (e.g. \"https://flows.example.org\"). Empty disables the whole TEM webhook → SNS → n8n pipeline. The consumer-template wires this from `module.n8n[0].app_url` so toggling n8n's `enabled` flag drives the pipeline too."
  type        = string
  default     = ""
}

variable "tem_webhook_n8n_path" {
  description = "Path appended to `tem_webhook_n8n_url` to form the SNS HTTPS subscription endpoint. The matching n8n workflow lives at platform/identity/n8n-workflows/tem-delivery-alerting.json and listens on this path."
  type        = string
  default     = "/webhook/tem-delivery"
}

variable "tem_webhook_event_types" {
  description = "TEM event types forwarded to SNS. Defaults cover delivery latency tracking and bounce alerting."
  type        = list(string)
  default = [
    "email_deferred",
    "email_delivered",
    "email_dropped",
    "email_queued",
  ]
}

variable "tem_webhook_sns_topic_name" {
  description = "Name of the SNS topic that receives TEM events. Resource is namespaced per project by Scaleway, so the bare topic name is fine."
  type        = string
  default     = "tem-delivery-events"
}

variable "tem_webhook_name_override" {
  description = "Override the auto-generated webhook name (default `<org_slug>-<environment>-tem-delivery`). Set when the auto-generated name collides with a leaked-name reservation from a previously-failed Scaleway create call — TEM holds names for an indeterminate period after a partial create, and the only operator escape is renaming. Empty string keeps the auto-generated name."
  type        = string
  default     = ""
}

# ── Host services ───────────────────────────────────────────────────────────
# Per-host runtime watchers (autoheal, diun, wazuh-agent). Each service is
# default-on at the category level. Consumer flips `enabled = false` to turn
# a service off everywhere, or lists hosts in `disabled_hosts` to opt out
# per-host. The base layer for_each's over var.compute_hosts and instantiates
# one bundle per host minus disabled_hosts.

variable "autoheal" {
  description = "Autoheal host-service. One container per compute_host watches Docker for unhealthy sibling containers and restarts those carrying the `autoheal=true` label. Default-on category. `enabled = false` disables on every host; `disabled_hosts` opts specific hosts out (must be keys in compute_hosts). image_tag / interval_seconds / start_period_seconds forward to the bundle defaults."
  type = object({
    enabled              = optional(bool, true)
    disabled_hosts       = optional(list(string), [])
    image_tag            = optional(string, "latest")
    interval_seconds     = optional(number, 5)
    start_period_seconds = optional(number, 60)
  })
  default = {}
}

variable "dmarc_rua_email" {
  description = "Email address for DMARC aggregate reports (rua=). Default empty = no rua, matching the conservative `v=DMARC1; p=quarantine` baseline. Set only if you actually process DMARC reports — otherwise reports go into a black hole."
  type        = string
  default     = ""
}

# ── Host-services tier ──────────────────────────────────────────────────────
# Each service auto-instantiates once per entry in var.compute_hosts. Defaults
# are on. Consumers disable an entire service via `enabled = false` or opt out
# specific hosts via `disabled_hosts = [...]`. See ARCHITECTURE.md.

variable "diun" {
  description = "Diun (notify-on-new-image watcher) settings. One instance per compute_host. Set `enabled = false` to turn off everywhere, or list keys from `compute_hosts` in `disabled_hosts` for per-host opt-out. `n8n_webhook_url` is auto-wired by the consumer-template when the n8n bundle is enabled — leave empty otherwise."
  type = object({
    enabled                 = optional(bool, true)
    disabled_hosts          = optional(list(string), [])
    image_tag               = optional(string, "4.31.0")
    timezone                = optional(string, "UTC")
    watch_schedule          = optional(string, "0 0 6 * * *")
    watch_workers           = optional(number, 10)
    watch_first_check_notif = optional(bool, false)
    watch_by_default        = optional(bool, true)
    default_watch_repo      = optional(bool, false)
    include_swarm_services  = optional(bool, false)
    notification_targets    = optional(list(any), [])
    diun_notif_extra        = optional(map(any), {})
    diun_watch_enabled      = optional(bool, false)
    autoheal_enabled        = optional(bool, true)
    monitoring_enabled      = optional(bool, true)
    n8n_webhook_url         = optional(string, "")
    extra_env_vars          = optional(map(string), {})
  })
  default = {}
  # Not marked sensitive — keys (enabled, disabled_hosts) feed for_each in
  # host_services.tf, and terraform forbids sensitive values as for_each
  # arguments. n8n_webhook_url contains no secret material (URL only;
  # auth is via the secret-id pattern, not embedded in the URL). Per-field
  # sensitivity, if a consumer ever needs it, lives at the consumer-template
  # call site, not on this variable wrapper.
}

variable "wazuh_agent" {
  description = "HIDS log-shipper running on every compute host, reporting to the wazuh manager. Default on because SSH-as-deploy means hosts are always exposed and host-level intrusion detection is a sensible production default. Consumers without a wazuh manager set `enabled = false` (whole service off) or list every host under `disabled_hosts`. `manager_address` is the manager's reachable network address — consumer-template auto-wires it from `module.wazuh.manager_private_ip` when the manager app is enabled."
  type = object({
    enabled              = optional(bool, true)
    disabled_hosts       = optional(list(string), [])
    image                = optional(string, "wazuh/wazuh-agent")
    release_version      = optional(string, "4.9.0")
    manager_address      = optional(string, "")
    fim_enabled          = optional(bool, true)
    fim_extra_paths      = optional(list(string), [])
    fim_extra_exclusions = optional(list(string), [])
    diun_watch_enabled   = optional(bool, true)
    autoheal_enabled     = optional(bool, true)
    extra_env_vars       = optional(map(string), {})
  })
  default = {}
}
