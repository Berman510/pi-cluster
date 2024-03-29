# K3S Pi Cluster

I use this repo to provision and deploy my home k3s cluster. I have 3 NanoPi R6S nodes, one with an attached external hardware RAID storage array. There are configurations to support single or multi-node environments. Tested using Debian Bullseye Core w/ kernel 6.1 arm64. Comments, suggestions and pull-requests highly encouraged! This repository is based on Jeff Geerling's [Pi-Cluster](https://github.com/geerlingguy/pi-cluster) repository and has been configured for my specific home setup. Note: I've added services like external-dns and cert-manager that require pre-provisioning secrets. My `kube-prometheus-stack` configuration is also expecting a secret for the bearer token to attach to my separate HomeAssistant deployment. Be sure to add these secrets to the `secrets` folder. See notes below on how to [Configure Secrets Files](#configure-secrets-files).

### Note:
This repository is not entirely generalized. When customizing for your own environment, be sure to fork this repository and update the templates containing `repoURL` and `targetRevision` entries as well as entries in all the `Values.yaml` files with your desired values.

### TODO

- Update README with steps for auto_inventory.sh usage (also make it work reliably...)
- Expand secrets via external-secrets chart (plus AWS-side setup)
- Generalize entire repo for mass-consumption
- Correct http->https redirect
- Correct traefik default tls
- Integrate crossplane for entire environment bootstrapping from ARP discovery through application deployment
- Migrate homeassistant.bermanoc.net from RPi4b+ HAOS to cluster deployed chart with full supervisor/USB conbee/etc functionality.
- Figure out how to incorporate OverlayFS with k3s server and agent. (OverlayFS allows support for snapshotting of file system, which supports SoC's lacking a proper power switch [loss of power when unplugging won't corrupt filesystem]) - This is a priority.

## Usage

  1. Make sure you have [Ansible](https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html) installed.
  2. Copy the `example.(multi|single).hosts.ini` inventory file to `hosts.ini`. Make sure it has the `control_plane`, `storage`, and `node`s configured correctly (for my examples I named my nodes `nanopi0[1-3]`).
  3. Copy the `example.(multi|single).config.yml` file to `config.yml`, and modify the variables to your liking.

### Cluster Pre-Provisioning

- Set hostnames: `node01` (set to `02` for node 2, `03` for node 3, etc.) (TODO: add tasks to automate this - see `auto_inventory.sh` for framework)
- Modify `/etc/hosts` to include the new hostname in the loopback address on each node. (TODO: add tasks to automate this - see `auto_inventory.sh` for framework)
- Ensure nodes are set to static IP addresses, matching values configured in hosts.yml (TODO: add tasks to automate this - see `auto_inventory.sh` for framework)
- Ensure nodes are set to the correct timezone (e.g. using `timedatectl set-hostname America/Los_Angeles`) (TODO: add tasks to automate this - see `auto_inventory.sh` for framework)
- Enable SSH: Generate id_rsa_pi_cluster ssh keypair, then copy public keys to allowed_hosts on each node (e.g. `for i in {1..3}; do ssh-copy-id -i ~/.ssh/id_rsa_pi_cluster pi@nanopi0$i; done`) (TODO: add tasks to automate this - see `auto_inventory.sh` for framework)
- Reboot all nodes.

# Kubernetes Secrets Management

This Ansible playbook is designed to manage Kubernetes secrets. It processes local secrets files and creates corresponding secrets in a Kubernetes cluster.

## Overview

The playbook consists of two main parts:

1. **Process secrets files and create a list of secrets**: This part runs locally and finds secret files, reads their contents, and prepares a list of secrets to be created in Kubernetes.

2. **Create Kubernetes secrets on the control plane**: This part runs on the Kubernetes control plane. It ensures the necessary namespaces exist, templates the secret definitions, and applies them to the Kubernetes cluster.

## Prerequisites

- Ansible installed on the machine where the playbook will be executed.
- Access to the Kubernetes control plane.
- The secrets files should be located in the `../../secrets` directory.

## Variables

- `../../config.yml`: This file should contain any necessary configurations required by the playbook.
- `K8S_AUTH_KUBECONFIG`: Path to the kubeconfig file. Default is `/etc/rancher/k3s/k3s.yaml`.
- Secrets files should be named in the format `<name>.<namespace>.yml`.

## Steps

1. **Finding Secrets Files**:
   - Locates all `.yml` files in the `../../secrets` directory.
   - The secrets file naming convention is important for the correct processing.

2. **Initialize Secrets List**:
   - Initializes an empty list to store secrets information.

3. **Read Secrets and Prepare List**:
   - Reads each secrets file and appends its content to the `secrets_info` list.
   - The secret name and namespace are derived from the file name.

4. **Ensure Namespace Exists in Kubernetes**:
   - Checks if the specified namespace exists for each secret in Kubernetes.
   - If not, it creates the namespace.

5. **Template Secret Definition**:
   - Uses the `secret_template.j2` Jinja2 template to create secret definitions.
   - Stores the templated definitions in `/tmp`.

6. **Apply Secrets in Kubernetes**:
   - Applies each templated secret definition to the Kubernetes cluster.

## Usage

To execute the playbook, run the following command:

```shell
ansible-playbook tasks/kubernetes/secrets.yaml


### SSH connection test


```
ssh pi@node1
```

```
ansible all -m ping
```

It should respond with a 'SUCCESS' message for each node.

### Storage Configuration

#### Filesystem Storage

If using filesystem (`storage_type: filesystem`), make sure to use the appropriate `storage_nfs_dir` variable in `config.yml`.

### Cluster configuration and K3s installation

Copy the desired playbook for single or multiple nodes (e.g. `cp main_multi.yml main.yml`)

Run the playbook:

```
ansible-playbook main.yml
```

### Upgrading the cluster

Install CRDs:
```
kubectl apply -f https://github.com/rancher/system-upgrade-controller/releases/download/v0.7.5/system-upgrade-controller.yaml
```

Run the upgrade playbook:

```
ansible-playbook upgrade.ymal
```

### Monitoring the cluster

To access ArgoCD/Grafana/etc:

  1. `external-dns` (if configured) should create a DNS entry for each Ingress it finds. `cert-manager` (if configured) will create LetsEncrypt signed certs. Once DNS propagates and certificates are valid, ingresses are reachable at https://\<ingress\>.\<domian\> - e.g. `https://argocd.bermanoc.net`, `https://grafana.bermanoc.net`, etc.

The default login is `admin` / `prom-operator`, but you can also get the secret with `kubectl get secret cluster-monitoring-grafana -o jsonpath="{.data.admin-password}" | base64 -D`.

You can then browse to all the Kubernetes and Pi-related dashboards by browsing the Dashboards in the 'General' folder.

### Benchmarking the cluster

See the README file within the `benchmarks` folder.

### Shutting down the cluster

The safest way to shut down the cluster is to run the following command:

```
ansible all -m community.general.shutdown -b
```
