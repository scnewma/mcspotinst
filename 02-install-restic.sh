#!/bin/bash

set -euo pipefail

: "${RESTIC_VERSION:=0.9.5}"

curl -fsSL -o /tmp/restic.bz2 https://github.com/restic/restic/releases/download/v${RESTIC_VERSION}/restic_${RESTIC_VERSION}_linux_amd64.bz2
bunzip2 /tmp/restic.bz2
mv /tmp/restic /usr/local/bin
chmod +x /usr/local/bin/restic
