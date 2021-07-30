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
sudo systemctl restart snap.microk8s.daemon-apiserver

echo "# kubectl..."
sudo snap install kubectl --classic --channel=1.21

echo "# Krustlet..."
VERSION="v1.0.0-alpha.1"
wget https://krustlet.blob.core.windows.net/releases/krustlet-$VERSION-linux-amd64.tar.gz
tar -C /usr/local/bin -xzf krustlet-$VERSION-linux-amd64.tar.gz
sudo mkdir -p /etc/krustlet/config
sudo chown -R ubuntu:ubuntu /etc/krustlet
cp $HOME/.kube/config /etc/krustlet/config/kubeconfig
sudo chown ubuntu:ubuntu /etc/krustlet/config/kubeconfig

echo "# krustlet config..."
sudo tee -a /etc/systemd/system/krustlet.service <<'EOF'
[Unit]
Description=Krustlet
[Service]
Restart=on-failure
RestartSec=5s
Environment=KUBECONFIG=/etc/krustlet/config/kubeconfig
Environment=KRUSTLET_DATA_DIR=/etc/krustlet
Environment=RUST_LOG=wasi_provider=info,main=info
Environment=KRUSTLET_BOOTSTRAP_FILE=/etc/krustlet/config/bootstrap.conf
ExecStart=/usr/local/bin/krustlet-wasi \
  -node-ip=127.0.0.1 \
  --node-name=krustlet
User=ubuntu
Group=ubuntu
[Install]
WantedBy=multi-user.target
EOF
sudo chmod +x /etc/systemd/system/krustlet.service
sudo systemctl enable krustlet
sudo systemctl start krustlet
sleep 5 # wait for krustlet to start
kubectl certificate approve $HOSTNAME-tls

echo "# complete!"
