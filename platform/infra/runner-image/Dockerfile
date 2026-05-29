# Ansible runner for sabokit.
#
# Bakes ansible-core + collections + the entire platform/ tree at the matching
# repo tag. Consumers drop their local ansible install and run:
#
#   docker run --rm \
#     -v "$PWD/env:/env:ro" \
#     -v "$SSH_AUTH_SOCK:/ssh-agent" -e SSH_AUTH_SOCK=/ssh-agent \
#     ghcr.io/sheyaln/sabokit-runner:vX.Y.Z \
#     site.yml -i /env/inventory.ini -e @/env/enabled_apps.json
#
# /env is the consumer's convention: their inventory.ini, enabled_apps.json
# (produced from `terraform output -json enabled_apps`), and any extra vars
# files. The runner does not generate enabled_apps.json — TF state lives on
# the consumer side, not in the image.

# syntax=docker/dockerfile:1.7
FROM python:3.12-slim

ARG ANSIBLE_CORE_VERSION=2.18.1
ARG SABOKIT_VERSION=dev
ARG TERRAFORM_VERSION=1.10.5

LABEL org.opencontainers.image.source="https://github.com/sheyaln/sabokit"
LABEL org.opencontainers.image.description="Ansible + Terraform runner for sabokit. Ansible-core + collections + Terraform CLI + every bundle's role baked in at the matching repo tag."
LABEL org.opencontainers.image.version="${SABOKIT_VERSION}"
LABEL org.opencontainers.image.licenses="MIT"

RUN apt-get update && apt-get install -y --no-install-recommends \
      openssh-client \
      git \
      ca-certificates \
      curl \
      jq \
      sshpass \
      unzip \
    && rm -rf /var/lib/apt/lists/*

RUN pip install --no-cache-dir \
      "ansible-core==${ANSIBLE_CORE_VERSION}" \
      "requests" \
      "jmespath" \
      "passlib" \
      "docker" \
      "scaleway"

# scaleway.scaleway's lookups (eg. scaleway_secret, used by the authentik role
# to read DB/admin/server secrets) need the official `scaleway` Python SDK at
# runtime — installed above. Pin the collection so a later rebuild can't drift
# onto a version with different requirements without us noticing.
RUN ansible-galaxy collection install --force \
      community.docker \
      community.general \
      ansible.posix \
      scaleway.scaleway:2.7.2 \
    && rm -rf /root/.ansible/tmp

# Terraform CLI. Pinned via TERRAFORM_VERSION build arg. Bumped per sabokit
# release; consumers override with --build-arg TERRAFORM_VERSION=X.Y.Z.
# TARGETARCH (amd64/arm64) is injected by buildx and matches HashiCorp's
# linux_<arch> artifact naming, so the image builds natively on both arches.
ARG TARGETARCH
RUN curl -fsSL https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_${TARGETARCH}.zip \
      -o /tmp/tf.zip \
    && unzip /tmp/tf.zip -d /usr/local/bin \
    && rm /tmp/tf.zip \
    && terraform -version

COPY platform/ /opt/sabokit/platform/
COPY scripts/  /opt/sabokit/scripts/

# Default WORKDIR is the ansible tree (most invocations are ansible-playbook).
# For terraform invocations the sabokit CLI sets its own workdir and mounts the
# consumer's TF tree at /project.
WORKDIR /opt/sabokit/platform/ansible

ENTRYPOINT ["ansible-playbook"]
CMD ["--help"]
