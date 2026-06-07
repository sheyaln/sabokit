# packer/ — Pre-baked base image for sabokit

This directory builds a **portable qcow2** that ships the static, version-agnostic bits of the host setup (docker engine + compose, ufw, fail2ban, unattended-upgrades, node_exporter + cadvisor binaries, scw CLI, jq, python3 + Scaleway SDK, monitoring container images pre-pulled).

Cold deploys against this image skip the slow apt-install steps in `bootstrap.yml` and finish roughly 5× faster. The Packer flow is **optional** — consumers who don't import the image stay on the Scaleway `ubuntu_jammy` marketplace image and get the same result, just slower.

The builder is **qemu**: the build runs offline against the upstream Ubuntu 22.04 LTS (jammy) cloud image — no Scaleway project, no API key, no object-storage bucket. Consumers import the resulting qcow2 into their own Scaleway project once per release via `consumer-template/scripts/import-base-image.sh`.

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
| `/etc/ssh/sshd_config.d/00-sabokit-hardening.conf` (PermitRootLogin no, PasswordAuth no, modern crypto, no agent/X11 fwd, AllowTcpForwarding local) | sshd hardening script | applies on first boot |
| `docker-prune.timer` + `/usr/local/sbin/docker-prune.sh` + `/etc/default/docker-prune` (weekly image/build-cache/runaway-log reclaim, **enabled**) | docker-prune script | none — host hygiene, no Ansible role |

Service units with a per-env runtime form (node_exporter, cadvisor, traefik, …) ship **stopped + disabled** — every clone runs Ansible on first boot, which configures and starts them with the right per-env config. The exceptions are units with no per-env config that must run regardless of which bundles a host carries: the first-boot lockdown one-shot and the `docker-prune.timer`, which ship **enabled**.

## Source OS

The qemu source image is the current Ubuntu 22.04 LTS (jammy) server cloud image:

```
https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img
```

This matches the Scaleway `ubuntu_jammy` marketplace image used by consumers who skip the qcow2 import, so both paths run the same OS family. Override `source_image_url` + `source_image_checksum` to pin a specific build or swap upstream image (e.g. a newer LTS) — but bumping the LTS is a contract change for downstream consumers and should be coordinated separately.

## Cloud-init seed

The qemu builder boots the source image with a `cidata` CD attached carrying `http/user-data` + `http/meta-data`. That seed creates a build-time `packer` user with a fixed password and passwordless sudo so the shell provisioners can run over SSH. `99-cleanup.sh` locks the account and wipes cloud-init state before the qcow2 ships, so the rendered image has no live `packer` login. Consumer-side cloud-init (from `up.sh`) seeds the real `root`/`deploy` accounts on first boot.

## Build (maintainers only)

Prerequisites:

- Packer ≥ 1.10
- qemu-system-x86 + qemu-utils (`apt install qemu-system-x86 qemu-utils` on Debian/Ubuntu)
- KVM acceleration (`/dev/kvm` present and writable) — strongly recommended; falls back to slow TCG if `accelerator=tcg` is set

```bash
cd packer
packer init .
packer validate -var image_version=2.0.0 .
packer build -var image_version=2.0.0 .
```

Packer downloads the source image, boots a temp VM, runs the provisioners over SSH, snapshots the disk, and writes `output/fc-base-<version>/fc-base-<version>.qcow2`. The temp VM is torn down automatically.

On a host without KVM (macOS, CI without nested virt) override the accelerator:

```bash
packer build -var image_version=2.0.0 -var accelerator=tcg .
```

TCG is roughly 10× slower; expect ~2 hours instead of ~15 minutes.

### Releasing

The `.github/workflows/packer-publish.yml` workflow runs on every `v*` tag push (or via manual dispatch). It installs qemu + Packer on the GitHub-hosted runner (which ships `/dev/kvm` enabled), builds the qcow2, and attaches it plus a metadata JSON to the matching GitHub Release.

No repo secrets needed — the qemu builder runs offline. Only the default `GITHUB_TOKEN` is consumed for `gh release upload`.

Release asset URL the consumer import script expects:
`https://github.com/sheyaln/sabokit/releases/download/<TAG>/fc-base-<TAG>.qcow2`

For ad-hoc rebuilds without tagging, trigger the workflow manually and pass `image_version` (e.g. `2.0.0`). The workflow creates the release if it doesn't already exist.

#### Manual fallback

When the workflow can't run (CI down) the same steps work by hand on any Linux box with KVM:

```bash
cd packer && packer init . && packer build -var image_version=2.0.0 .
gh release upload v2.0.0 output/fc-base-2.0.0/fc-base-2.0.0.qcow2 --clobber
```

## Consumer import flow

Each consumer (per Scaleway project) does this **once per sabokit version**:

```bash
cd consumer-template/scripts
./import-base-image.sh v2.1.0
```

The script downloads the qcow2 from the GitHub Release, uploads it to a temporary object-storage bucket in the consumer's Scaleway project, imports it as a block snapshot, registers it as an instance image, and prints the resulting `image_id`. The consumer pastes that ID into their `hosts.yml`:

```yaml
# hosts.yml — image override per host (instance sizing comes from env.yml)
compute_hosts:
  tools:
    role: tools
    ansible_group: tools
    image: "11111111-2222-3333-4444-555555555555"  # sabokit-base-2.1.0
```

Consumers who skip the import keep `image = "ubuntu_jammy"` and pay the apt-install cost on bootstrap. Both paths converge to identical post-bootstrap state thanks to the Ansible role guards.

## Adding to the image

1. Pick the right layer: an apt package goes in `provisioners/01-apt-base.sh`; a binary download gets its own script (see `04-exporter-binaries.sh` for the pattern).
2. Make the change idempotent (re-running the provisioner on an already-configured host must be a no-op).
3. **Do not start services** — the image is cloned across many VMs. Ansible owns service lifecycle.
4. If the addition replaces an Ansible install step, add a guard in the corresponding role that keys on the binary/marker file you're shipping. Keep the install step working for `ubuntu_jammy` users.
5. Bump `image_version`. The version is baked into `/etc/sabokit-base-image`, surfaces as the qcow2 filename, and is the contract consumers pin against.

## Trade-offs

- **Storage cost.** A Scaleway custom image lives in the consumer's project. The qcow2 is ~3 GB.
- **Version skew.** A consumer pinning an older image still gets a working deploy — the Ansible guards detect missing components (e.g. an old image without alloy) and run the install path for those.
- **Updates.** Refreshing the base image is a maintainer task. Apt security updates land via `unattended-upgrades` on every host regardless.
- **OS pin.** Both the qcow2 and the `ubuntu_jammy` fallback are Ubuntu 22.04 LTS. Bumping to a newer LTS (e.g. noble) is a coordinated change — base image + Ansible roles + consumer image marketplace reference all flip together.
