---
layout: default
title: "Part 0: Prerequisites"
---

# Part 0: Prerequisites & Environment Setup

This section covers what you need installed and configured before working with this infrastructure. You should be at least comfortable with using the command line interface, and basic networking before starting.

## 0.1 Overview

The infrastructure runs on Scaleway and consists of:

- 3 Virtual Private Servers: `tools-prod`, `management`, `authentik-prod`
- 1 managed PostgreSQL database shared across applications
- DNS for your domains (e.g., example.org for apps, example.cc for management)
- S3 object storage for backups and app data

Management tools:

- Terraform: Creates cloud resources
- Ansible: Configures servers and deploys applications
- Docker: Runs applications as containers

## 0.2 Required Software

### Windows

Follow this guide to set up WSL2, which is a Linux virtual machine that integrates with your Windows OS smoothly: <https://documentation.ubuntu.com/wsl/stable/howto/install-ubuntu-wsl2/>

Then, follow the Ubuntu/Debian instructions.

### macOS

```bash
brew install terraform
brew install ansible
brew install python@3.11
brew install scw
brew install jq
brew install git
```

### Ubuntu/Debian

```bash
sudo apt update
sudo apt install -y python3 python3-pip python3-venv

pip3 install ansible

wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install terraform

sudo apt install -y jq git curl
```

### Verify

```bash
terraform --version
ansible --version
python3 --version
git --version
```

## 0.3 Ansible Dependencies

```bash
ansible-galaxy collection install community.docker
ansible-galaxy collection install community.general
ansible-galaxy collection install scaleway.scaleway

pip3 install docker
pip3 install passlib
pip3 install bcrypt
```

## 0.4 SSH Setup

Generate a key if you don't have one:

```bash
ssh-keygen -t ed25519 -C "your-email@example.com"
```

Load it into the agent:

```bash
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_ed25519
```

Create `~/.ssh/config` (replace IPs with your actual server IPs):

```ssh-config
Host tools-prod
    HostName 192.0.2.10
    User ubuntu
    IdentityFile ~/.ssh/id_ed25519
    ForwardAgent yes

Host management
    HostName 192.0.2.20
    User ubuntu
    IdentityFile ~/.ssh/id_ed25519
    ForwardAgent yes

Host authentik-prod
    HostName 192.0.2.30
    User ubuntu
    IdentityFile ~/.ssh/id_ed25519
    ForwardAgent yes

Host *
    AddKeysToAgent yes
    IdentitiesOnly yes
```

> Note: IPs shown are RFC 5737 documentation examples. Replace with your actual server IPs from Scaleway.

Your SSH public key must be registered with Scaleway and added to the servers.
You can add an SSH public key to Scaleway using the UI.
See: <https://www.scaleway.com/en/docs/organizations-and-projects/how-to/create-ssh-key/>

You will also need to generate a Scaleway access key and secret key.
See 0.6.

## 0.5 Environment Variables

Create `~/.obs-env` (Federated Commons environment):

```bash
# Scaleway API
export SCW_ACCESS_KEY="your-access-key"
export SCW_SECRET_KEY="your-secret-key"
export SCW_DEFAULT_PROJECT_ID="your-project-id"
export SCW_DEFAULT_REGION="fr-par"

# Terraform variables
export TF_VAR_access_key="${SCW_ACCESS_KEY}"
export TF_VAR_secret_key="${SCW_SECRET_KEY}"
export TF_VAR_project_id="${SCW_DEFAULT_PROJECT_ID}"
export TF_VAR_region="${SCW_DEFAULT_REGION}"

# Terraform S3 backend
export AWS_ACCESS_KEY_ID="${SCW_ACCESS_KEY}"
export AWS_SECRET_ACCESS_KEY="${SCW_SECRET_KEY}"
export AWS_DEFAULT_REGION="fr-par"

# GitHub Container Registry
export GITHUB_USERNAME="your-github-username"
export GITHUB_TOKEN="your-github-pat"
```

Add to `~/.zshrc` or `~/.bashrc`:

```bash
if [ -f ~/.obs-env ]; then
    source ~/.obs-env
fi
```

Reload:

```bash
source ~/.zshrc
```

## 0.6 Scaleway API Credentials

ref:  <https://www.scaleway.com/en/docs/iam/how-to/create-api-keys/>

1. Log into <https://console.scaleway.com>
2. Go to IAM > API Keys
3. Generate an API Key
4. Copy the Access Key and Secret Key

Required permissions:

- Instances: Full access
- Secret Manager: Full access
- Object Storage: Full access
- Managed Databases: Full access
- Domains and DNS: Full access

## 0.7 Clone the Repository

```bash
git clone https://github.com/sabokit/sabokit.git
cd sabokit
```

## 0.8 Verification

### Test Terraform

```bash
cd terraform-scaleway-infra
terraform init
terraform state list
```

### Test Ansible Secret Access

```bash
cd ../ansible-vps
ansible localhost -m debug -a "msg={% raw %}{{ lookup('scaleway.scaleway.scaleway_secret', 'smtp-config') | b64decode }}{% endraw %}"
```

### Test SSH

```bash
ssh tools-prod "hostname"
ssh management "hostname"
ssh authentik-prod "hostname"
```

## 0.9 Web Access

| Service | URL | Access |
|---------|-----|--------|
| Scaleway Console | <https://console.scaleway.com> | Scaleway account |
| Authentik Admin | <https://gateway.example.org/if/admin/> | admin group |
| Grafana | <https://grafana.example.cc> | admin or union-delegate group |
| Zabbix  | <https://zabbix.example.cc> | No SSO, account must be created manually |

> Note: Replace `example.org` and `example.cc` with your actual domains.

## 0.10 Common Issues

**Permission denied on Terraform**: Environment variables not set. Check `echo $TF_VAR_access_key`.

**Ansible can't find secrets**: Install the collection: `ansible-galaxy collection install scaleway.scaleway --force`

**SSH host key verification**: Add host keys: `ssh-keyscan -H 192.0.2.10 >> ~/.ssh/known_hosts`

**Terraform state lock**: Someone else running Terraform, or previous run crashed. Use `terraform force-unlock LOCK_ID` only if needed.
