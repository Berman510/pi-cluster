#!/bin/zsh
set -x
HOSTS_FILE="hosts.yml"
SSH_DIR="${HOME}/.ssh/"
SSH_KEY="id_rsa_pi_cluster"
STORAGE_DEV="sda1"

declare -A CONTROL_PLANE
declare -A WORKER_NODES
declare -A STORAGE_NODE
declare -A CLUSTER_MEMBERS
declare -g CLUSTER_MODE
declare -g CLUSTER_SSH_USER
declare -g CLUSTER_SSH_PASSWD
declare -g CONTROL_PLANE_PREFIX
declare -g NODES_PREFIX
declare -g CLUSTER_SSH_PASSWD
declare -g SSH_DIR
declare -g SSH_KEY
declare -g CLUSTER_SSH_USER

usage() {
    echo "Usage: $(basename $0) [-s|-m] -cp <CONTROL_PLANE_PREFIX> -u <CLUSTER_SSH_USER> [-np <NODES_PREFIX>] [-p <STORAGE_DEV>]" >&2
    exit 1
}

#while [[ $# -eq 0 ]]; do
#    usage
#done

while [[ $# -gt 0 ]]; do
    case "$1" in
        -s|--single)
            CLUSTER_MODE=single
            shift
            ;;
        -m|--multi)
            CLUSTER_MODE=multi
            shift
            ;;
        -cp)
            CONTROL_PLANE_PREFIX=$2
            shift 2
            ;;
        -np)
            NODES_PREFIX=$2
            shift 2
            ;;
        -u)
            CLUSTER_SSH_USER=$2
            shift 2
            ;;
        -nfs)
            STORAGE_NODE=$2
            shift 2
            ;;
        *)
            usage
            ;;
    esac
done

if [[ -z $CLUSTER_MODE ]]; then
    usage
elif [[ $CLUSTER_MODE == "multi" ]]; then
    if [[ -z "$CONTROL_PLANE_PREFIX" || -z "$NODES_PREFIX" || -z "$CLUSTER_SSH_USER" ]]; then
    usage
    else
        printf "\t\tCluster mode set to %s\n" "$CLUSTER_MODE"
    fi
elif [[ $CLUSTER_MODE == "single" ]]; then
    if [[ -z "$CONTROL_PLANE_PREFIX" || -z "$CLUSTER_SSH_USER" ]]; then
    usage
    else
        printf "\t\tCluster mode set to %s\n" "$CLUSTER_MODE"
    fi
fi


ARP_OUTPUT=$(arp -a)
printf "%s" "$ARP_OUTPUT"

## Gather user and password
function inventory_init() {
    printf "\t\t  Welcome to Pi Cluster\nEnter the SSH password for user %s: " "$CLUSTER_SSH_USER"
    read -s CLUSTER_SSH_PASSWD
    if ! which sshpass > /dev/null; then
      yes | brew install hudochenkov/sshpass/sshpass
    fi
    if ! which yq > /dev/null; then
        yes | brew install yq
    fi
    if [[ ! -f "${SSH_DIR}${SSH_KEY}" ]]; then
        ssh-keygen -t rsa -b 4096 -C "${SSH_KEY}" -f "${SSH_DIR}${SSH_KEY}" -P ""
        touch $SSH_DIR/config
        printf "Match Host %s*\n\tUser %s\n\tIdentityFile %s%s\n" "$CONTROL_PLANE_PREFIX" "$CLUSTER_SSH_USER" "$SSH_DIR" "$SSH_KEY" | tee -a $SSH_DIR/config
        printf "Match Host %s*\n\tUser %s\n\tIdentityFile %s%s\n" "$NODES_PREFIX" "$CLUSTER_SSH_USER" "$SSH_DIR" "$SSH_KEY" | tee -a $SSH_DIR/config
    fi
}

## Discover hosts with arp and known host prefixes
function host_discovery() {
    printf "\nDiscovering cluster members...\n"
    while read -r line; do
        HOSTNAME=$(echo $line | awk '{print $1}' | tr -d '()')
        if [[ $HOSTNAME == "?" ]]; then
            continue
        elif [[ $HOSTNAME == $CONTROL_PLANE_PREFIX ]]; then
            IP=$(echo $line | awk '{print $2}' | tr -d '()')
            CONTROL_PLANE[$HOSTNAME]=$IP
            CLUSTER_MEMBERS[$HOSTNAME]=$IP
            continue
        elif [[ CLUSTER_MODE == "multi" ]]; then
            if [[ $HOSTNAME =~ $NODES_PREFIX* ]]; then
                IP=$(echo $line | awk '{print $2}' | tr -d '()')
                WORKER_NODES[$HOSTNAME]=$IP
                CLUSTER_MEMBERS[$HOSTNAME]=$IP
                continue
            fi
        fi
    done <<< "$ARP_OUTPUT"
}

## Add hosts to inventory maps
function host_inventory() {
    printf "---\ncontrol_plane:\n  hosts:\n"
    for i in "${(@k)CONTROL_PLANE}"; do
        printf "    %s:\n      ansible_host: %s\n      ansible_ssh_private_key_file: %s%s\n" "$i" "${CONTROL_PLANE[$i]}" "$SSH_DIR" "$SSH_KEY"
    done
    if [[ $CLUSTER_MODE == "multi" ]]; then
        printf "\nnodes:\n  hosts:\n"
        for i in "${(@k)WORKER_NODES}"; do
            printf "    %s:\n      ansible_host: %s\n      ansible_ssh_private_key_file: %s%s\n" "$i" "${WORKER_NODES[$i]}" "$SSH_DIR" "$SSH_KEY"
        done
    fi
}

## Discover node with attached storage for nfs-server
#  If no STORAGE_NODE set, checks for WORKER_NODES member with /dev/$STORAGE_DEV
function storage_discovery() {
    if [[ $CLUSTER_MODE == "multi" ]]; then
        if [[ -z $STORAGE_NODE ]]; then
            for i in "${(@k)WORKER_NODES}"; do
                IP="${WORKER_NODES[$i]}"
                # Connect to host via SSH and check for $STORAGE_DEV device, otherwise assume sda1
                sshpass -p "$CLUSTER_SSH_PASSWD" ssh -o "StrictHostKeyChecking no" \
                        "$CLUSTER_SSH_USER@$IP" "lsblk | grep sda1" > /dev/null 2>&1
                if [ $? -eq 0 ]; then
                    # If /dev/sda is found, set the storage node variable and break the loop
                    STORAGE_NODE[$i]=$IP
                    break
                fi
            done
        elif [[ $STORAGE_NODE ]]; then
            printf "%s" "$STORAGE_NODE"
            break
            HOSTNAME=$STORAGE_NODE
            IP=$(host $STORAGE_NODE | awk '{print $4}')
            unset STORAGE_NODE
            declare -A STORAGE_NODE
            STORAGE_NODE[$HOSTNAME]=$IP
        fi
    fi
}

## Add storage node to storage inventory
function storage_inventory() {
    if [[ $CLUSTER_MODE == "multi" ]]; then
        # If a storage node was found, add it to the inventory file
        if [ ${#STORAGE_NODE[@]} -ne 0 ]; then
            printf "\nstorage:\n  hosts:\n"
            for i in "${(@k)STORAGE_NODE}"; do
                printf "    %s:\n      ansible_host: %s\n" "$i" "${STORAGE_NODE[$i]}"
            done
        fi
    fi
}

## Finalize the inventory file
function finalize_inventory() {
    printf "\ncluster:\n  children:\n    control_plane:\n    nodes:\n"
}

## Copy SSH key to cluster members
function ssh_copy_id() {
    for i in "${(@k)CLUSTER_MEMBERS}"; do
        sshpass -p "$CLUSTER_SSH_PASSWD" ssh-copy-id -i "${SSH_DIR}${SSH_KEY}" $CLUSTER_SSH_USER@$i 
    done
}

inventory_init
host_discovery
storage_discovery
host_inventory | tee $HOSTS_FILE
storage_inventory | tee -a $HOSTS_FILE
finalize_inventory | tee -a $HOSTS_FILE
ssh_copy_id
