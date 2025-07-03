#!/bin/bash
set -eux

# --- Install containerd from Ubuntu repo ---
apt-get update && apt-get install -y ca-certificates curl gnupg lsb-release containerd awscli

# --- Load required kernel modules ---
modprobe br_netfilter
modprobe overlay
echo -e "br_netfilter\noverlay" | tee /etc/modules-load.d/k8s.conf

# --- Configure sysctl for networking ---
tee /etc/sysctl.d/99-kubernetes-cri.conf <<EOF
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF
sysctl --system

# --- Configure containerd ---
mkdir -p /etc/containerd
containerd config default | tee /etc/containerd/config.toml
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml

systemctl enable containerd
systemctl restart containerd

# --- Install Kubernetes tools ---
mkdir -p /etc/apt/keyrings
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.30/deb/Release.key | \
  gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] \
https://pkgs.k8s.io/core:/stable:/v1.30/deb/ /" > /etc/apt/sources.list.d/kubernetes.list

apt-get update
apt-get install -y kubelet kubeadm kubectl
apt-mark hold kubelet kubeadm kubectl

# --- Initialize Kubernetes master ---
kubeadm init --pod-network-cidr=10.244.0.0/16 --kubernetes-version=1.30.0

# --- Setup kubectl for ubuntu user ---
mkdir -p /home/ubuntu/.kube
cp -i /etc/kubernetes/admin.conf /home/ubuntu/.kube/config
chown ubuntu:ubuntu /home/ubuntu/.kube/config

# --- Install flannel CNI ---
su - ubuntu -c "kubectl apply -f https://raw.githubusercontent.com/flannel-io/flannel/master/Documentation/kube-flannel.yml"
kubectl completion bash | sudo tee /etc/bash_completion.d/kubectl > /dev/null

# --- Store proxy URL in SSM ---
REGION=$(curl -s http://169.254.169.254/latest/dynamic/instance-identity/document | grep region | awk -F\" '{print $4}')
MASTER_IP="$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)"
echo "$MASTER_IP"
aws ssm put-parameter --name "/k8s/proxy-url" --type "String" --value $MASTER_IP --overwrite --region $REGION

# --- Wait for join command to be available ---
for i in {1..10}; do
  JOIN_COMMAND=$(kubeadm token create --print-join-command 2>/dev/null || true)
  if [[ "$JOIN_COMMAND" == kubeadm* ]]; then
    echo "Join command is ready"
    break
  fi
  echo "Waiting for kubeadm join command to be available..."
  sleep 5
  if [[ $i -eq 10 ]]; then
    echo "Timeout waiting for join command"
    exit 1
  fi
done
# --- Store join command in SSM ---
aws ssm put-parameter --name "/k8s/join" --type "String" --value "$JOIN_COMMAND" --overwrite --region $REGION

# --- Start kubectl proxy ---
su - ubuntu -c "nohup kubectl proxy --address=0.0.0.0 --port=8001 --accept-hosts='^.*$' > /home/ubuntu/kubectl-proxy.log 2>&1 &"
