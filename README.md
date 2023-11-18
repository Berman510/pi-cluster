# K3S Pi Cluster

### TODO:
Update README with steps for auto_inventory.sh usage! Below steps are remnants of geerlingguy's pi-cluster repo and still mostly apply.

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

### Configure Secrets Files

- Update `secrets` folder with desired secrets - this will also create the target namespaces for the secrets. Secret file format is `secrets/<secret-name>.<target-namespace>.yml`, with key/value pairs in yaml format of `<key-name>: "<secret>"`.

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

To access Grafana:

  1. Make sure you set up a valid `~/.kube/config` file (see 'K3s installation' above).
  1. Run `kubectl port-forward service/cluster-monitoring-grafana :80`
  1. Grab the port that's output, and browse to `localhost:[port]`, and bingo! Grafana.

The default login is `admin` / `prom-operator`, but you can also get the secret with `kubectl get secret cluster-monitoring-grafana -o jsonpath="{.data.admin-password}" | base64 -D`.

You can then browse to all the Kubernetes and Pi-related dashboards by browsing the Dashboards in the 'General' folder.

### Benchmarking the cluster

See the README file within the `benchmarks` folder.

### Shutting down the cluster

The safest way to shut down the cluster is to run the following command:

```
ansible all -m community.general.shutdown -b
```
