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
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.30/deb/Release.key |   gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.30/deb/ /" > /etc/apt/sources.list.d/kubernetes.list

apt-get update
apt-get install -y kubelet kubeadm kubectl
apt-mark hold kubelet kubeadm kubectl
kubectl completion bash | sudo tee /etc/bash_completion.d/kubectl > /dev/null

# --- Wait for the join command to appear in SSM ---
REGION=$(curl -s http://169.254.169.254/latest/dynamic/instance-identity/document | grep region | awk -F\" '{print $4}')

for i in {1..30}; do
  JOIN_COMMAND=$(aws ssm get-parameter --name /k8s/join --region "$REGION" --query "Parameter.Value" --output text 2>/dev/null || echo "")
  if [[ "$JOIN_COMMAND" == kubeadm* ]]; then
    echo "Valid join command retrieved"
    break
  else
    echo "Waiting for valid join command..."
    sleep 10
  fi
done

$JOIN_COMMAND

# --- Setup kubectl proxy using master's IP ---
PROXY_URL=$(aws ssm get-parameter --name "/k8s/proxy-url" --region $REGION --query "Parameter.Value" --output text || true)
  echo "$PROXY_URL"
  mkdir -p /home/ubuntu/.kube
  echo -e "apiVersion: v1\nclusters:\n- cluster:\n    server: http://$PROXY_URL:8001\n  name: proxy\ncontexts:\n- context:\n    cluster: proxy\n    user: default\n  name: proxy\ncurrent-context: proxy\nkind: Config\npreferences: {}\nusers:\n- name: default\n  user: {}" > /home/ubuntu/.kube/config
  chown -R ubuntu:ubuntu /home/ubuntu/.kube