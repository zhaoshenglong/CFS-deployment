#!/usr/bin/env bash

CURDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IPFS=${HOME}/ipfs
MUCC=${HOME}/mucc


function ipfs_download() {
    rm ${HOME}/ipfs
    wget -O ${HOME}/ipfs https://github.com/zhaoshenglong/CFS-deployment/releases/download/ipfs_v0.1/ipfs
    chmod +x ${HOME}/ipfs
}

function ipfs_init() {
    if [ ! -d ${HOME}/.ipfs ]; then
        ${IPFS} init
    fi

    ${IPFS} bootstrap rm --all
    cp ${HOME}/multichord/bin/ipfs/swarm.key ${HOME}/.ipfs
    sed -i s/127.0.0.1/0.0.0.0/ ${HOME}/.ipfs/config
    ${IPFS} config Routing.Type dht

    while read -r line; do
        if [ -z "$line" ]; then
            continue
        fi
        ${IPFS} bootstrap add "$line"
    done < ipfs_bootstrap.txt
}

function ipfs_update_bootstrap() {
    ${IPFS} bootstrap rm --all
    while read -r line; do
        if [ -z "$line" ]; then
            continue
        fi
        ${IPFS} bootstrap add "$line"
    done < ipfs_bootstrap.txt
}

function ipfs_run() {
    pushd ${HOME}
    if ! pgrep ipfs; then
        IPFS_LOGGING=info ${IPFS} daemon >ipfs.log  2>&1 &
    fi
    popd
}

function ipfs_stop() {
    { pgrep ipfs | xargs kill -9; } >/dev/null 2>&1
}

function set_latency() {
    local nic
    local latency
    nic="$(ifconfig | grep -B1 "$(hostname -i)" | grep -v inet | awk '{print $1}' | cut -d ':' -f1)"
    latency=$(cat latency.txt)

    if ! sudo tc qdisc add dev ${nic} root netem delay ${latency}ms; then
        echo "latency has already been set"
        sudo tc qdisc del dev ${nic} root netem
        sudo tc qdisc add dev ${nic} root netem delay ${latency}ms
    fi
}

function unset_latency() {
    local nic
    nic="$(ifconfig | grep -B1 "$(hostname -i)" | grep -v inet | awk '{print $1}' | cut -d ':' -f1)"
    if ! sudo tc qdisc del dev ${nic} root netem; then
        echo "latency has already been unset"
    fi
}


function mucc_build() {
    rm ${HOME}/mucc
    wget -O ${HOME}/mucc https://github.com/zhaoshenglong/CFS-deployment/releases/download/ipfs_v0.1/mucc
    chmod +x ${HOME}/mucc
}

function mucc_run() {
    local bootnode
    local ip
    local mcid
    ip="$(curl -s ifconfig.me)"
    bootnode="$(python3 read_bootnode.py ${ip})"
    mcid="$(python3 read_mcid.py ${ip})"
    pushd ${HOME}
    if ! pgrep mucc; then
        ${MUCC} start --bootnode="${bootnode}:8100" --ip="${ip}" --mcid="${mcid}" --log=3 8100 > mucc.log 2>&1 & 
    fi
    popd
}

function mucc_stop() {
    { pgrep mucc | xargs kill -9; } >/dev/null 2>&1
}

# Update the repositories
git pull


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

