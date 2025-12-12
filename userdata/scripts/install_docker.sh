#!/bin/bash

# Install docker
sudo dnf install -y dnf-utils
sudo dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo

sudo dnf install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin -y


# Enable and start docker daemon
sudo systemctl enable --now docker
#sudo systemctl start docker

# Add user to docker group
sudo usermod -a -G docker ${user} 
