```bash
#!/usr/bin/env bash
#===============================================================================
# setup-attacker.sh - Configures an SSH server for reverse tunnel reception
#===============================================================================
# This script must be run as root on the attacker's server.
# It creates a low‑privilege user, generates an SSH key pair, and installs
# a hardened SSH configuration.
#
# Usage:
#   sudo ./setup-attacker.sh [options]
#
# Options:
#   -u USER       Username for tunnel account (default: revuser)
#   -k KEY_PATH   Path to save generated private key (default: /root/revuser_target_key)
#   -p PORT       SSH port for revuser (default: 22)
#   -h            Show help
#
#===============================================================================

set -euo pipefail

# Default values
TUNNEL_USER="revuser"
KEY_PATH="/root/revuser_target_key"
SSH_PORT=22
LOG_FILE="/var/log/setup-attacker.log"

# Colored output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log() {
    local level="$1"; shift
    local msg="$*"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${timestamp} [${level}] ${msg}" | tee -a "$LOG_FILE"
}

info()  { log "INFO"  "$@"; }
warn()  { log "WARN"  "$@"; }
error() { log "ERROR" "$@"; exit 1; }

usage() {
    cat <<EOF
Usage: $0 [options]

Options:
  -u USER       Username for tunnel account (default: revuser)
  -k KEY_PATH   Path to save generated private key (default: /root/revuser_target_key)
  -p PORT       SSH port for revuser (default: 22)
  -h            Show this help
EOF
    exit 0
}

# Parse arguments
while getopts "u:k:p:h" opt; do
    case "$opt" in
        u) TUNNEL_USER="$OPTARG" ;;
        k) KEY_PATH="$OPTARG" ;;
        p) SSH_PORT="$OPTARG" ;;
        h) usage ;;
        *) usage ;;
    esac
done

# Ensure root
if [[ $EUID -ne 0 ]]; then
    error "This script must be run as root. Use sudo."
fi

# Check SSH server installed
if ! command -v sshd >/dev/null 2>&1; then
    error "OpenSSH server (sshd) is not installed. Install it first."
fi

# Check if user already exists
if id "$TUNNEL_USER" &>/dev/null; then
    warn "User '$TUNNEL_USER' already exists. Skipping user creation."
else
    info "Creating user '$TUNNEL_USER'..."
    useradd -m -s /bin/false "$TUNNEL_USER"
    info "User created."
fi

# Create .ssh directory
info "Setting up SSH directory for '$TUNNEL_USER'..."
mkdir -p "/home/$TUNNEL_USER/.ssh"
chown "$TUNNEL_USER:$TUNNEL_USER" "/home/$TUNNEL_USER/.ssh"
chmod 700 "/home/$TUNNEL_USER/.ssh"

# Generate SSH key pair if not exists
if [[ -f "$KEY_PATH" ]]; then
    warn "Private key already exists at $KEY_PATH. Skipping generation."
else
    info "Generating Ed25519 SSH key pair..."
    ssh-keygen -t ed25519 -f "$KEY_PATH" -N "" -C "reverse-tunnel-target"
    info "Key generated."
fi

# Install public key
PUB_KEY="${KEY_PATH}.pub"
if [[ ! -f "$PUB_KEY" ]]; then
    error "Public key $PUB_KEY not found."
fi

info "Installing public key into authorized_keys with restrictions..."
# Restrict key to only allow TCP forwarding and specified ports
# Adjust ports as needed (2222 and 4444 are examples)
AUTH_KEYS="/home/$TUNNEL_USER/.ssh/authorized_keys"
{
    echo -n 'restrict,port-forwarding,permitopen="localhost:2222",permitopen="localhost:4444" '
    cat "$PUB_KEY"
} > "$AUTH_KEYS"

chown "$TUNNEL_USER:$TUNNEL_USER" "$AUTH_KEYS"
chmod 600 "$AUTH_KEYS"
info "Public key installed."

# Create hardened sshd_config snippet
SSHD_CONF_DIR="/etc/ssh/sshd_config.d"
mkdir -p "$SSHD_CONF_DIR"
SSHD_SNIPPET="$SSHD_CONF_DIR/revuser.conf"

info "Creating hardened SSH config for '$TUNNEL_USER' at $SSHD_SNIPPET..."
cat > "$SSHD_SNIPPET" <<EOF
# Managed by setup-attacker.sh
Match User $TUNNEL_USER
    AllowTcpForwarding yes
    PermitOpen localhost:2222 localhost:4444
    X11Forwarding no
    PermitTTY no
    ForceCommand /bin/false
    PasswordAuthentication no
    PubkeyAuthentication yes
    AllowUsers $TUNNEL_USER
EOF

chmod 600 "$SSHD_SNIPPET"
info "SSH config snippet created."

# Restart SSH service
info "Restarting SSH service..."
if systemctl is-active --quiet sshd; then
    systemctl restart sshd
elif systemctl is-active --quiet ssh; then
    systemctl restart ssh
else
    warn "Could not determine SSH service name. Please restart manually."
fi

# Output summary
info "Setup complete."
info "Private key saved to: $KEY_PATH"
info "Public key: $PUB_KEY"
info "Transfer the private key securely to the target machine."
echo
echo -e "${GREEN}Done.${NC} Copy the private key to the target and configure target-scripts/target.env accordingly."