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
sudo echo "--enable-bootstrap-token-auth" > /var/snap/microk8s/current/args/kube-apiserver
sudo systemctl restart snap.microk8s.daemon-apiserver

echo "# kubectl..."
sudo snap install kubectl --classic --channel=1.21

echo "# krustlet..."
VERSION="v1.0.0-alpha.1"
wget https://krustlet.blob.core.windows.net/releases/krustlet-$VERSION-linux-amd64.tar.gz
tar -C /usr/local/bin -xzf krustlet-$VERSION-linux-amd64.tar.gz
curl -o bootstrap.sh https://raw.githubusercontent.com/krustlet/krustlet/main/scripts/bootstrap.sh
chmod +x bootstrap.sh
./bootstrap.sh
sudo mkdir -p /etc/krustlet/config
sudo chown -R ubuntu:ubuntu /etc/krustlet
cp $HOME/.krustlet/config/bootstrap.conf /etc/krustlet/config/bootstrap.conf
sudo chown ubuntu:ubuntu /etc/krustlet/config/bootstrap.conf

echo "# krustlet daemon file..."
sudo tee -a /etc/systemd/system/krustlet.service <<'EOF'
[Unit]
Description=Krustlet
[Service]
Restart=on-failure
RestartSec=5s
Environment=KUBECONFIG=/etc/krustlet/config/kubeconfig
Environment=KRUSTLET_CERT_FILE=/etc/krustlet/config/krustlet.crt
Environment=KRUSTLET_PRIVATE_KEY_FILE=/etc/krustlet/config/krustlet.key
Environment=KRUSTLET_DATA_DIR=/etc/krustlet
Environment=RUST_LOG=wasi_provider=info,main=info
ExecStart=/usr/local/bin/krustlet-wasi \
  --node-ip=127.0.0.1 \
  --node-name=krustlet \
  --bootstrap-file=$/etc/krustlet/config/bootstrap.conf
User=ubuntu
Group=ubuntu
[Install]
WantedBy=multi-user.target
EOF
sudo chmod +x /etc/systemd/system/krustlet.service

echo "# starting krustlet ..."
sudo systemctl enable krustlet
sudo systemctl start krustlet

echo "# waiting for krustlet to start ..."            
sleep 5 # wait for krustlet to start

echo "# signing cert request ..."
kubectl --kubeconfig=/home/ubuntu/.kube/config certificate approve $HOSTNAME-tls

echo "# complete!"
