# Systemd Service for Persistent Reverse SSH Tunnel

This directory contains a systemd unit file to run the reverse SSH tunnel as a persistent service on Linux targets.

## Installation

1. Copy the service file to `/etc/systemd/system/`:
   ```bash
   sudo cp reverse-ssh.service /etc/systemd/system/