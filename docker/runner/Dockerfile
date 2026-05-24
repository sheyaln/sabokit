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
ARG FEDERATED_COMMONS_VERSION=dev

LABEL org.opencontainers.image.source="https://github.com/sheyaln/sabokit"
LABEL org.opencontainers.image.description="Ansible runner for sabokit. Ansible + collections + every bundle's role baked in at the matching repo tag."
LABEL org.opencontainers.image.version="${FEDERATED_COMMONS_VERSION}"
LABEL org.opencontainers.image.licenses="MIT"

RUN apt-get update && apt-get install -y --no-install-recommends \
      openssh-client \
      git \
      ca-certificates \
      curl \
      jq \
      sshpass \
    && rm -rf /var/lib/apt/lists/*

RUN pip install --no-cache-dir \
      "ansible-core==${ANSIBLE_CORE_VERSION}" \
      "requests" \
      "jmespath" \
      "passlib" \
      "docker"

RUN ansible-galaxy collection install --force \
      community.docker \
      community.general \
      ansible.posix \
      scaleway.scaleway \
    && rm -rf /root/.ansible/tmp

COPY platform/ /opt/sabokit/platform/
COPY scripts/  /opt/sabokit/scripts/

WORKDIR /opt/sabokit/platform/ansible

ENTRYPOINT ["ansible-playbook"]
CMD ["--help"]
