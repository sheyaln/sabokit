// Input variables for base.pkr.hcl.
//
// Pass `image_version` explicitly when building a release (typically the
// sabokit git tag without the `v`). Source image defaults to the current
// Ubuntu 22.04 LTS (jammy) cloud qcow2 — override `source_image_url` /
// `source_image_checksum` to pin a specific point release.

variable "image_version" {
  type        = string
  description = "Version tag baked into the image name and into /etc/sabokit-base-image. Typically the sabokit release tag without the leading 'v' (e.g. \"1.4.0\"). Required."
}

variable "image_name_prefix" {
  type        = string
  description = "Prefix for the resulting image artefact. Final qcow2 is `<prefix>-<version>.qcow2`."
  default     = "fc-base"
}

variable "source_image_url" {
  type        = string
  description = "URL of the upstream cloud qcow2 used as the build seed. Defaults to current Ubuntu 22.04 LTS (jammy) server cloud image (amd64). Matches the Scaleway `ubuntu_jammy` marketplace image so the pre-baked and fallback paths share an OS family. Override with a `file://` URL to use a locally cached image."
  default     = "https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img"
}

variable "source_image_checksum" {
  type        = string
  description = "Checksum for the source qcow2 in the form packer expects (e.g. `file:<url-to-SHA256SUMS>` or `sha256:<hex>`). The `file:` form auto-resolves from Ubuntu's published SHA256SUMS so re-pointing to a newer build just works."
  default     = "file:https://cloud-images.ubuntu.com/jammy/current/SHA256SUMS"
}

variable "output_directory" {
  type        = string
  description = "Directory the qcow2 is written to. Per-version subdirectory is created underneath so concurrent builds at different versions don't collide."
  default     = "output"
}

variable "disk_size" {
  type        = string
  description = "Resulting qcow2 virtual disk size. Cloud qcow2s ship ~2 GB; we grow to fit the pre-pulled docker images + extra headroom for a consumer's first apt upgrade."
  default     = "10G"
}

variable "memory" {
  type        = number
  description = "RAM (MB) given to the build VM. 2048 is enough for apt + docker pull workloads."
  default     = 2048
}

variable "cpus" {
  type        = number
  description = "vCPUs given to the build VM."
  default     = 2
}

variable "accelerator" {
  type        = string
  description = "Qemu accelerator. `kvm` on Linux hosts with /dev/kvm; `tcg` for a slow CPU-only fallback (CI without nested virt)."
  default     = "kvm"
}

variable "node_exporter_version" {
  type        = string
  description = "node_exporter release to bake. Pinned because we want reproducible images."
  default     = "1.8.2"
}

variable "cadvisor_version" {
  type        = string
  description = "cAdvisor release to bake. Pinned for reproducibility."
  default     = "0.49.1"
}

variable "scw_cli_version" {
  type        = string
  description = "Scaleway CLI release to bake. Pinned for reproducibility — Ansible will upgrade in-place if a newer one is configured. GitHub garbage-collects very old release assets periodically; keep this within the last ~year of releases or builds 404."
  default     = "2.56.1"
}

// SHA256 checksums for downloaded binaries. Keep in sync with the *_version
// pins above. Source of truth:
//   - node_exporter: sha256sums.txt sibling on the GitHub release
//   - cadvisor:      no upstream checksum file → anchor the first trusted
//                    download and verify on every subsequent build
//   - scw:           SHA256SUMS sibling on the GitHub release
variable "node_exporter_sha256_amd64" {
  type    = string
  default = "6809dd0b3ec45fd6e992c19071d6b5253aed3ead7bf0686885a51d85c6643c66"
}
variable "node_exporter_sha256_arm64" {
  type    = string
  default = "627382b9723c642411c33f48861134ebe893e70a63bcc8b3fc0619cd0bfac4be"
}
variable "cadvisor_sha256_amd64" {
  type    = string
  default = "1d5cc701a3fcdf1e8ed1c86da5304b896a6997d9e6673139e78a6f87812495b0"
}
variable "cadvisor_sha256_arm64" {
  type    = string
  default = "c535f46d789599f25c7c680af193d4402da27a98d9828eb2ec916af6256e0c0c"
}
variable "scw_cli_sha256_amd64" {
  type    = string
  default = "dea550d0f768ba43f21fcd8dc2309cfd54680fe8c425048fde8e88f22f840209"
}
variable "scw_cli_sha256_arm64" {
  type    = string
  default = "30d6f8a1af4ab1cf7ea06d40290afe9e5c20a7d56e1773310a185a13f05b8b8f"
}

// Pre-pulled docker images, pinned by digest. `:tag@sha256:digest` is the
// only form that gives true immutability — registries can move tags but
// digests are content-addressed. Update digests when bumping versions:
//   curl -sIL -H "Accept: application/vnd.docker.distribution.manifest.list.v2+json,application/vnd.oci.image.index.v1+json" \
//     -H "Authorization: Bearer $(curl -sL 'https://auth.docker.io/token?service=registry.docker.io&scope=repository:<repo>:pull' | jq -r .token)" \
//     "https://registry-1.docker.io/v2/<repo>/manifests/<tag>" | grep -i docker-content-digest
variable "image_node_exporter" {
  type    = string
  default = "prom/node-exporter:v1.8.2@sha256:4032c6d5bfd752342c3e631c2f1de93ba6b86c41db6b167b9a35372c139e7706"
}
variable "image_cadvisor" {
  type    = string
  default = "gcr.io/cadvisor/cadvisor:v0.49.1@sha256:3cde6faf0791ebf7b41d6f8ae7145466fed712ea6f252c935294d2608b1af388"
}
variable "image_alloy" {
  type    = string
  default = "grafana/alloy:v1.4.2@sha256:625174f60ee3287a4ec9de7e818805f117376f1375169bc73482b41540697376"
}
variable "image_traefik" {
  type    = string
  default = "traefik:v3.3@sha256:2cd5cc75530c8d07ae0587c743d23eb30cae2436d07017a5ff78498b1a43d09f"
}
variable "image_haproxy" {
  type    = string
  default = "haproxy:2.9-alpine@sha256:3e29449a6beed63262e36104adf531b4e41b359f61937303f5ea8607987b3748"
}
