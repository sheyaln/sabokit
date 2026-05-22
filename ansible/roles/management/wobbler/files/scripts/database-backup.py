#!/usr/bin/env python3
"""
Scaleway Managed Database Backup Manager

Creates on-demand backups for Scaleway managed databases and maintains retention.
This handles database-level backups (for easy single-database restoration),
not instance snapshots (which are handled by Scaleway's automatic backup feature).
"""

import argparse
import logging
import os
import sys
import time
from datetime import datetime, timedelta, timezone
from typing import Optional

import requests

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(levelname)s - %(message)s",
    handlers=[logging.StreamHandler(sys.stdout)],
)
logger = logging.getLogger(__name__)


class ScalewayDatabaseBackupManager:
    """Manages Scaleway managed database backups."""

    API_BASE = "https://api.scaleway.com"

    def __init__(
        self,
        access_key: str,
        secret_key: str,
        project_id: str,
        region: str = "fr-par",
    ):
        self.access_key = access_key
        self.secret_key = secret_key
        self.project_id = project_id
        self.region = region
        self.headers = {
            "X-Auth-Token": secret_key,
            "Content-Type": "application/json",
        }

    def _request(
        self, method: str, endpoint: str, data: Optional[dict] = None
    ) -> dict:
        """Make an API request to Scaleway."""
        url = f"{self.API_BASE}{endpoint}"
        response = requests.request(
            method, url, headers=self.headers, json=data, timeout=60
        )

        if response.status_code >= 400:
            logger.error(f"API error: {response.status_code} - {response.text}")
            response.raise_for_status()

        return response.json() if response.text else {}

    def list_instances(self) -> list:
        """List all database instances."""
        endpoint = f"/rdb/v1/regions/{self.region}/instances?project_id={self.project_id}"
        result = self._request("GET", endpoint)
        return result.get("instances", [])

    def get_instance_by_name(self, name: str) -> Optional[dict]:
        """Get a database instance by name."""
        instances = self.list_instances()
        for instance in instances:
            if instance["name"] == name:
                return instance
        return None

    def get_instance_status(self, instance_id: str) -> str:
        """Get the current status of an instance."""
        endpoint = f"/rdb/v1/regions/{self.region}/instances/{instance_id}"
        result = self._request("GET", endpoint)
        return result.get("status", "unknown")

    def wait_for_instance_ready(
        self, instance_id: str, timeout: int = 300, poll_interval: int = 5
    ) -> bool:
        """Wait for instance to return to ready state."""
        start_time = time.time()
        while time.time() - start_time < timeout:
            status = self.get_instance_status(instance_id)
            if status == "ready":
                return True
            if status in ("error", "locked", "deleting"):
                logger.error(f"Instance in unexpected state: {status}")
                return False
            time.sleep(poll_interval)
        logger.error(f"Timeout waiting for instance to be ready (waited {timeout}s)")
        return False

    def list_databases(self, instance_id: str) -> list:
        """List all databases in an instance."""
        endpoint = f"/rdb/v1/regions/{self.region}/instances/{instance_id}/databases"
        result = self._request("GET", endpoint)
        return result.get("databases", [])

    def list_backups(self, instance_id: str, database_name: Optional[str] = None) -> list:
        """List backups for an instance, optionally filtered by database name."""
        endpoint = f"/rdb/v1/regions/{self.region}/backups?instance_id={instance_id}"
        if database_name:
            endpoint += f"&database_name={database_name}"
        result = self._request("GET", endpoint)
        return result.get("database_backups", [])

    def create_backup(
        self,
        instance_id: str,
        database_name: str,
        backup_name: str,
        expires_at: Optional[str] = None,
    ) -> dict:
        """Create a backup for a specific database."""
        endpoint = f"/rdb/v1/regions/{self.region}/backups"
        data = {
            "instance_id": instance_id,
            "database_name": database_name,
            "name": backup_name,
        }
        if expires_at:
            data["expires_at"] = expires_at
        return self._request("POST", endpoint, data)

    def delete_backup(self, backup_id: str) -> None:
        """Delete a backup."""
        endpoint = f"/rdb/v1/regions/{self.region}/backups/{backup_id}"
        self._request("DELETE", endpoint)

    def backup_instance(
        self,
        instance_name: str,
        databases: Optional[list] = None,
        retention_days: int = 7,
        exclude_system: bool = True,
    ) -> tuple[int, int]:
        """
        Create backups for all databases in an instance.
        
        Returns: (success_count, total_count)
        """
        instance = self.get_instance_by_name(instance_name)
        if not instance:
            logger.error(f"Instance not found: {instance_name}")
            return (0, 0)

        instance_id = instance["id"]
        all_databases = self.list_databases(instance_id)
        
        # Filter databases
        if databases:
            db_names = [db["name"] for db in all_databases if db["name"] in databases]
        else:
            db_names = [db["name"] for db in all_databases]
            
        # Exclude system databases
        system_dbs = {"rdb", "postgres", "template0", "template1"}
        if exclude_system:
            db_names = [name for name in db_names if name not in system_dbs]

        if not db_names:
            logger.warning(f"No databases to backup for instance: {instance_name}")
            return (0, 0)

        timestamp = datetime.now(timezone.utc).strftime("%Y%m%d-%H%M%S")
        expires_at = (datetime.now(timezone.utc) + timedelta(days=retention_days)).isoformat()
        
        success_count = 0
        for i, db_name in enumerate(db_names):
            backup_name = f"auto-{instance_name}-{db_name}-{timestamp}"
            logger.info(f"Creating backup ({i+1}/{len(db_names)}): {backup_name}")
            
            try:
                result = self.create_backup(
                    instance_id=instance_id,
                    database_name=db_name,
                    backup_name=backup_name,
                    expires_at=expires_at,
                )
                backup = result.get("database_backup", {})
                logger.info(f"Backup created: {backup.get('id', 'unknown')} (expires: {expires_at[:10]})")
                success_count += 1
                
                # Wait for instance to be ready before next backup
                # (Scaleway only allows one backup operation at a time)
                if i < len(db_names) - 1:
                    logger.info("Waiting for instance to be ready...")
                    if not self.wait_for_instance_ready(instance_id, timeout=600):
                        logger.error("Instance did not return to ready state, aborting remaining backups")
                        break
                        
            except requests.HTTPError as e:
                logger.error(f"Failed to create backup for {db_name}: {e}")
                # Wait anyway in case instance is in transient state
                time.sleep(5)
                if not self.wait_for_instance_ready(instance_id, timeout=300):
                    logger.error("Instance did not return to ready state, aborting remaining backups")
                    break

        return (success_count, len(db_names))

    def cleanup_old_backups(
        self,
        instance_name: str,
        retention_count: int = 3,
    ) -> int:
        """Delete old backups beyond the retention count per database."""
        instance = self.get_instance_by_name(instance_name)
        if not instance:
            logger.error(f"Instance not found: {instance_name}")
            return 0

        instance_id = instance["id"]
        all_backups = self.list_backups(instance_id)
        
        # Filter to only auto-created backups
        auto_backups = [b for b in all_backups if b["name"].startswith("auto-")]
        
        # Group by database name
        by_database: dict[str, list] = {}
        for backup in auto_backups:
            db_name = backup["database_name"]
            if db_name not in by_database:
                by_database[db_name] = []
            by_database[db_name].append(backup)

        total_deleted = 0
        for db_name, backups in by_database.items():
            # Sort by creation date (newest first)
            backups.sort(key=lambda b: b.get("created_at", ""), reverse=True)
            
            if len(backups) > retention_count:
                to_delete = backups[retention_count:]
                logger.info(
                    f"Database {db_name}: found {len(backups)} backups, "
                    f"deleting {len(to_delete)} (keeping {retention_count})"
                )
                
                for backup in to_delete:
                    backup_id = backup["id"]
                    backup_name = backup["name"]
                    logger.info(f"Deleting backup: {backup_name}")
                    try:
                        self.delete_backup(backup_id)
                        total_deleted += 1
                    except requests.HTTPError as e:
                        logger.error(f"Failed to delete backup {backup_name}: {e}")
            else:
                logger.info(
                    f"Database {db_name}: {len(backups)} backups, "
                    f"no cleanup needed (retention: {retention_count})"
                )

        return total_deleted


def main():
    parser = argparse.ArgumentParser(
        description="Scaleway Managed Database Backup Manager"
    )
    parser.add_argument(
        "--action",
        choices=["backup", "list", "cleanup"],
        default="backup",
        help="Action to perform (default: backup)",
    )
    parser.add_argument(
        "--instance",
        help="Target a specific database instance by name",
    )
    parser.add_argument(
        "--database",
        help="Target specific databases (comma-separated). Leave empty for all.",
    )
    parser.add_argument(
        "--retention-days",
        type=int,
        default=7,
        help="Number of days before backup expires (default: 7)",
    )
    parser.add_argument(
        "--retention-count",
        type=int,
        default=3,
        help="Max backups to keep per database during cleanup (default: 3)",
    )
    parser.add_argument(
        "--include-system",
        action="store_true",
        help="Include system databases (rdb, postgres, etc.)",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Show what would be done without making changes",
    )

    args = parser.parse_args()

    # Get credentials from environment
    access_key = os.environ.get("SCW_ACCESS_KEY", "")
    secret_key = os.environ.get("SCW_SECRET_KEY", "")
    project_id = os.environ.get("SCW_PROJECT_ID", "")

    if not all([access_key, secret_key, project_id]):
        logger.error("Missing Scaleway credentials (SCW_ACCESS_KEY, SCW_SECRET_KEY, SCW_PROJECT_ID)")
        sys.exit(1)

    manager = ScalewayDatabaseBackupManager(
        access_key=access_key,
        secret_key=secret_key,
        project_id=project_id,
    )

    # Get instances to backup
    if args.instance:
        instances = [args.instance]
    else:
        all_instances = manager.list_instances()
        instances = [i["name"] for i in all_instances]

    if not instances:
        logger.error("No database instances found")
        sys.exit(1)

    # Parse database filter
    databases = None
    if args.database:
        databases = [d.strip() for d in args.database.split(",")]

    if args.action == "list":
        for instance_name in instances:
            instance = manager.get_instance_by_name(instance_name)
            if not instance:
                print(f"\n=== Instance not found: {instance_name} ===")
                continue
                
            print(f"\n=== Backups for {instance_name} ===")
            backups = manager.list_backups(instance["id"])
            
            if not backups:
                print("  No backups found")
            else:
                # Group by database
                by_db: dict[str, list] = {}
                for b in backups:
                    db = b["database_name"]
                    if db not in by_db:
                        by_db[db] = []
                    by_db[db].append(b)
                
                for db_name, db_backups in sorted(by_db.items()):
                    print(f"\n  Database: {db_name}")
                    db_backups.sort(key=lambda b: b.get("created_at", ""), reverse=True)
                    for b in db_backups:
                        status = b.get("status", "unknown")
                        created = b.get("created_at", "unknown")[:19]
                        expires = b.get("expires_at", "never")[:10] if b.get("expires_at") else "never"
                        size_mb = b.get("size", 0) / (1024 * 1024)
                        print(f"    - {b['name']}")
                        print(f"      Status: {status}, Created: {created}, Expires: {expires}, Size: {size_mb:.1f} MB")
        return

    if args.action == "backup":
        print("=== Starting Scaleway Database Backup ===")
        print(f"Instances: {', '.join(instances)}")
        print(f"Retention: {args.retention_days} days")
        if databases:
            print(f"Databases: {', '.join(databases)}")
        print("")

        total_success = 0
        total_count = 0
        
        for instance_name in instances:
            print(f"--- Backing up: {instance_name} ---")
            
            if args.dry_run:
                instance = manager.get_instance_by_name(instance_name)
                if instance:
                    dbs = manager.list_databases(instance["id"])
                    db_names = [d["name"] for d in dbs if d["name"] not in {"rdb", "postgres"} or args.include_system]
                    if databases:
                        db_names = [d for d in db_names if d in databases]
                    print(f"[DRY RUN] Would backup databases: {', '.join(db_names)}")
                    total_count += len(db_names)
                    total_success += len(db_names)
            else:
                success, count = manager.backup_instance(
                    instance_name=instance_name,
                    databases=databases,
                    retention_days=args.retention_days,
                    exclude_system=not args.include_system,
                )
                total_success += success
                total_count += count
                
                if success == count and count > 0:
                    print(f"[OK] Backed up {success}/{count} databases")
                elif success > 0:
                    print(f"[PARTIAL] Backed up {success}/{count} databases")
                else:
                    print(f"[FAILED] Could not backup any databases")

        print(f"\n=== Backup Complete ===")
        print(f"Databases backed up: {total_success}/{total_count}")

    if args.action == "cleanup":
        print("=== Cleaning up old database backups ===")
        print(f"Retention: {args.retention_count} backups per database")
        print("")
        
        total_deleted = 0
        for instance_name in instances:
            print(f"--- Cleaning: {instance_name} ---")
            
            if args.dry_run:
                instance = manager.get_instance_by_name(instance_name)
                if instance:
                    backups = manager.list_backups(instance["id"])
                    auto_backups = [b for b in backups if b["name"].startswith("auto-")]
                    by_db: dict[str, int] = {}
                    for b in auto_backups:
                        db = b["database_name"]
                        by_db[db] = by_db.get(db, 0) + 1
                    for db, count in by_db.items():
                        if count > args.retention_count:
                            print(f"[DRY RUN] {db}: would delete {count - args.retention_count} old backups")
            else:
                deleted = manager.cleanup_old_backups(
                    instance_name=instance_name,
                    retention_count=args.retention_count,
                )
                total_deleted += deleted
                if deleted > 0:
                    print(f"[OK] Deleted {deleted} old backups")
                else:
                    print(f"[OK] No cleanup needed")

        print(f"\n=== Cleanup Complete ===")
        print(f"Total backups deleted: {total_deleted}")


if __name__ == "__main__":
    main()

