---
layout: default
title: "Part 7: Disaster Recovery"
---

# Part 7: Disaster Recovery

Procedures for recovering from failures.

## 7.1 Backup Architecture

### Database Backups

Managed PostgreSQL has automatic daily backups.
- Retention: 3 days
- Region: Same region (fr-par)

Access via Scaleway Console > Managed Databases > Backups.

### Application Data Backups

Restic backups to S3 bucket `{project}-appdata-prod-0`.

Backed up:
- Docker volumes
- Application config directories (`/opt/*`)
- Traefik ACME certificates

### Terraform State

S3 bucket: `{project}-terraform-state-prod-0`
- Versioning enabled
- Recoverable via S3 versioning

## 7.2 Database Recovery

### From Managed PostgreSQL Backup

1. Go to Scaleway Console
2. Managed Databases > Select instance
3. Backups > Select backup
4. Restore (creates new instance or restores to existing)

### Point-in-Time Recovery

Managed PostgreSQL supports PITR for recent data:

1. Go to Managed Databases > Instance
2. Backups > Restore to point in time
3. Select timestamp

## 7.3 Application Recovery

### Single Application

1. SSH to server
2. Stop application:
   ```bash
   cd /opt/{app}
   docker compose down
   ```
3. Restore data if needed
4. Redeploy:
   ```bash
   cd ~/sabokit/ansible-vps
   ansible-playbook playbook-tools-prod.yml -i inventory.ini --tags {app}
   ```

### From Restic Backup

```bash
# List snapshots
docker exec restic-backup restic snapshots

# Restore specific snapshot
docker exec restic-backup restic restore SNAPSHOT_ID --target /restore

# Copy restored data
cp -r /restore/backup/opt/{app} /opt/
```

## 7.4 Full Server Recovery

### If Server Exists but Corrupted

1. SSH in (if possible) to check for any issues.
2. Run full Ansible playbook from local:
   ```bash
   ansible-playbook playbook-tools-prod.yml -i inventory.ini
   ```

### If Server Destroyed

1. Recreate with Terraform:
   ```bash
   cd terraform-scaleway-infra
   terraform apply
   ```

2. Update inventory.ini with new IP

3. Run Ansible:
   ```bash
   ansible-playbook playbook-tools-prod.yml -i inventory.ini
   ```

4. Restore application data from backups

## 7.5 Authentik Recovery

Critical path - without Authentik, no one can log in.

### Container Issues

```bash
ssh authentik-prod
cd /opt/authentik
docker compose logs authentik-server
docker compose restart
```

### Database Issues

1. Check PostgreSQL connection
2. Restore from managed database backup if needed
3. Restart Authentik containers

### Full Rebuild

1. Ensure database backup exists
2. Restore database
3. Run Ansible:
   ```bash
   ansible-playbook playbook-authentik.yml -i inventory.ini
   ```

### Secret Key Recovery

The Authentik secret key is stored in Scaleway Secret Manager (`authentik-secret-key`).

If lost, users will need to re-authenticate. Tokens become invalid.

## 7.6 Terraform State Recovery

### State File Corrupted

S3 bucket has versioning. Restore previous version:

1. Go to Scaleway Console > Object Storage
2. Select bucket `{project}-terraform-state-prod-0`
3. Find the state file
4. Restore previous version

### State File Lost

Worst case - need to import all resources.

```bash
# Import each resource
terraform import scaleway_instance_server.tools_prod fr-par-1/INSTANCE_ID
terraform import scaleway_rdb_instance.postgres fr-par/INSTANCE_ID
# ... repeat for all resources
```

This is tedious. Keep backups.

## 7.7 DNS Recovery

### If Scaleway DNS Unavailable

Update nameservers at domain registrar to point elsewhere temporarily.

### If Records Deleted

Terraform state contains record IDs. Run:
```bash
cd terraform-scaleway-infra
terraform apply
```

## 7.8 Recovery Checklist

### Server Down
- [ ] Check Scaleway Console - is server running?
- [ ] Try SSH
- [ ] Use emergency console if SSH fails
- [ ] Check disk space, memory
- [ ] Check docker service: `systemctl status docker`
- [ ] Restart docker: `systemctl restart docker`

### Application Down
- [ ] Check container: `docker ps`
- [ ] Check logs: `docker logs {container}`
- [ ] Check disk space
- [ ] Restart container: `docker restart {container}`
- [ ] Redeploy via Ansible

### Database Unavailable
- [ ] Check Scaleway Console for database status
- [ ] Check network connectivity from server
- [ ] Test connection: `psql "postgresql://user:pass@host:5432/db"`
- [ ] Restore from backup if needed

### SSO Down
- [ ] Check Authentik containers
- [ ] Check Authentik database
- [ ] Restart Authentik
- [ ] If database corrupted, restore from backup

## 7.9 Contact Points

### Scaleway Support

For infrastructure issues:
- Console: https://console.scaleway.com > Support
- Status: https://status.scaleway.com

### Service Dependencies

| Service | Depends On |
|---------|-----------|
| All apps | Traefik, Authentik |
| Authentik | PostgreSQL |
| Monitoring | PostgreSQL (Zabbix) |
| All apps | PostgreSQL (most) |
