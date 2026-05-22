#!/usr/bin/env python3
"""
Scaleway Disk Snapshot Manager

Creates daily snapshots for specified servers and maintains a rolling retention.
Supports both Instance volumes (l_ssd) and Block Storage volumes (sbs_*).
"""

import argparse
import json
import logging
import os
import sys
from datetime import datetime, timezone
from typing import Optional

import requests

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(levelname)s - %(message)s",
    handlers=[logging.StreamHandler(sys.stdout)],
)
logger = logging.getLogger(__name__)


class ScalewaySnapshotManager:
    """Manages Scaleway instance and block storage snapshots."""

    API_BASE = "https://api.scaleway.com"

    def __init__(
        self,
        access_key: str,
        secret_key: str,
        project_id: str,
        region: str = "fr-par",
        zone: str = "fr-par-1",
    ):
        self.access_key = access_key
        self.secret_key = secret_key
        self.project_id = project_id
        self.region = region
        self.zone = zone
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
            method, url, headers=self.headers, json=data, timeout=30
        )

        if response.status_code >= 400:
            logger.error(f"API error: {response.status_code} - {response.text}")
            response.raise_for_status()

        return response.json() if response.text else {}

    def get_server_by_name(self, server_name: str) -> Optional[dict]:
        """Get server details by name."""
        endpoint = f"/instance/v1/zones/{self.zone}/servers?name={server_name}&project={self.project_id}"
        result = self._request("GET", endpoint)
        servers = result.get("servers", [])
        return servers[0] if servers else None

    def get_server_volumes(self, server_id: str) -> list:
        """Get volumes attached to a server (from full server details)."""
        endpoint = f"/instance/v1/zones/{self.zone}/servers/{server_id}"
        result = self._request("GET", endpoint)
        # Volumes are in the 'Volumes' key (capital V) for SBS volumes
        volumes = result.get("Volumes", [])
        if not volumes:
            # Fallback to lowercase 'volumes' for instance volumes
            server = result.get("server", {})
            volumes = list(server.get("volumes", {}).values())
        return volumes

    def _is_sbs_volume(self, volume: dict) -> bool:
        """Check if volume is SBS (block storage) type."""
        vol_type = volume.get("volume_type", "")
        return vol_type.startswith("sbs_") or vol_type.startswith("b_")

    def create_instance_snapshot(self, volume_id: str, name: str) -> dict:
        """Create a snapshot using Instance API (for l_ssd volumes)."""
        endpoint = f"/instance/v1/zones/{self.zone}/snapshots"
        data = {
            "name": name,
            "volume_id": volume_id,
            "project": self.project_id,
        }
        return self._request("POST", endpoint, data)

    def create_block_snapshot(self, volume_id: str, name: str) -> dict:
        """Create a snapshot using Block Storage API (for sbs_* volumes)."""
        endpoint = f"/block/v1alpha1/zones/{self.zone}/snapshots"
        data = {
            "name": name,
            "volume_id": volume_id,
            "project_id": self.project_id,
        }
        return self._request("POST", endpoint, data)

    def list_instance_snapshots(self, name_prefix: Optional[str] = None) -> list:
        """List Instance API snapshots."""
        endpoint = f"/instance/v1/zones/{self.zone}/snapshots?project={self.project_id}"
        result = self._request("GET", endpoint)
        snapshots = result.get("snapshots", [])

        if name_prefix:
            snapshots = [s for s in snapshots if s["name"].startswith(name_prefix)]

        # Normalize format
        for s in snapshots:
            s["_api"] = "instance"
        return snapshots

    def list_block_snapshots(self, name_prefix: Optional[str] = None) -> list:
        """List Block Storage API snapshots."""
        endpoint = f"/block/v1alpha1/zones/{self.zone}/snapshots?project_id={self.project_id}"
        result = self._request("GET", endpoint)
        snapshots = result.get("snapshots", [])

        if name_prefix:
            snapshots = [s for s in snapshots if s["name"].startswith(name_prefix)]

        # Normalize format - block API uses created_at instead of creation_date
        for s in snapshots:
            s["_api"] = "block"
            if "created_at" in s and "creation_date" not in s:
                s["creation_date"] = s["created_at"]
        return snapshots

    def list_snapshots(self, name_prefix: Optional[str] = None) -> list:
        """List all snapshots from both APIs."""
        instance_snaps = self.list_instance_snapshots(name_prefix)
        block_snaps = self.list_block_snapshots(name_prefix)
        return instance_snaps + block_snaps

    def delete_instance_snapshot(self, snapshot_id: str) -> None:
        """Delete an Instance API snapshot."""
        endpoint = f"/instance/v1/zones/{self.zone}/snapshots/{snapshot_id}"
        self._request("DELETE", endpoint)

    def delete_block_snapshot(self, snapshot_id: str) -> None:
        """Delete a Block Storage API snapshot."""
        endpoint = f"/block/v1alpha1/zones/{self.zone}/snapshots/{snapshot_id}"
        self._request("DELETE", endpoint)

    def delete_snapshot(self, snapshot: dict) -> None:
        """Delete a snapshot using the appropriate API."""
        snapshot_id = snapshot["id"]
        if snapshot.get("_api") == "block":
            self.delete_block_snapshot(snapshot_id)
        else:
            self.delete_instance_snapshot(snapshot_id)

    def create_server_snapshot(self, server_name: str) -> bool:
        """Create snapshots for all volumes of a server."""
        logger.info(f"Creating snapshot for server: {server_name}")

        server = self.get_server_by_name(server_name)
        if not server:
            logger.error(f"Server not found: {server_name}")
            return False

        volumes = self.get_server_volumes(server["id"])
        if not volumes:
            logger.error(f"No volumes found for server: {server_name}")
            return False

        timestamp = datetime.now(timezone.utc).strftime("%Y%m%d-%H%M%S")

        for volume in volumes:
            volume_id = volume["id"]
            volume_name = volume.get("name", "root")
            snapshot_name = f"auto-{server_name}-{volume_name}-{timestamp}"
            is_sbs = self._is_sbs_volume(volume)

            logger.info(f"Creating {'SBS' if is_sbs else 'Instance'} snapshot: {snapshot_name} for volume {volume_id}")
            try:
                if is_sbs:
                    result = self.create_block_snapshot(volume_id, snapshot_name)
                else:
                    result = self.create_instance_snapshot(volume_id, snapshot_name)
                snapshot = result.get("snapshot", {})
                logger.info(f"Snapshot created: {snapshot.get('id', 'unknown')}")
            except requests.HTTPError as e:
                logger.error(f"Failed to create snapshot for {volume_name}: {e}")
                return False

        return True

    def cleanup_old_snapshots(self, server_name: str, retention_count: int = 3) -> int:
        """Delete old snapshots beyond the retention count."""
        prefix = f"auto-{server_name}-"
        snapshots = self.list_snapshots(name_prefix=prefix)

        # Sort by creation date (newest first)
        snapshots.sort(
            key=lambda s: s.get("creation_date", ""), reverse=True
        )

        deleted_count = 0
        if len(snapshots) > retention_count:
            to_delete = snapshots[retention_count:]
            logger.info(
                f"Found {len(snapshots)} snapshots for {server_name}, "
                f"deleting {len(to_delete)} old snapshots (keeping {retention_count})"
            )

            for snapshot in to_delete:
                snapshot_id = snapshot["id"]
                snapshot_name = snapshot["name"]
                logger.info(f"Deleting snapshot: {snapshot_name} ({snapshot_id})")
                try:
                    self.delete_snapshot(snapshot)
                    deleted_count += 1
                except requests.HTTPError as e:
                    logger.error(f"Failed to delete snapshot {snapshot_name}: {e}")
        else:
            logger.info(
                f"Found {len(snapshots)} snapshots for {server_name}, "
                f"no cleanup needed (retention: {retention_count})"
            )

        return deleted_count


def main():
    parser = argparse.ArgumentParser(
        description="Scaleway Disk Snapshot Manager"
    )
    parser.add_argument(
        "--action",
        choices=["backup", "list", "cleanup"],
        default="backup",
        help="Action to perform (default: backup)",
    )
    parser.add_argument(
        "--server",
        help="Target a specific server (comma-separated for multiple)",
    )
    parser.add_argument(
        "--retention",
        type=int,
        default=3,
        help="Number of snapshots to retain per server (default: 3)",
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
    zone = os.environ.get("SCW_ZONE", "fr-par-1")

    if not all([access_key, secret_key, project_id]):
        logger.error("Missing Scaleway credentials (SCW_ACCESS_KEY, SCW_SECRET_KEY, SCW_PROJECT_ID)")
        sys.exit(1)

    manager = ScalewaySnapshotManager(
        access_key=access_key,
        secret_key=secret_key,
        project_id=project_id,
        zone=zone,
    )

    # Default servers if not specified
    default_servers = ["tools-prod", "management", "authentik-prod"]
    
    if args.server:
        servers = [s.strip() for s in args.server.split(",")]
    else:
        servers = default_servers

    if args.action == "list":
        for server_name in servers:
            prefix = f"auto-{server_name}-"
            snapshots = manager.list_snapshots(name_prefix=prefix)
            print(f"\n=== Snapshots for {server_name} ===")
            if not snapshots:
                print("  No snapshots found")
            else:
                snapshots.sort(key=lambda s: s.get("creation_date", ""), reverse=True)
                for s in snapshots:
                    print(f"  - {s['name']}")
                    print(f"    Created: {s.get('creation_date', 'unknown')}")
                    print(f"    Size: {s.get('size', 0) / (1024**3):.2f} GB")
        return

    if args.action == "backup":
        print("=== Starting Scaleway Disk Snapshot Backup ===")
        print(f"Servers: {', '.join(servers)}")
        print(f"Retention: {args.retention} snapshots per server")
        print("")

        success_count = 0
        for server_name in servers:
            if args.dry_run:
                print(f"[DRY RUN] Would create snapshot for: {server_name}")
                success_count += 1
            else:
                if manager.create_server_snapshot(server_name):
                    success_count += 1
                    print(f"[OK] Snapshot created for {server_name}")
                else:
                    print(f"[FAILED] Could not create snapshot for {server_name}")

        # Cleanup old snapshots
        print("\n=== Cleaning up old snapshots ===")
        total_deleted = 0
        for server_name in servers:
            if args.dry_run:
                prefix = f"auto-{server_name}-"
                snapshots = manager.list_snapshots(name_prefix=prefix)
                if len(snapshots) > args.retention:
                    print(f"[DRY RUN] Would delete {len(snapshots) - args.retention} old snapshots for {server_name}")
            else:
                deleted = manager.cleanup_old_snapshots(server_name, args.retention)
                total_deleted += deleted
                if deleted > 0:
                    print(f"[OK] Deleted {deleted} old snapshots for {server_name}")
                else:
                    print(f"[OK] No cleanup needed for {server_name}")

        print(f"\n=== Backup Complete ===")
        print(f"Snapshots created: {success_count}/{len(servers)}")
        if not args.dry_run:
            print(f"Old snapshots deleted: {total_deleted}")

    if args.action == "cleanup":
        print("=== Cleaning up old snapshots ===")
        total_deleted = 0
        for server_name in servers:
            if args.dry_run:
                prefix = f"auto-{server_name}-"
                snapshots = manager.list_snapshots(name_prefix=prefix)
                if len(snapshots) > args.retention:
                    print(f"[DRY RUN] Would delete {len(snapshots) - args.retention} old snapshots for {server_name}")
            else:
                deleted = manager.cleanup_old_snapshots(server_name, args.retention)
                total_deleted += deleted
                print(f"Deleted {deleted} old snapshots for {server_name}")

        print(f"\nTotal deleted: {total_deleted}")


if __name__ == "__main__":
    main()

