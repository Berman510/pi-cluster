#!/bin/zsh
hosts_file="hosts.yml"
ssh_dir="${HOME}/.ssh/"
ssh_key="id_rsa_pi_cluster"
ssh_key_path=${ssh_dir}${ssh_key}

declare -A arp_list
declare -A control_plane
declare -A storage_node
declare -A cluster_members
declare -g cluster_mode
declare -g control_plane_prefix
declare -g nodes_prefix
declare -g ssh_passwd
declare -g ssh_user

usage() {
    echo "Usage: $(basename $0) [-s|-m] -cp <control_plane_prefix> -u <ssh_user> \
        [-np <nodes_prefix>] [-nfs <storage_host>]" >&2
    exit 1
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -s|--single)
            cluster_mode=single
            shift
            ;;
        -m|--multi)
            cluster_mode=multi
            shift
            ;;
        -cp)
            control_plane_prefix=$2
            shift 2
            ;;
        -np)
            nodes_prefix=$2
            shift 2
            ;;
        -u)
            ssh_user=$2
            shift 2
            ;;
        -nfs)
            storage_node=$2
            shift 2
            ;;
        *)
            usage
            ;;
    esac
done

if [[ -z $cluster_mode ]]; then
    usage
elif [[ $cluster_mode == "multi" ]]; then
    if [[ -z "$control_plane_prefix" || -z "$nodes_prefix" || -z "$ssh_user" ]]; then
    usage
    else
        printf "\t\tCluster mode set to %s\n" "$cluster_mode"
    fi
elif [[ $cluster_mode == "single" ]]; then
    if [[ -z "$control_plane_prefix" || -z "$ssh_user" ]]; then
    usage
    else
        printf "\t\tCluster mode set to %s\n" "$cluster_mode"
    fi
fi

## Gather user and password
function inventory_init() {
    printf "\t\t  Welcome to Pi Cluster\nEnter the SSH password for user %s: " "$ssh_user"
    read -s ssh_passwd
    # Check for sshpass
    if ! which sshpass > /dev/null; then
      yes | brew install hudochenkov/sshpass/sshpass
    fi
    # Check for yq
    if ! which yq > /dev/null; then
        yes | brew install yq
    fi
    # Check for existing cluster ssh key
    if [[ ! -f "${ssh_key_path}" ]]; then
        ssh-keygen -t rsa -b 4096 -C "${ssh_key}" -f "${ssh_key_path}" -P ""
        touch $ssh_dir/config
        printf "Match Host %s*\n\tUser %s\n\tIdentityFile %s%s\n" "$control_plane_prefix" \
            "$ssh_user" "$ssh_dir" "$ssh_key" >> $ssh_dir/config
        if [[ $cluster_mode == "multi" ]]; then
            printf "Match Host %s*\n\tUser %s\n\tIdentityFile %s%s\n" "$nodes_prefix" \
                "$ssh_user" "$ssh_dir" "$ssh_key" >> $ssh_dir/config
        fi
    fi
}

## Discover hosts with arp and known host prefixes
function host_discovery() {
    printf "\nDiscovering cluster members...\n"
    arp_output=$(arp -a)
    while read -r line; do
        host=$(echo "${line}" | awk '{print $1}')
        ip=$(echo "${line}" | awk '{print $2}')
        arp_list[$host]="$ip"
    done <<< $arp_output
}

## Add hosts to inventory maps
function host_inventory() {
    # Discover Control Plane Node
    printf "---\ncontrol_plane:\n  hosts:\n"
    for host in ${(@k)arp_list}; do
        if [[ "$host" == "$control_plane_prefix"* ]]; then
            ip=${arp_list[$host]//[()]/}
            printf "    %s:\n      ansible_host: %s\n      ansible_ssh_private_key_file: %s%s\n\n" "$host" "$ip" "$ssh_dir" "$ssh_key"
            cluster_members[$host]="$ip"
            break
        fi
    done

    if [[ $cluster_mode == "multi" ]]; then
        # Discover Worker Nodes
        printf "nodes:\n  hosts:\n"
        for host in ${(@k)arp_list}; do
            if [[ "$host" == "$nodes_prefix"* ]]; then
                ip=${arp_list[$host]//[()]/}
                printf "    %s:\n      ansible_host: %s\n      ansible_ssh_private_key_file: %s%s\n" "$host" "$ip" "$ssh_dir" "$ssh_key"
                cluster_members[$host]="$ip"
            fi
        done

        # Discover Storage Node
        if [[ -z $storage_node ]]; then
            for host in ${(@k)cluster_members}; do
                ip=${cluster_members[$host]//[()]/}
                sshpass -p "$ssh_passwd" ssh -o "StrictHostKeyChecking no" \
                        "$ssh_user@$ip" "lsblk | grep sda1" > /dev/null 2>&1
                if [ $? -eq 0 ]; then
                    printf "\nstorage:\n  hosts:\n    %s:\n      ansible_host: %s\n      ansible_ssh_private_key_file: %s%s\n" \
                        "$host" "$ip" "$ssh_dir" "$ssh_key"
                fi
            done

        elif [[ $storage_node ]]; then
            host=$storage_node
            ip=$(host $storage_node | awk '{print $4}')
            printf "\nstorage:\n  hosts:\n    %s:\n      ansible_host: %s\n      ansible_ssh_private_key_file: %s%s\n" \
                "$host" "$ip" "$ssh_dir" "$ssh_key"
        fi
        printf "\ncluster:\n  children:\n    control_plane:\n    nodes:\n"
    elif [[ $cluster_mode == "single" ]]; then
        for host in ${(@k)cluster_members}; do
            ip=${cluster_members[$host]//[()]/}
            printf "\nstorage:\n  hosts:\n    %s:\n      ansible_host: %s\n      ansible_ssh_private_key_file: %s%s\n" \
                "$host" "$ip" "$ssh_dir" "$ssh_key"
        done
    fi
}

ssh_copy_id() {
    for host in "${(@k)cluster_members}"; do
        sshpass -p "$ssh_passwd" ssh-copy-id -f -i "${ssh_key_path}" $ssh_user@$host
    done
}

inventory_init
host_discovery
host_inventory | tee $hosts_file
ssh_copy_id
