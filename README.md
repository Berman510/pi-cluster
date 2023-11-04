# Raspberry Pi Cluster

### TODO:
Update README with steps for auto_inventory.sh usage! Below steps are remnants of geerlingguy's pi-cluster repo and still mostly apply.

## Usage

  1. Make sure you have [Ansible](https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html) installed.
  2. Copy the `example.hosts.ini` inventory file to `hosts.ini`. Make sure it has the `control_plane` and `node`s configured correctly (for my examples I named my nodes `node[1-4].local`).
  3. Copy the `example.config.yml` file to `config.yml`, and modify the variables to your liking.

### Raspberry Pi Setup

  - Set hostname: `node1.local` (set to `2` for node 2, `3` for node 3, etc.)
  - Enable SSH: 'Allow public-key', and paste in my public SSH key(s)

### SSH connection test


```
ssh pi@node1.local
```

```
ansible all -m ping
```

It should respond with a 'SUCCESS' message for each node.

### Storage Configuration

#### Filesystem Storage

If using filesystem (`storage_type: filesystem`), make sure to use the appropriate `storage_nfs_dir` variable in `config.yml`.

### Cluster configuration and K3s installation

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
