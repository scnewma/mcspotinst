#!/bin/bash

set -euo pipefail

BUCKET=scnewma-minecraft
REPO=https://github.com/scnewma/mcspotinst

apt update
apt install -y awscli git

git clone $REPO /opt/mctools

aws s3 cp s3://$BUCKET/.env /opt/mctools/.env

source /opt/mctools/.env

for f in $(find . -name '[0-9][0-9]*.sh' | sort); do
    /bin/bash $f
done
