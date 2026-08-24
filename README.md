# Educational-Guide-to-Reverse-Shells


## Legal Disclaimer
This information is provided for educational and authorized testing purposes only. Unauthorized access to computer systems is illegal. Always obtain explicit permission before using these techniques.


## What is a Reverse SSH Shell?
A traditional SSH connection flows from the client (attacker) to the server (target). If the target is behind a firewall or NAT, inbound SSH may be blocked. A reverse SSH tunnel reverses the direction: the target machine (client) connects outbound to an attacker‑controlled SSH server, then creates a tunnel that allows the attacker to connect back to the target’s SSH service (or any other port) through the established connection.

The result is a fully encrypted, authenticated channel that can be used to obtain a shell on the target.


## Scenario Overview

· Attacker Machine (public IP, SSH server running)
· Target Machine (behind firewall, outbound SSH allowed)

The target will run a script that:

1. Establishes an SSH connection to the attacker’s machine.
2. Sets up a reverse port forward (-R) so that a port on the attacker’s machine is forwarded to a port on the target (e.g., the target’s own SSH server or a netcat listener).
3. The attacker then connects to that local port on their own machine to gain access to the target.
