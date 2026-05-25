# packer/ — Pre-baked base image for sabokit

This directory builds a Scaleway custom image that ships the static, version-agnostic bits of the host setup (docker engine + compose, ufw, fail2ban, unattended-upgrades, node_exporter + cadvisor binaries, scw CLI, jq, python3 + Scaleway SDK, monitoring container images pre-pulled).

Cold deploys against this image skip the slow apt-install steps in `bootstrap.yml` and finish roughly 5× faster. The Packer flow is **optional** — consumers who don't import the image stay on the `ubuntu_jammy` marketplace image and get the same result, just slower.

## Contents

| Layer | Provided by | Used by Ansible role |
| --- | --- | --- |
| ca-certificates, curl, gnupg, jq, ufw, fail2ban, unattended-upgrades, mailutils, logrotate, rsyslog | apt | `ufw`, `fail2ban`, `unattended-upgrades`, `log-management` |
| python3, python3-pip, python3-docker, scaleway SDK, pyyaml | apt + pip | Ansible community.docker / scaleway lookups |
| docker-ce + compose plugin + buildx + containerd | Docker apt repo | `docker` |
| `/usr/local/bin/node_exporter` + systemd unit (disabled) | binary download | `monitoring-agent` |
| `/usr/local/bin/cadvisor` + systemd unit (disabled) | binary download | `monitoring-agent` |
| `/usr/local/bin/scw` | binary download | `scw-secrets` |
| Pre-pulled docker images: `prom/node-exporter`, `gcr.io/cadvisor/cadvisor`, `grafana/alloy`, `traefik`, `haproxy` | docker pull | `monitoring-agent`, `traefik` |
| `/etc/sabokit-base-image` marker file (with `SABOKIT_BASE_VERSION`) | stamp script | every role's guard |

Services are intentionally **stopped + disabled** in the image — every clone of the image runs Ansible on first boot, which configures and starts them with the right per-env config.

## Build (maintainers only)

Prerequisites:

- Packer ≥ 1.10
- Scaleway API key with project-scoped permissions
- `SCW_ACCESS_KEY`, `SCW_SECRET_KEY`, `SCW_DEFAULT_PROJECT_ID` exported

```bash
cd packer
packer init .
packer validate -var image_version=2.0.0 .
packer build -var image_version=2.0.0 .
```

Packer creates a temporary build instance, runs the provisioners, snapshots it, and registers the snapshot as a Scaleway image named `fc-base-2.1.0`. The temporary instance and snapshot intermediates are cleaned up automatically.

### Releasing

The `.github/workflows/packer-publish.yml` workflow runs on every `v*` tag push (or via manual dispatch). It builds the image, exports the snapshot to qcow2, and attaches the qcow2 plus a metadata JSON to the matching GitHub Release.

Required repo secrets (one-time setup):

| Secret | What it is |
| --- | --- |
| `PACKER_SCW_ACCESS_KEY`     | Scaleway API access key for the build project. |
| `PACKER_SCW_SECRET_KEY`     | Scaleway API secret key for the build project. |
| `PACKER_SCW_PROJECT_ID`     | Scaleway project where the build VM, snapshot, and intermediate object live. |
| `PACKER_SCW_PUBLISH_BUCKET` | Existing Scaleway object-storage bucket the workflow uses as the qcow2 export staging area. |

Release asset URL the consumer import script expects:
`https://github.com/sheyaln/sabokit/releases/download/<TAG>/fc-base-<TAG>.qcow2`

For ad-hoc rebuilds without tagging, trigger the workflow manually and pass `image_version` (e.g. `2.0.0`). The workflow creates the release if it doesn't already exist.

#### Manual fallback

When the workflow can't run (CI down, secret rotation in progress) the same steps work by hand:

```bash
# Build (SCW_* env vars set).
cd packer && packer init . && packer build -var image_version=2.0.0 .

# Resolve snapshot via the image's root_volume.
IMAGE_ID="<id printed by packer>"
SNAPSHOT_ID=$(scw instance image get "$IMAGE_ID" -o json | jq -r '.image.root_volume.id')

# Export → download → upload.
scw block snapshot export-to-object-storage snapshot-id="$SNAPSHOT_ID" bucket=<bucket> key=fc-base-2.1.0.qcow2
scw object-storage object download bucket=<bucket> key=fc-base-2.1.0.qcow2 > fc-base-2.1.0.qcow2
gh release upload v2.0.0 fc-base-2.1.0.qcow2 --clobber
```

## Consumer import flow

Each consumer (per Scaleway project) does this **once per sabokit version**:

```bash
cd consumer-template/scripts
./import-base-image.sh v2.1.0
```

The script downloads the qcow2 from the GitHub Release, uploads it to a temporary object-storage bucket in the consumer's Scaleway project, imports it as a block snapshot, registers it as an instance image, and prints the resulting `image_id`. The consumer pastes that ID into their `terraform.tfvars`:

```hcl
compute_hosts = {
  tools = {
    instance_type = "PRO2-S"
    image         = "11111111-2222-3333-4444-555555555555"  # fc-base-2.1.0
    role          = "apps"
    ansible_group = "apps"
  }
}
```

Consumers who skip the import keep `image = "ubuntu_jammy"` and pay the apt-install cost on bootstrap. Both paths converge to identical post-bootstrap state thanks to the Ansible role guards.

## Adding to the image

1. Pick the right layer: a Debian package goes in `provisioners/01-apt-base.sh`; a binary download gets its own script (see `04-exporter-binaries.sh` for the pattern).
2. Make the change idempotent (re-running the provisioner on an already-configured host must be a no-op).
3. **Do not start services** — the image is cloned across many VMs. Ansible owns service lifecycle.
4. If the addition replaces an Ansible install step, add a guard in the corresponding role that keys on the binary/marker file you're shipping. Keep the install step working for `ubuntu_jammy` users.
5. Bump `image_version`. The version is baked into `/etc/sabokit-base-image`, surfaces in Scaleway image tags, and is the contract consumers pin against.

## Trade-offs

- **Storage cost.** A Scaleway custom image lives in the consumer's project. The qcow2 is ~3 GB.
- **Version skew.** A consumer pinning an older image still gets a working deploy — the Ansible guards detect missing components (e.g. an old image without alloy) and run the install path for those.
- **Updates.** Refreshing the base image is a maintainer task. Apt security updates land via `unattended-upgrades` on every host regardless.
