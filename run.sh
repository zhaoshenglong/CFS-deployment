#!/usr/bin/env bash


set -e

CURDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MUCC_DIR="${HOME}/multichord/"


function ipfs_download() {
    wget -O ${HOME}/ipfs https://github.com/zhaoshenglong/CFS-deployment/releases/download/ipfs_v0.1/ipfs
}

function ipfs_init() {
    IPFS=$(which ipfs)
    if [ ! -d $HOME/.ipfs ]; then
        ${IPFS} init
    fi

    ${IPFS} bootstrap rm --all
    cp ${CURDIR}/swarm.key ${HOME}/.ipfs
    sed -i s/127.0.0.1/0.0.0.0/ ${CURDIR}/.ipfs/config
    ipfs config Routing.Type dht

    while read -r line; do
        if [ -z "$line" ]; then
            continue
        fi
        ${IPFS} bootstrap add "$line"
    done < ipfs_bootstrap.txt
}

function ipfs_update_bootstrap() {
    ipfs bootstrap rm --all
    while read -r line; do
        if [ -z "$line" ]; then
            continue
        fi
        ${IPFS} bootstrap add "$line"
    done < ipfs_bootstrap.txt
}

function ipfs_run() {
    IPFS_LOGGING=info ipfs daemon >ipfs.log  2>&1 &
}

function ipfs_stop() {
    { pgrep ipfs | xargs kill -9; } >/dev/null 2>&1
}

function set_latency() {
    local nic
    local latency
    nic="$(ifconfig | grep -B1 '172' | grep -v inet | awk '{print $1}' | cut -d ':' -f1)"
    latency=$(cat latency.txt)
    sudo tc qdisc add dev ${nic} root netem delay ${latency}ms
}

function unset_latency() {
    local nic
    nic="$(ifconfig | grep -B1 '172' | grep -v inet | awk '{print $1}' | cut -d ':' -f1)"
    sudo tc qdisc del dev ${nic} root netem
}


function mucc_build() {
    pushd "${HOME}/multichord"
    make
    popd
    cp ${HOME}/multichord/bin/mucc/mucc ${HOME}/mucc
}

function mucc_run() {
    local bootnode="$(cat ${CURDIR}/mucc_bootstrap.txt)"
    local ip="$(curl -s ifconfig.me)"
    local mcid=$(python3 read_mcid.py ${ip})
    mucc start --bootnode="${bootnode}" --ip="${ip}" --mcid="${mcid}" --log=3 8100 > mucc.log 2>&1 & 
}

function mucc_stop() {
    { pgrep ipfs | xargs kill -9; } >/dev/null 2>&1
}

# Update the repositories
git pull
pushd ${MUCC_DIR}
git pull
popd


# Execute actions defined in actions.txt
# NOTE: ORDER MATTERS
while read -r line; do
    action=$(echo "$line" | tr -d '\n')
    if [ -z "$action" ]; then
        continue
    fi
    case $action in
        ipfs_download)
            ipfs_download
            ;;
        ipfs_init)
            ipfs_init
            ;;
        ipfs_update_bootstrap)
            ipfs_update_bootstrap
            ;;
        ipfs_run)
            ipfs_run
            ;;
        ipfs_stop)
            ipfs_stop
            ;;
        set_latency)
            set_latency
            ;;
        unset_latency)
            unset_latency
            ;;
        mucc_build)
            mucc_build
            ;;
        mucc_run)
            mucc_run
            ;;
        mucc_stop)
            mucc_stop
            ;;
        *)
            echo "Unexpected action: $action"
            exit 1
            ;;
    esac
done < actions.txt

