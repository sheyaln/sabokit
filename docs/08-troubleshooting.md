---
layout: default
title: "Part 8: Troubleshooting"
---

# Part 8: Troubleshooting Guide

Common problems and solutions.

## 8.1 SSH Issues

### "Permission denied"

Causes:
- Wrong SSH key
- Key not added to server
- Wrong user (should be `ubuntu`)

Solutions:
```bash
# Check key is loaded
ssh-add -l

# Add key
ssh-add ~/.ssh/id_ed25519

# Verify user
ssh ubuntu@192.0.2.10
```

### "Host key verification failed"

```bash
ssh-keyscan -H 192.0.2.10 >> ~/.ssh/known_hosts
```

### "Connection refused"

Server may be down or SSH not running. Check Scaleway Console.

## 8.2 Ansible Issues

### "No such file or directory" for secrets

Scaleway collection not installed:
```bash
ansible-galaxy collection install scaleway.scaleway --force
```

### "Permission denied" during playbook

Check `become: true` is set in play/task. Check ubuntu user has sudo.

### "Could not find or access" secret

Environment variables not set:
```bash
echo $SCW_ACCESS_KEY
echo $SCW_SECRET_KEY
```

## 8.3 Terraform Issues

### "Failed to get existing workspaces: S3 operation error"

AWS/Scaleway credentials not set:
```bash
export AWS_ACCESS_KEY_ID=$SCW_ACCESS_KEY
export AWS_SECRET_ACCESS_KEY=$SCW_SECRET_KEY
```

### "Error acquiring state lock"

Someone else running Terraform, or previous run crashed:
```bash
terraform force-unlock LOCK_ID
```

### "Resource already exists"

Resource created outside Terraform. Import it:
```bash
terraform import scaleway_domain_record.myrecord fr-par/RECORD_ID
```

## 8.4 Container Issues

### Container Won't Start

Check logs:
```bash
docker logs {container} --tail 100
```

Common causes:
- Missing environment variables
- Database not accessible
- Port conflict

### Container Keeps Restarting

Check health check or startup issues:
```bash
docker inspect {container} | grep -A 10 "Health"
docker logs {container} | head -50  # First startup logs
```

### "No space left on device"

```bash
df -h
docker system prune -af
```

### "Cannot connect to Docker daemon"

```bash
sudo systemctl status docker
sudo systemctl restart docker
```

## 8.5 Web Application Issues

### 502 Bad Gateway

Container not running or Traefik can't reach it:
```bash
docker ps | grep {app}
docker logs traefik --tail 50 | grep {app}
```

### 404 Not Found

DNS or Traefik routing issue:
```bash
dig myapp.example.org  # Check DNS
docker logs traefik --tail 50  # Check Traefik
```

Verify Traefik labels in docker-compose.yml.

### SSL Certificate Error

Let's Encrypt issue:
```bash
docker logs traefik | grep -i acme
docker logs traefik | grep -i certificate
```

If rate limited, wait. If challenge failing, check DNS.

### "Unable to connect" / Site Not Loading

```bash
# Is container running?
docker ps

# Is Traefik running?
docker logs traefik --tail 20

# Is port open?
curl -I http://localhost:{app_port}
```

## 8.6 Authentication Issues

### Can't Log In (Authentik)

Check Authentik is running:
```bash
ssh authentik-prod
docker ps
docker logs authentik-server --tail 50
```

### OAuth Redirect Error

Redirect URI mismatch. Check:
- terraform-authentik/apps.tf has correct redirect_uri
- Application config matches

### "Invalid token"

Session expired or secret key changed. User needs to log in again.

### Social Login Not Working

Check Google/Apple credentials in terraform.tfvars.
Check Authentik logs for OAuth errors.

## 8.7 Database Issues

### "Connection refused"

Database not running or network issue:
```bash
# Test from server
docker run --rm postgres:16 pg_isready -h 10.0.0.x -p 5432
```

### "Authentication failed"

Wrong credentials. Check secret in Scaleway:
```bash
ansible localhost -m debug -a "msg={% raw %}{{ lookup('scaleway.scaleway.scaleway_secret', 'postgres-{app}-credentials') | b64decode }}{% endraw %}"
```

### "Database does not exist"

Database not created. Check terraform-scaleway-infra/storage.tf includes database name.

## 8.8 Monitoring Issues

### No Metrics in Grafana

Check Prometheus:
1. Go to Grafana > Explore > Prometheus
2. Query: `up`
3. Should show targets

If targets down:
```bash
ssh tools-prod "docker ps | grep exporter"
```

### No Logs in Loki

Check Alloy:
```bash
ssh tools-prod "docker logs alloy --tail 50"
```

Check Loki is receiving:
```bash
ssh management "curl http://localhost:3100/ready"
```

### Dashboard Not Loading

Check Grafana:
```bash
ssh management "docker logs grafana --tail 50"
```

## 8.9 DNS Issues

### Subdomain Not Resolving

```bash
dig myapp.example.org
```

If no answer:
- Check terraform-scaleway-infra/dns.tf
- Run terraform apply
- Wait for propagation (up to 1 hour)

### Wrong IP

Update in dns.tf, run terraform apply.

## 8.10 Disk Space Issues

### Docker Eating Disk

```bash
docker system df
docker system prune -af
docker volume prune -f  # Careful - removes unused volumes
```

### Logs Too Large

Check `/var/log`:
```bash
du -sh /var/log/*
```

Traefik logs rotate automatically. Docker logs have max size configured.

## 8.11 Performance Issues

### High CPU

```bash
top
docker stats
```

Identify container, check its logs for issues.

### High Memory

```bash
free -h
docker stats
```

Container may need resource limits adjusted.

### Slow Application

Check:
- Database performance
- Container resource limits
- Network latency
- Application logs for errors

## 8.12 Quick Diagnostic Commands

```bash
# Server status
uptime
free -h
df -h

# Docker status
docker ps
docker stats --no-stream
docker system df

# Network
curl -I https://wiki.example.org
dig wiki.example.org

# Logs
docker logs {container} --tail 50
journalctl -u docker -n 50

# Firewall
sudo ufw status
sudo fail2ban-client status
```
