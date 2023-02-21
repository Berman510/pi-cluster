#!/bin/zsh
arp_output=$(arp -a)
hosts_file="hosts.yml"
storage_dev="sda1" # Define attached storage device for storage node
control_plane_prefix="rpi" # Define control plane hostname prefix
nodes_prefix="nanopi" # Define cluster nodes hostname prefix

declare -A control_plane
declare -A worker_nodes
declare -A storage_node
declare -A cluster_members
declare -g cluster_ssh_user
declare -g cluster_ssh_passwd

## Reconcile pre-requisites and cluster sshkey
function prereqs() {
    if ! which sshpass > /dev/null; then
      yes | brew install hudochenkov/sshpass/sshpass
    fi
    if ! which yq > /dev/null; then
        yes | brew install yq
    fi
    if [[ ! -f ~/.ssh/id_rsa_pi_cluster ]]; then
        ssh-keygen -t rsa -b 4096 -C "id_rsa_pi_cluster" -f ~/.ssh/id_rsa_pi_cluster -P ""
    fi
}

## Gather user and password
function inventory_init() {
    printf "\t\tWelcome to Pi Cluster\nEnter the cluster SSH username: "
    read cluster_ssh_user
    printf "Enter password for user '%s': " "$cluster_ssh_user"
    read -s cluster_ssh_passwd
    printf "\nDiscovering cluster members...\n"
}

## Discover hosts with arp and known host prefixes
function host_discovery() {
    while read -r line; do
        hostname=$(echo $line | awk '{print $1}' | tr -d '()')
        if [[ $hostname == "?" ]]; then
            continue
        elif [[ $hostname == $control_plane_prefix ]]; then
            ip=$(echo $line | awk '{print $2}' | tr -d '()')
            control_plane[$hostname]=$ip
            cluster_members[$hostname]=$ip
            continue
        elif [[ $hostname =~ $nodes_prefix* ]]; then
            ip=$(echo $line | awk '{print $2}' | tr -d '()')
            worker_nodes[$hostname]=$ip
            cluster_members[$hostname]=$ip
        fi
    done <<< "$arp_output"
}

## Add hosts to inventory maps
function host_inventory() {
    printf "---\ncontrol_plane:\n  hosts:\n"
    for i in "${(@k)control_plane}"; do
        printf "    %s:\n      ansible_host: %s\n" "$i" "${control_plane[$i]}"
    done
    printf "\nnodes:\n  hosts:\n"
    for i in "${(@k)worker_nodes}"; do
        printf "    %s:\n      ansible_host: %s\n" "$i" "${worker_nodes[$i]}"
    done
}

## Discover node with attached storage for nfs-server
function storage_discovery() {
    for i in "${(@k)worker_nodes}"; do
        ip="${worker_nodes[$i]}"
        # Connect to host via SSH and check for $storage_dev device
        sshpass -p "$cluster_ssh_passwd" ssh -o "StrictHostKeyChecking no" \
                "$cluster_ssh_user@$ip" "lsblk | grep $storage_dev" > /dev/null 2>&1
        if [ $? -eq 0 ]; then
            # If /dev/sda is found, set the storage node variable and break the loop
            storage_node[$i]=$ip
            break
        fi
    done
}

## Add storage node to storage inventory
function storage_inventory() {
    # If a storage node was found, add it to the inventory file
    if [ ${#storage_node[@]} -ne 0 ]; then
        printf "\nstorage:\n  hosts:\n"
        for i in "${(@k)storage_node}"; do
            printf "    %s:\n      ansible_host: %s\n" "$i" "${storage_node[$i]}"
        done
    fi
}

## Finalize the inventory file
function finalize_inventory() {
    printf "\ncluster:\n  children:\n    control_plane:\n    nodes:\n"
}

## Copy SSH key to cluster members
function ssh_copy_id() {
    for i in "${(@k)cluster_members}"; do
        sshpass -p "$cluster_ssh_passwd" ssh-copy-id $cluster_ssh_user@$i
    done
}

prereqs
inventory_init
host_discovery
storage_discovery
host_inventory | tee $hosts_file
storage_inventory | tee -a $hosts_file
finalize_inventory | tee -a $hosts_file
ssh_copy_id
