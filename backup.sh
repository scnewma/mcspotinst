#!/bin/bash

set -euo pipefail

# for this script to work;
# rcon needs to be enabled on
# the server, and the port/password
# need to be provided

: "${RCON_PORT:=25575}"
: "${RCON_PASSWORD:=minecraft}"
: "${MC_DIR:=/opt/minecraft}"
: "${RESTIC_BUCKET:=scnewma-minecraft}"
: "${RESTIC_PASSWORD:=password}"
: "${RESTIC_TAGS:=mc_backup}" # comma separated
: "${EXCLUDES:=*.jar,cache,logs}" # comma separated
: "${KEEP_HOURLY:=12}"
: "${KEEP_DAILY:=7}"
: "${KEEP_WEEKLY:=0}"
: "${KEEP_MONTHLY:=3}"
: "${KEEP_YEARLY:=5}"

source /opt/mctools/.env

export RESTIC_REPOSITORY="s3:s3.amazonaws.com/$RESTIC_BUCKET"
export RCON_PORT
export RCON_PASSWORD

retry() {
    local retries="${1}"
    local interval="${2}"
    readonly retries interval
    shift 2

    local i=-1
    while (( retries >= ++i )); do
        if output="$(timeout --signal=SIGINT --kill-after=30s 5m "${@}" 2>&1 | tr '\n' '\t')"; then
            return 0
        else
            echo "ERROR Unable to execute ${*} - try ${i}/${retries}. Retrying in ${interval}"
            if [ -n "${output}" ]; then
                echo "ERROR Failure reason: ${output}"
            fi
        fi
        sleep ${interval}
    done
    return 2
}

backup() {
    restic backup --tag "${RESTIC_TAGS}" "${excludes[@]}" "${MC_DIR}"
}

prune() {
    keep_flags=""
    if [ "$KEEP_HOURLY" -gt "0" ]; then
        keep_flags+=( --keep-hourly $KEEP_HOURLY )
    fi

    if [ "$KEEP_DAILY" -gt "0" ]; then
        keep_flags+=( --keep-daily $KEEP_DAILY )
    fi

    if [ "$KEEP_WEEKLY" -gt "0" ]; then
        keep_flags+=( --keep-weekly $KEEP_WEEKLY )
    fi

    if [ "$KEEP_MONTHLY" -gt "0" ]; then
        keep_flags+=( --keep-monthly $KEEP_MONTHLY )
    fi

    if [ "$KEEP_YEARLY" -gt "0" ]; then
        keep_flags+=( --keep-yearly $KEEP_YEARLY )
    fi

    restic forget --tag "$RESTIC_TAGS" ${keep_flags} --prune
}

readarray -td, excludes_patterns < <(printf '%s' "${EXCLUDES}")

excludes=()
for pattern in "${excludes_patterns[@]}"; do
    excludes+=(--exclude "${pattern}")
done

if retry 5 10s rcon-cli save-off; then
    # ensure saving is on
    trap 'retry 5 5s rcon-cli save-on' EXIT

    retry 5 10s rcon-cli save-all
    retry 5 10s sync

    backup

    retry 20 10s rcon-cli save-on

    trap EXIT
else
    echo "ERROR Unable to turn saving off. Is the server running?"
    exit 1
fi

prune

