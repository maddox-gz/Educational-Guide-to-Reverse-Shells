# Reverse SSH Tunnel Toolkit


![License](https://img.shields.io/badge/License-MIT-blue.svg)
![Platform](https://img.shields.io/badge/Platform-Linux%20%7C%20macOS-lightgrey)
![Status](https://img.shields.io/badge/Status-Educational-orange)

> **LEGAL DISCLAIMER**  
> This repository is intended **solely for educational purposes, authorized penetration testing, and legitimate remote administration**.  
> Unauthorized access to computer systems is illegal and may result in severe criminal and civil penalties.  
> **Always obtain explicit written permission** before using any technique or code contained herein.  
> The authors assume no liability for misuse.


## Overview

**Reverse SSH Tunnel Toolkit** demonstrates how to establish an encrypted, authenticated remote shell to a machine that is behind a firewall or NAT and **cannot accept inbound connections**.  
The target initiates an outbound SSH connection to a controlled server and creates a reverse port forward. The operator can then connect to a local port on that server to reach the target’s SSH daemon (or a custom listener), effectively gaining a shell.

This technique is commonly used by:

- System administrators for managing devices in restrictive networks
- Penetration testers during authorized engagements
- Security researchers studying network tunneling


## Features

- **Pure SSH** – uses only OpenSSH client/server, no extra dependencies
- **Automatic reconnection** via `autossh` (optional)
- **Systemd service** for persistence on Linux targets
- **Configurable** via environment file or command-line arguments
- **Comprehensive logging** with timestamps and log levels
- **Security hardened** setup script for the attacker’s server
- **Two reverse shell modes**:
  1. Reverse tunnel to the target’s own SSH server
  2. Reverse tunnel to a custom `netcat`/`socat` listener spawning `/bin/bash`
- **Detailed documentation** including architecture, security, and troubleshooting


## Quick Start

### 1. On the Attacker Server (public IP)

```bash
git clone https://github.com/maddox-gz/Educational-Guide-to-Reverse-Shells.git
cd reverse-ssh-tunnel-lab/attacker-setup
chmod +x setup-attacker.sh
sudo ./setup-attacker.sh