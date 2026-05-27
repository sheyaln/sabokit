# Canonical 3-host naming rename (v3.4.0).
# Consumers using the prior upstream default ({apps} single-host) migrate
# their state into the new {tools, identity, management} keys via these
# blocks. No-op for greenfield consumers.

moved {
  from = module.base.module.compute_host["apps"]
  to   = module.base.module.compute_host["tools"]
}

# For consumers who keyed their identity host as "authentik" prior to v3.4.0.
moved {
  from = module.base.module.compute_host["authentik"]
  to   = module.base.module.compute_host["identity"]
}

# Backrest is a multi-instance bundle keyed off the host it backs up. When
# the host key renames, the corresponding backrest module instance label
# moves with it. Consumers who instantiated `module.backrest["apps"]` /
# `module.backrest["authentik"]` directly (rather than the per-host
# `module.backrest_mgmt` form shipped in apps.tf) inherit these.
moved {
  from = module.backrest["apps"]
  to   = module.backrest["tools"]
}

moved {
  from = module.backrest["authentik"]
  to   = module.backrest["identity"]
}

# Core-tier relocation (v3.4.0): loki / prometheus / grafana / wazuh moved
# from platform/apps/ to platform/core/ and now compose under a single
# module.core block. Existing state addresses migrate via these blocks so
# `terraform apply` is a no-op for greenfield-on-v3.4.0 deploys and a
# zero-resource move for v3.3.x consumers bumping in place.
moved {
  from = module.loki
  to   = module.core.module.loki
}

moved {
  from = module.prometheus
  to   = module.core.module.prometheus
}

moved {
  from = module.grafana
  to   = module.core.module.grafana
}

moved {
  from = module.wazuh
  to   = module.core.module.wazuh
}
