#!/bin/bash

set -euo pipefail

: "${MC_VERSION:=latest}"
: "${MC_DIR:=/opt/minecraft}"
: "${RESTIC_BUCKET:=scnewma-minecraft}"
: "${RESTIC_PASSWORD:=password}"
: "${RESTIC_BACKUP:=latest}"
: "${RESTIC_TAGS:=mc_backup}" # comma separated

useradd --system --create-home \
    --user-group --home-dir /opt/minecraft -s /bin/false minecraft \
    || echo "User already exists."

apt update
apt install -y openjdk-8-jre-headless jq

VERSION_ENDPOINT=https://launchermeta.mojang.com/mc/game/version_manifest.json

case "X$MC_VERSION" in
    X|XLATEST|Xlatest)
        VANILLA_VERSION=$(curl -fsSL $VERSION_ENDPOINT | jq -r '.latest.release')
        ;;
    XSNAPSHOT|Xsnapshot)
        VANILLA_VERSION=$(curl -fsSL $VERSION_ENDPOINT | jq -r '.latest.snapshot')
        ;;
    X[1-9]*)
        VANILLA_VERSION=$VERSION
        ;;
    *)
        VANILLA_VERSION=$(curl -fsSL $VERSION_ENDPOINT | jq -r '.latest.release')
        ;;
esac

SERVER="minecraft_server.${VANILLA_VERSION// /_}.jar"

if [ ! -e "${MC_DIR}/${SERVER}" ]; then
    echo "Downloading $SERVER"
    versionManifestURL=$(curl -fsSL $VERSION_ENDPOINT | \
        jq --arg VANILLA_VERSION "$VANILLA_VERSION" --raw-output \
        '[.versions[] | select(.id == $VANILLA_VERSION)][0].url')

    serverDownloadURL=$(curl -fsSL "$versionManifestURL" | \
        jq --raw-output '.downloads.server.url')

    curl -fsSL -o "${MC_DIR}/${SERVER}" "$serverDownloadURL"
fi

# restore latest backup
export RESTIC_REPOSITORY="s3:s3.amazonaws.com/$RESTIC_BUCKET"

restic restore --tag "$RESTIC_TAGS" "$RESTIC_BACKUP" --target "$MC_DIR"

# run it
cat <<EOF > /etc/systemd/system/minecraft.service
[Unit]
Description=Minecraft Server
After=network.target

[Service]
User=minecraft
Nice=1
KillMode=none
SuccessExitStatus=0 1
ProtectHome=true
ProtectSystem=full
PrivateDevices=true
NoNewPrivileges=true
WorkingDirectory=${MC_DIR}
ExecStart=/usr/bin/java -Xmx1024M -Xms512M -jar "${SERVER}" nogui
ExecStop=/usr/local/bin/rcon-cli stop

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl start minecraft
systemctl enable minecraft

ufw allow 25565/tcp
