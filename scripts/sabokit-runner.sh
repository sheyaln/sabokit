#!/usr/bin/env bash
# sabokit-runner — consumer-facing wrapper around the sabokit ansible
# runner image (ghcr.io/sheyaln/sabokit-runner). Hides the docker
# invocation behind friendly flags so consumers don't need to remember the
# mount + ssh-agent dance every time.
#
# The image is pinned to a tag matching this wrapper's version by default
# (so a consumer running sabokit-runner v3.0.0 gets the v3.0.0 image). Override
# with --image to pull a different tag (e.g. while testing pre-release).
#
# Install: drop on $PATH and chmod +x. Or curl-install one-shot:
#   curl -fsSL https://raw.githubusercontent.com/sheyaln/sabokit/v3.0.0/scripts/sabokit-runner.sh \
#     -o /usr/local/bin/sabokit-runner && chmod +x /usr/local/bin/sabokit-runner
#
# Bash 3.2 compatible (macOS default).

set -euo pipefail

# Version the wrapper ships at. release.sh's ref-bump should not touch this —
# it's hand-bumped at the start of a release cycle.
SABOKIT_RUNNER_VERSION="v3.0.0"

print_help() {
  cat <<'EOF'
sabokit-runner — deploy sabokit via the published runner image

Usage:
  sabokit-runner [OPTIONS]

Targeting (combinable):
  -a, --apps LIST         comma-sep app slugs (e.g. outline,n8n)
  -s, --servers LIST      comma-sep host or group (e.g. tools-prod,management)
                          alias: --hosts
  -b, --base              base layer only (docker + traefik + secrets agent)
  -B, --no-base           skip base layer (fast app redeploy)
  -S, --rotate-secrets    re-fetch secrets + re-render env files + restart on change

Modes:
  -c, --check             dry-run with diff
  -v, --verbose           more ansible noise (repeatable: -vv, -vvv)
  -n, --dry-run           print the docker invocation, don't run it

Paths:
  -i, --inventory FILE    inventory path inside --env dir (default: inventory.ini)
  -e, --enabled-apps FILE enabled_apps json inside --env dir (default: enabled_apps.json)
      --env DIR           consumer env dir, mounted at /env:ro (default: ./env)
      --overlay DIR       optional overlay dir, mounted at /consumer:ro
                          /consumer/roles prepended after upstream roles_path
                          /consumer/extensions.yml (if present) runs after upstream's site.yml
      --image TAG         runner image tag (default: matches wrapper version)

  -h, --help              this message

Examples:
  sabokit-runner                                            # full deploy
  sabokit-runner --apps outline                             # redeploy one app
  sabokit-runner --apps outline,n8n --no-base               # fast multi-app redeploy
  sabokit-runner --servers tools-prod                       # reprovision one host
  sabokit-runner --base --servers authentik-prod            # base only, one host
  sabokit-runner --rotate-secrets                           # rotate all secrets, all hosts
  sabokit-runner --rotate-secrets --servers tools-prod      # rotate secrets, one host
  sabokit-runner --apps outline --check                     # plan a single app
  sabokit-runner --overlay ansible-local                    # with consumer extensions

Raw docker invocation (what the wrapper builds): see docker/runner/README.md
EOF
}

# Defaults — overridable via flags.
ENV_DIR="./env"
OVERLAY_DIR=""
INVENTORY_FILE="inventory.ini"
ENABLED_APPS_FILE="enabled_apps.json"
IMAGE_TAG=""
DRY_RUN=0
CHECK=0
VERBOSITY=0

# Targeting buckets — joined later. Bash 3.2 friendly (plain strings, not arrays).
APPS=""
SERVERS=""
BASE_ONLY=0
NO_BASE=0
ROTATE_SECRETS=0

# Append-to-comma-list helper. Bash 3.2: pass-by-name via eval (safe for the
# fixed set of varnames below).
append_csv() {
  local varname="$1" value="$2" current
  eval "current=\${$varname}"
  if [[ -z "$current" ]]; then
    eval "$varname=\$value"
  else
    eval "$varname=\$current,\$value"
  fi
}

# Long-option parser — bash getopts only handles short flags. Hand-rolled
# loop covers both. Order-independent. Long options accept --flag=value or
# --flag value; short options accept -fvalue or -f value.
while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help) print_help; exit 0 ;;

    -a|--apps)        append_csv APPS "$2"; shift 2 ;;
    --apps=*)         append_csv APPS "${1#*=}"; shift ;;
    -s|--servers|--hosts) append_csv SERVERS "$2"; shift 2 ;;
    --servers=*|--hosts=*) append_csv SERVERS "${1#*=}"; shift ;;

    -b|--base)            BASE_ONLY=1; shift ;;
    -B|--no-base)         NO_BASE=1; shift ;;
    -S|--rotate-secrets)  ROTATE_SECRETS=1; shift ;;

    -c|--check)    CHECK=1; shift ;;
    -v|--verbose)  VERBOSITY=$((VERBOSITY + 1)); shift ;;
    -vv)           VERBOSITY=$((VERBOSITY + 2)); shift ;;
    -vvv)          VERBOSITY=$((VERBOSITY + 3)); shift ;;
    -n|--dry-run)  DRY_RUN=1; shift ;;

    -i|--inventory)    INVENTORY_FILE="$2"; shift 2 ;;
    --inventory=*)     INVENTORY_FILE="${1#*=}"; shift ;;
    -e|--enabled-apps) ENABLED_APPS_FILE="$2"; shift 2 ;;
    --enabled-apps=*)  ENABLED_APPS_FILE="${1#*=}"; shift ;;
    --env)             ENV_DIR="$2"; shift 2 ;;
    --env=*)           ENV_DIR="${1#*=}"; shift ;;
    --overlay)         OVERLAY_DIR="$2"; shift 2 ;;
    --overlay=*)       OVERLAY_DIR="${1#*=}"; shift ;;
    --image)           IMAGE_TAG="$2"; shift 2 ;;
    --image=*)         IMAGE_TAG="${1#*=}"; shift ;;

    --) shift; break ;;  # everything after -- passes through to ansible-playbook untouched
    -*) echo "sabokit-runner: unknown flag: $1" >&2; echo "Run 'sabokit-runner --help' for usage." >&2; exit 2 ;;
    *)  echo "sabokit-runner: unexpected positional: $1" >&2; exit 2 ;;
  esac
done

# Mutex sanity checks — combinations that are silently broken under ansible's
# tag union semantics deserve an explicit error here.
if [[ $BASE_ONLY -eq 1 && $NO_BASE -eq 1 ]]; then
  echo "sabokit-runner: --base and --no-base are mutually exclusive." >&2; exit 2
fi
if [[ $BASE_ONLY -eq 1 && $ROTATE_SECRETS -eq 1 ]]; then
  echo "sabokit-runner: --base and --rotate-secrets are mutually exclusive (base layer doesn't fetch app secrets — for base credential rotation, just re-run --base)." >&2; exit 2
fi
if [[ $BASE_ONLY -eq 1 && -n "$APPS" ]]; then
  echo "sabokit-runner: --base and --apps are mutually exclusive." >&2; exit 2
fi

# Resolve image tag.
if [[ -z "$IMAGE_TAG" ]]; then
  IMAGE_TAG="$SABOKIT_RUNNER_VERSION"
fi
IMAGE="ghcr.io/sheyaln/sabokit-runner:${IMAGE_TAG}"

# Resolve env dir to absolute path so the docker mount works regardless of cwd.
if [[ ! -d "$ENV_DIR" ]]; then
  echo "sabokit-runner: --env directory not found: $ENV_DIR" >&2; exit 2
fi
ENV_ABS="$(cd "$ENV_DIR" && pwd)"
if [[ ! -f "$ENV_ABS/$INVENTORY_FILE" ]]; then
  echo "sabokit-runner: inventory not found at $ENV_ABS/$INVENTORY_FILE" >&2; exit 2
fi

# Build ansible flag list. Bash 3.2 — no arrays for portability across older
# macOS shells; the runner image's entrypoint is `ansible-playbook`, so the
# docker CMD is everything after the image name.
ANSIBLE_ARGS=()
ANSIBLE_ARGS+=(-i "/env/$INVENTORY_FILE")
if [[ -f "$ENV_ABS/$ENABLED_APPS_FILE" ]]; then
  ANSIBLE_ARGS+=(-e "@/env/$ENABLED_APPS_FILE")
fi

# Tag translation.
TAGS=""
SKIP_TAGS=""
if [[ $BASE_ONLY -eq 1 ]]; then
  TAGS="bootstrap"
fi
if [[ -n "$APPS" ]]; then
  append_csv TAGS "$APPS"
fi
if [[ $ROTATE_SECRETS -eq 1 ]]; then
  append_csv TAGS "secrets"
fi
if [[ $NO_BASE -eq 1 ]]; then
  SKIP_TAGS="bootstrap"
fi
[[ -n "$TAGS" ]] && ANSIBLE_ARGS+=(--tags "$TAGS")
[[ -n "$SKIP_TAGS" ]] && ANSIBLE_ARGS+=(--skip-tags "$SKIP_TAGS")
[[ -n "$SERVERS" ]] && ANSIBLE_ARGS+=(--limit "$SERVERS")

[[ $CHECK -eq 1 ]] && ANSIBLE_ARGS+=(--check --diff)

if [[ $VERBOSITY -gt 0 ]]; then
  v=""
  i=0
  while [[ $i -lt $VERBOSITY ]]; do v="${v}v"; i=$((i + 1)); done
  ANSIBLE_ARGS+=("-${v}")
fi

# Playbook positionals. Upstream's site.yml is first (always). Overlay's
# extensions.yml is appended when present — runs in the same ansible process
# so fact cache + ssh connections are shared.
PLAYBOOKS=("/opt/sabokit/platform/ansible/site.yml")
OVERLAY_ABS=""
if [[ -n "$OVERLAY_DIR" ]]; then
  if [[ ! -d "$OVERLAY_DIR" ]]; then
    echo "sabokit-runner: --overlay directory not found: $OVERLAY_DIR" >&2; exit 2
  fi
  OVERLAY_ABS="$(cd "$OVERLAY_DIR" && pwd)"
  if [[ -f "$OVERLAY_ABS/extensions.yml" ]]; then
    PLAYBOOKS+=("/consumer/extensions.yml")
  fi
fi

# Docker invocation.
DOCKER_ARGS=(run --rm)

# TTY only when stdin is a terminal — keeps CI runs from getting "the input
# device is not a TTY" failures.
if [[ -t 0 && -t 1 ]]; then
  DOCKER_ARGS+=(-it)
fi

DOCKER_ARGS+=(-v "${ENV_ABS}:/env:ro")
if [[ -n "$OVERLAY_ABS" ]]; then
  DOCKER_ARGS+=(-v "${OVERLAY_ABS}:/consumer:ro")
  # Prepend consumer roles to ansible's roles path (upstream still wins on conflict).
  DOCKER_ARGS+=(-e "ANSIBLE_ROLES_PATH=/opt/sabokit/platform/apps:/opt/sabokit/platform/base/ansible/roles:/consumer/roles")
fi

# SSH agent passthrough — only if the host has one running.
if [[ -n "${SSH_AUTH_SOCK:-}" && -S "$SSH_AUTH_SOCK" ]]; then
  DOCKER_ARGS+=(-v "${SSH_AUTH_SOCK}:/ssh-agent" -e "SSH_AUTH_SOCK=/ssh-agent")
fi

# Image + args.
DOCKER_ARGS+=("$IMAGE")
DOCKER_ARGS+=("${PLAYBOOKS[@]}")
DOCKER_ARGS+=("${ANSIBLE_ARGS[@]}")

# Anything after -- on the command line passes through verbatim. Useful for
# ansible flags the wrapper doesn't expose explicitly (--start-at-task,
# --syntax-check, etc.).
if [[ $# -gt 0 ]]; then
  DOCKER_ARGS+=("$@")
fi

if [[ $DRY_RUN -eq 1 ]]; then
  printf 'docker'
  for a in "${DOCKER_ARGS[@]}"; do printf ' %q' "$a"; done
  printf '\n'
  exit 0
fi

exec docker "${DOCKER_ARGS[@]}"
