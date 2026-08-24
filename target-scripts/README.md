# Target Scripts

This directory contains scripts that run on the target machine to establish a reverse SSH tunnel.

## Scripts Overview

| Script | Description |
|--------|-------------|
| `reverse-ssh.sh` | Main script with config file support, logging, and manual reconnection loop. |
| `reverse-ssh-autossh.sh` | Variant using `autossh` for automatic reconnection. |
| `reverse-ssh-netcat.sh` | Reverse tunnel to a `netcat`/`socat` listener that spawns a shell. |
| `target.env.example` | Example environment configuration file. |

## Configuration

All scripts can be configured via an environment file (default `./target.env`) or via command-line options.

### Environment Variables

Copy `target.env.example` to `target.env` and edit:

```bash
cp target.env.example target.env
nano target.env