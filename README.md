# vp-k8s-deployment

Procedure to deploy K8S using Kubespray it's meant to run at the first node of the cluster.
It may need changes to run it from a bastion host.

// First you need to create a SSH Key and copy the pub key to all nodes.

ssh-keygen -t ed25519

// Now run the following commands with regular user to clone the Kubespray repository and prepare it for deployment:

// Note: change the supplementary_addresses_in_ssl_keys as your needs, that is just a example.

// Also the inventory.init is a example for a cluster with 4 nodes.


sudo apt update

sudo apt install python3-pip git sshpass python3-venv -y

python3 -m venv venv

source venv/bin/activate

git clone https://github.com/kubernetes-incubator/kubespray.git

cd kubespray

git checkout v2.27.0

pip3 install -r requirements.txt

pip3 install kubernetes

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

supplementary_addresses_in_ssl_keys: [ mycluster.voltagepark.com, 45.164.216.218 ]

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
k8s-test01 ansible_host=192.168.0.250 etcd_member_name=k8s-test01
k8s-test02 ansible_host=192.168.0.251 etcd_member_name=k8s-test02
k8s-test03 ansible_host=192.168.0.252 etcd_member_name=k8s-test03

[etcd:children]
kube_control_plane

[kube_node]
k8s-test01 ansible_host=192.168.0.250 
k8s-test02 ansible_host=192.168.0.251 
k8s-test03 ansible_host=192.168.0.252
k8s-test04 ansible_host=192.168.0.253


EOF

// Check if ansible is working:

ansible -i inventory/mycluster/inventory.ini all -m shell -a "uptime"

// Disable cloud-init update etc hosts

ansible --become -i inventory/mycluster/inventory.ini all -m shell -a "sed -i '/update_etc_hosts/d' /etc/cloud/cloud.cfg"

// Run the playbook to deploy the new K8S cluster

ansible-playbook --become -i inventory/mycluster/inventory.ini cluster.yml
