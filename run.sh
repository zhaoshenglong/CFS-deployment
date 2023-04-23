#!/usr/bin/env bash


set -e

CURDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

function ipfs_init() {
    IPFS=$(which ipfs)
    if [ ! -d $HOME/.ipfs ]; then
        ${IPFS} init
    fi

    ${IPFS} bootstrap rm --all
    ${IPFS} bootstrap add "$(cat ${CURDIR}/bootstrap.txt)"
    cp ${CURDIR}/swarm.key ${HOME}/.ipfs
    sed -i s/127.0.0.1/0.0.0.0/ ${CURDIR}/.ipfs/config
    ./ipfs config Routing.Type dht
}

function ipfs_update_bootstrap() {
    IPFS=$(which ipfs)
    ${IPFS} bootstrap rm --all
    ${IPFS} bootstrap add "$(cat ${CURDIR}/bootstrap.txt)"
}

function ipfs_run() {
    IPFS=$(which ipfs)
    IPFS_LOGGING=info ./ipfs daemon >ipfs.log  2>&1 &
}

function ipfs_stop() {
    IPFS=$(which ipfs)
    { pgrep ipfs | xargs kill -9; } >/dev/null 2>&1;
}

function set_latency() {
    local nic=$(ifconfig | grep -B1 '172' | grep -v inet | awk '{print $1}' | cut -d ':' -f1)
    local latency=$1
    sudo tc qdisc add dev ${nic} root netem delay ${latency}ms
}

function unset_latency() {
    local nic=$(ifconfig | grep -B1 '172' | grep -v inet | awk '{print $1}' | cut -d ':' -f1)
    sudo tc qdisc del dev ${nic} root netem
}

# Execute actions defined in actions.txt
# NOTE: ORDER MATTERS
while read line; do
    IFS=' ' read -ra input <<< "$line"
    if [ -z "$input" ]; then
        continue
    fi
    action=${input[0]}
    echo "$action"
    echo "${input[@]}"
    case $action in
        ipfs_init)
            ipfs_init "${input[@]}"
            ;;
        ipfs_update_bootstrap)
            ipfs_update_bootstrap "${input[@]}"
            ;;
        ipfs_run)
            ipfs_run "${input[@]}"
            ;;
        ipfs_stop)
            ipfs_stop "${input[@]}"
            ;;
        set_latency)
            set_latency "${input[@]}"
            ;;
        unset_latency)
            unset_latency "${input[@]}"
            ;;
        mucc_run)
            mucc_run "${input[@]}"
            ;;
        mucc_stop)
            mucc_stop "${input[@]}"
            ;;
        *)
            echo "Unexpected action: $action"
            exit 1
            ;;
    esac
done < actions.txt

