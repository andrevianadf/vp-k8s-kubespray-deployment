#!/bin/bash

cd 

sudo apt -y update

sudo apt install python3-pip git sshpass python3-venv -y

python3 -m venv venv

source venv/bin/activate

echo 'source venv/bin/activate' >> ~/.bashrc

git clone https://github.com/kubernetes-incubator/kubespray.git

cd kubespray

git checkout v2.27.0

pip3 install -r requirements.txt

pip3 install --upgrade kubernetes

pip3 install --upgrade 'grafana-import[builder]'

PUB_IP=`curl ifconfig.me`

cp -rfp inventory/sample inventory/mycluster

cat <<EOF >> inventory/mycluster/group_vars/k8s_cluster/k8s-net-calico.yml
calico_node_memory_limit: 2048M
calico_node_cpu_limit: 500m
calico_node_memory_requests: 64M
calico_node_cpu_requests: 30m
calico_felix_prometheusmetricsenabled: true
EOF

sed -i 's/# containerd_snapshotter: "native"/containerd_snapshotter: "overlayfs"/' inventory/mycluster/group_vars/all/containerd.yml

sed -i 's/enable_nodelocaldns: true/enable_nodelocaldns: false/' inventory/mycluster/group_vars/k8s_cluster/k8s-cluster.yml


cat <<EOF >> inventory/mycluster/group_vars/k8s_cluster/k8s-cluster.yml
supplementary_addresses_in_ssl_keys: [ mycluster.voltagepark.com, 147.185.41.82, 147.185.41.82 ]

tls_cipher_suites:
  - TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256
  - TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384
  - TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256
  - TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384
  - TLS_ECDHE_ECDSA_WITH_CHACHA20_POLY1305_SHA256
  - TLS_ECDHE_RSA_WITH_CHACHA20_POLY1305_SHA256

EOF


cat <<EOF > inventory/mycluster/inventory.ini
[kube_control_plane]
g209 ansible_host=10.15.26.9 etcd_member_name=g209
g210 ansible_host=10.15.26.17 etcd_member_name=g210

[etcd:children]
kube_control_plane

[kube_node]
g209 ansible_host=
g210 ansible_host=10.15.26.17


EOF

echo
echo
echo
echo
echo 'activate the environment with the command: source ~/venv/bin/activate'
echo
echo 'go to Kubesprady directory: cd ~/kubespray'
echo
echo 'Edit the Inventory file as your needs. You should add hostnames and IPs from control-planes and workers'
echo 'after that'
echo 
echo 
echo '# Check if ansible is working:'
echo 'ansible -i inventory/mycluster/inventory.ini all -m shell -a "uptime"'
echo
echo '## Disable cloud-init update etc hosts'
echo ansible --become -i inventory/mycluster/inventory.ini all -m shell -a "sed -i '/update_etc_hosts/d' /etc/cloud/cloud.cfg"
echo
echo 'Deploy Kubernetes with running the cluster playbook'
echo 'ansible-playbook --become -i inventory/mycluster/inventory.ini cluster.yml'
