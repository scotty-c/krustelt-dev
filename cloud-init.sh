#!/usr/bin/env bash
set -ex pipefail

export DEBIAN_FRONTEND=noninteractive

echo "# make..."
sudo apt-get install -y \
        make

echo "# microk8s..."
sudo snap install microk8s --classic --channel=1.21
mkdir -p $HOME/.kube/
sudo usermod -a -G microk8s $USER
sudo chown -f -R $USER ~/.kube
sudo microk8s config > $HOME/.kube/config
echo "--enable-bootstrap-token-auth" > /var/snap/microk8s/current/args/kube-apiserver
systemctl restart snap.microk8s.daemon-apiserver

echo "# kubectl..."
sudo snap install kubectl --classic --channel=1.21

echo "# Krustlet..."
VERSION="v1.0.0-alpha.1"
wget https://krustlet.blob.core.windows.net/releases/krustlet-$VERSION-linux-amd64.tar.gz
tar -C /usr/local/bin -xzf krustlet-$VERSION-linux-amd64.tar.gz
curl -o bootstrap.sh 'https://raw.githubusercontent.com/krustlet/krustlet/main/scripts/bootstrap.sh'
chmod +x bootstrap.sh
./bootstrap.sh

echo "# krustlet config..."
KUBECONFIG=${PWD}/krustlet-config 
terminal -e krustlet-wasi \
--node-ip=127.0.0.1 \
--node-name=krustlet \
--bootstrap-file=${HOME}/.krustlet/config/bootstrap.conf  
kubectl certificate approve $HOSTNAME-tls

echo "# complete!"