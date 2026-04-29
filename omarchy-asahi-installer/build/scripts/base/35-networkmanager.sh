#!/bin/bash
# Configure NetworkManager with iwd backend
set -e

echo "Configuring NetworkManager..."

mkdir -p /etc/NetworkManager/conf.d/

cat > /etc/NetworkManager/conf.d/wifi_backend.conf <<EOF
[device]
wifi.backend=iwd
EOF

systemctl enable NetworkManager.service
systemctl enable iwd.service

echo "NetworkManager configured."
