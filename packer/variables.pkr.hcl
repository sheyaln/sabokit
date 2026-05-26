// Input variables for base.pkr.hcl.
//
// Pass `image_version` explicitly when building a release (typically the
// sabokit git tag without the `v`). Source image defaults to the current
// Debian stable cloud qcow2 — override `source_image_url` /
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
  description = "URL of the upstream cloud qcow2 used as the build seed. Defaults to current Debian stable (trixie) generic-amd64. Override with a `file://` URL to use a locally cached image."
  default     = "https://cloud.debian.org/images/cloud/trixie/latest/debian-13-generic-amd64.qcow2"
}

variable "source_image_checksum" {
  type        = string
  description = "Checksum for the source qcow2 in the form packer expects (e.g. `file:<url-to-SHA512SUMS>` or `sha256:<hex>`). The `file:` form auto-resolves from Debian's published SHA512SUMS so re-pointing to a newer point release just works."
  default     = "file:https://cloud.debian.org/images/cloud/trixie/latest/SHA512SUMS"
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
