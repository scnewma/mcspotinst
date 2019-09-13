#!/bin/bash

set -euo pipefail

: "${RCON_CLI_VERSION:=1.4.6}"

curl -fsSL -o /tmp/rcon-cli.tar.gz https://github.com/itzg/rcon-cli/releases/download/${RCON_CLI_VERSION}/rcon-cli_${RCON_CLI_VERSION}_linux_amd64.tar.gz
mkdir -p /opt/rcon-cli
tar x -f /tmp/rcon-cli.tar.gz -C /opt/rcon-cli
rm /tmp/rcon-cli.tar.gz
mv /opt/rcon-cli/rcon-cli /usr/local/bin
