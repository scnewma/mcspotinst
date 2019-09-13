#!/bin/bash

set -euo pipefail

(
    crontab -l -u minecraft
    cat <<EOF
0 * * * *  /opt/mctools/backup.sh
EOF
) | crontab -u minecraft -
