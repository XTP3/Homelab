#!/bin/bash

echo "Installing Docker and Docker Compose..."
echo "Updating..."
apt update
echo "Installing curl..."
apt install curl -y
echo "Installing Docker..."
apt install -y docker.io
echo "Starting Docker..."
systemctl start docker
echo "Enabling Docker..."
systemctl enable docker
echo "Installing Docker Compose..."
curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose
echo "Done!"
docker --version
docker-compose --version
