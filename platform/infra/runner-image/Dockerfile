# Ansible + Terraform + scw runner for sabokit.
#
# Bakes everything the consumer-template layer scripts need — ansible-core +
# collections, the Terraform CLI, the Scaleway CLI, jq — plus the entire
# platform/ tree and the consumer-template at the matching repo tag.
#
# sabokit-cli mounts the consumer repo at /workspace/consumer and runs the
# layer scripts (the consumer's scripts/ if present, else the baked
# /opt/sabokit/consumer-template/scripts/) with the consumer repo as cwd:
#
#   docker run --rm \
#     -v "$PWD:/workspace/consumer" -w /workspace/consumer \
#     -v "$SSH_AUTH_SOCK:/ssh-agent" -e SSH_AUTH_SOCK=/ssh-agent \
#     -e SCW_ACCESS_KEY -e SCW_SECRET_KEY \
#     --entrypoint bash \
#     ghcr.io/sheyaln/sabokit-runner:vX.Y.Z \
#     /opt/sabokit/consumer-template/scripts/up.sh <env>
#
# /workspace/sabokit is a baked symlink to /opt/sabokit so the consumer's
# ansible-local/site.yml `../../sabokit/platform/ansible/site.yml` import
# resolves exactly like a sibling checkout on a host. TF state and secrets
# stay on the consumer side, never in the image.

# syntax=docker/dockerfile:1.7
FROM python:3.12-slim

ARG ANSIBLE_CORE_VERSION=2.18.1
ARG SABOKIT_VERSION=dev
ARG TERRAFORM_VERSION=1.10.5
ARG SCW_CLI_VERSION=2.56.0

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

# Scaleway CLI. The layer scripts read the Authentik admin token from the
# Scaleway secret infra mints (lib.sh fetch_authentik_token), so scw must be
# on PATH inside the runner. Single static binary per arch.
RUN curl -fsSL https://github.com/scaleway/scaleway-cli/releases/download/v${SCW_CLI_VERSION}/scaleway-cli_${SCW_CLI_VERSION}_linux_${TARGETARCH} \
      -o /usr/local/bin/scw \
    && chmod +x /usr/local/bin/scw \
    && scw version

COPY platform/          /opt/sabokit/platform/
COPY scripts/           /opt/sabokit/scripts/
COPY consumer-template/ /opt/sabokit/consumer-template/

# /workspace/sabokit mirrors the sibling-checkout convention: the consumer
# repo is mounted at /workspace/consumer, so its ansible-local/site.yml
# `../../sabokit/...` import resolves into the baked tree.
RUN mkdir -p /workspace && ln -s /opt/sabokit /workspace/sabokit

# Default WORKDIR is the ansible tree (most invocations are ansible-playbook).
# Layer-script invocations override with -w /workspace/consumer; terraform
# invocations set their own workdir on the consumer's mounted TF tree.
WORKDIR /opt/sabokit/platform/ansible

ENTRYPOINT ["ansible-playbook"]
CMD ["--help"]
