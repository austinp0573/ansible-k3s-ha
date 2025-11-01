# quick start - k3s ha cluster

## before starting

Make sure:

- [ ] 5 VMs are running
- [ ] You can SSH to all nodes as `<whatever_user_has_sudo_on_your_nodes>`
- [ ] Ansible is installed
- [ ] SSH key is loaded (if using passphrase)

## deployment steps

### 1. install dependencies

```bash
cd ./ansible-k3s-ha
ansible-galaxy collection install community.general ansible.posix
```

### 2. test connectivity

```bash
ansible all -m ping
```

Should see:
```
k3s-cp-1 | SUCCESS => { ... "ping": "pong" ... }
k3s-cp-2 | SUCCESS => { ... "ping": "pong" ... }
k3s-cp-3 | SUCCESS => { ... "ping": "pong" ... }
k3s-wk-1 | SUCCESS => { ... "ping": "pong" ... }
k3s-wk-2 | SUCCESS => { ... "ping": "pong" ... }
```

### 3. deploy

```bash
./deploy.sh
# or just run the playbook directly:
# ansible-playbook site.yml
```

## what happens

- pre-flight checks
- System config
- Download k3s
- Setup control plane
- Join workers
- Setup networking
- Verify everything

## verification

after it finishes:

```bash
export KUBECONFIG=/home/austin/code/iac/proxmox/ansible-k3s-ha/kubeconfig

kubectl get nodes

# You should see:
# NAME       STATUS   ROLES                       AGE   VERSION
# k3s-cp-1   Ready    control-plane,etcd,master   5m    v1.31.2+k3s1
# k3s-cp-2   Ready    control-plane,etcd,master   4m    v1.31.2+k3s1
# k3s-cp-3   Ready    control-plane,etcd,master   4m    v1.31.2+k3s1
# k3s-wk-1   Ready    <none>                      3m    v1.31.2+k3s1
# k3s-wk-2   Ready    <none>                      3m    v1.31.2+k3s1

kubectl get pods -A

# test vip
curl -k https://192.168.1.<kube_vip_ip>:6443
# "Unauthorized" is good - means the API is up
```

## test loadBalancer

```bash
kubectl create deployment nginx --image=nginx
kubectl expose deployment nginx --port=80 --type=LoadBalancer

kubectl get svc nginx
# Should get an EXTERNAL-IP like 192.168.1.30

curl http://192.168.1.30  # nginx welcome page

# cleanup
kubectl delete deployment nginx
kubectl delete service nginx
```

## Troubleshooting

### SSH Issues

if there are host key errors:
```bash
ssh-keygen -R 192.168.1.<All node IPs>
ssh-keygen -R 192.168.1.<All node IPs>
ssh-keygen -R 192.168.1.<All node IPs>
ssh-keygen -R 192.168.1.<All node IPs>
ssh-keygen -R 192.168.1.<All node IPs>
```

### ssh key has passphrase

```bash
eval $(ssh-agent)
ssh-add ~/.ssh/your_key
```

### deploy failed partway through

just run it again (it's idempotent):
```bash
ansible-playbook site.yml
```

or wipe and restart:
```bash
./reset.sh
./deploy.sh
```

### checking logs

```bash
# control plane
ansible k3s-cp-1 -m shell -a "journalctl -u k3s -n 50 --no-pager"

# worker
ansible k3s-wk-1 -m shell -a "systemctl status k3s-agent"
```

## resetting everything

to wipe k3s and start over:

```bash
./reset.sh
# or: ansible-playbook reset.yml
```

then deploy fresh

## important stuff

1. change the token in `group_vars/all.yml` (`k3s_token`) to something secure
2. make sure 192.168.1.<kube_vip_ip> isn't being used by anything else (vip)
3. make sure 192.168.1.<assigned_metallb_pool> isn't in your DHCP range (metalLB pool)
4. if your VMs use `ens18` instead of `eth0`, update `flannel_iface` in `group_vars/all.yml`

## what i'll do next

once it's running I'll try:

1. deploying some apps
2. adding longhorn for persistent storage
3. setup prometheus/grafana for monitoring
4. install nginx ingress
5. try argoCD for gitops