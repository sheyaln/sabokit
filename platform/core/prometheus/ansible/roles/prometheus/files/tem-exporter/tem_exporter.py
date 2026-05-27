"""
Scaleway TEM Prometheus exporter.

Polls the Scaleway Transactional Email API on a fixed interval, computes
aggregate counters + per-flag rates over a rolling window, and exposes them
as Prometheus metrics on a local HTTP endpoint.

Scaleway TEM has no native /metrics surface. This exporter bridges that gap
so Grafana can build dashboards + Prometheus can fire alerts on bounce/
deferral/failure rates without a polling workflow living in n8n.

The TEM SMTP password (provisioned in platform/base/terraform/tem.tf) IS a
Scaleway IAM API key scoped to TransactionalEmailFullAccess, so we reuse it
here as the API auth token — no additional credential to manage.

Environment:
  SCW_SECRET_KEY        — Scaleway IAM key (= TEM SMTP password).
  SCW_PROJECT_ID        — Scaleway project ID to scope the query.
  SCW_REGION            — Scaleway region (default: fr-par; TEM lives in fr-par only).
  TEM_DOMAIN_ID         — Optional. Restrict metrics to one TEM domain.
  POLL_INTERVAL_SECONDS — How often to poll TEM (default: 60).
  LOOKBACK_MINUTES      — Rolling window for the per-flag list query (default: 60).
  LISTEN_PORT           — HTTP port to expose /metrics on (default: 9111).
"""

from __future__ import annotations

import logging
import os
import sys
import time
from typing import Any

import requests
from prometheus_client import Counter, Gauge, start_http_server

LOG = logging.getLogger("tem_exporter")
logging.basicConfig(
    level=os.environ.get("LOG_LEVEL", "INFO"),
    format="%(asctime)s %(levelname)s %(name)s %(message)s",
)

API_BASE = "https://api.scaleway.com/transactional-email/v1alpha1"

# Aggregate state counts. Gauges (point-in-time counts from the TEM stats endpoint,
# reflecting the project's all-time counts, not deltas).
tem_state = Gauge(
    "scaleway_tem_emails_total",
    "TEM email count per status (cumulative, from /statistics).",
    ["state"],
)

# Per-flag counter over the rolling window. Sums the count of emails in the
# lookback window whose `flags` list contains each flag.
tem_window_flags = Gauge(
    "scaleway_tem_window_flag_count",
    "TEM email count carrying a given flag in the lookback window.",
    ["flag"],
)

# Status counts in the rolling window — basis for rate calculation in Grafana.
tem_window_status = Gauge(
    "scaleway_tem_window_status_count",
    "TEM email count per status in the lookback window.",
    ["status"],
)

# Exporter health.
exporter_scrape_errors = Counter(
    "scaleway_tem_exporter_scrape_errors_total",
    "Total errors hit while polling the Scaleway TEM API.",
)
exporter_last_success = Gauge(
    "scaleway_tem_exporter_last_success_timestamp_seconds",
    "Unix timestamp of the last successful scrape.",
)


def _required_env(name: str) -> str:
    val = os.environ.get(name)
    if not val:
        LOG.error("missing required env: %s", name)
        sys.exit(2)
    return val


def fetch_stats(session: requests.Session, region: str, project_id: str,
                domain_id: str | None) -> dict[str, Any]:
    """Hit GET /regions/{region}/statistics. Cumulative state counts."""
    params: dict[str, str] = {"project_id": project_id}
    if domain_id:
        params["domain_id"] = domain_id
    r = session.get(f"{API_BASE}/regions/{region}/statistics",
                    params=params, timeout=20)
    r.raise_for_status()
    return r.json()


def fetch_window(session: requests.Session, region: str, project_id: str,
                 domain_id: str | None, since_iso: str) -> list[dict[str, Any]]:
    """Page through GET /regions/{region}/emails for the lookback window."""
    emails: list[dict[str, Any]] = []
    page = 1
    while True:
        params: dict[str, str | int] = {
            "project_id": project_id,
            "since": since_iso,
            "page": page,
            "page_size": 100,
        }
        if domain_id:
            params["domain_id"] = domain_id
        r = session.get(f"{API_BASE}/regions/{region}/emails",
                        params=params, timeout=30)
        r.raise_for_status()
        body = r.json()
        batch = body.get("emails", [])
        emails.extend(batch)
        # TEM returns total_count + paginates of page_size. Stop when we got
        # less than page_size (end of list) or hit a sanity cap.
        if len(batch) < 100 or len(emails) >= 10_000:
            break
        page += 1
    return emails


def update_metrics(stats: dict[str, Any], emails: list[dict[str, Any]]) -> None:
    # /statistics returns: total_count, new_count, sending_count, sent_count,
    # failed_count, canceled_count.
    for key in ("new", "sending", "sent", "failed", "canceled"):
        tem_state.labels(state=key).set(int(stats.get(f"{key}_count", 0) or 0))

    flag_counts: dict[str, int] = {}
    status_counts: dict[str, int] = {}
    for email in emails:
        status = email.get("status", "unknown")
        status_counts[status] = status_counts.get(status, 0) + 1
        for flag in email.get("flags", []) or []:
            flag_counts[flag] = flag_counts.get(flag, 0) + 1

    # Reset known labels by setting then re-set; prometheus_client retains
    # last value otherwise. Iterating only over seen flags is acceptable —
    # absent flags fall off naturally on the next /metrics read after the
    # client doesn't write them. To avoid stale carry, zero the known set.
    for flag in ("hard_bounce", "soft_bounce", "spam", "mailbox_full",
                 "mailbox_not_found", "greylisted", "blocklisted"):
        tem_window_flags.labels(flag=flag).set(flag_counts.get(flag, 0))
    for status in ("new", "sending", "sent", "failed", "canceled"):
        tem_window_status.labels(status=status).set(status_counts.get(status, 0))


def main() -> None:
    secret_key = _required_env("SCW_SECRET_KEY")
    project_id = _required_env("SCW_PROJECT_ID")
    region = os.environ.get("SCW_REGION", "fr-par")
    domain_id = os.environ.get("TEM_DOMAIN_ID") or None
    poll = int(os.environ.get("POLL_INTERVAL_SECONDS", "60"))
    lookback = int(os.environ.get("LOOKBACK_MINUTES", "60"))
    port = int(os.environ.get("LISTEN_PORT", "9111"))

    session = requests.Session()
    session.headers["X-Auth-Token"] = secret_key

    start_http_server(port)
    LOG.info("tem_exporter listening on :%d (poll=%ds, lookback=%dm)",
             port, poll, lookback)

    while True:
        try:
            since_epoch = time.time() - (lookback * 60)
            since_iso = time.strftime(
                "%Y-%m-%dT%H:%M:%SZ", time.gmtime(since_epoch))
            stats = fetch_stats(session, region, project_id, domain_id)
            emails = fetch_window(session, region, project_id, domain_id, since_iso)
            update_metrics(stats, emails)
            exporter_last_success.set(time.time())
            LOG.debug("scrape ok: %d emails in last %dm", len(emails), lookback)
        except Exception:
            exporter_scrape_errors.inc()
            LOG.exception("scrape failed")
        time.sleep(poll)


if __name__ == "__main__":
    main()
