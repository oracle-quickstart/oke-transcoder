#!/bin/bash

sudo dnf -y install oraclelinux-developer-release-el8
sudo dnf -y install python36-oci-cli

echo "export OCI_CLI_AUTH=instance_principal" >> ~/.bash_profile
echo "export OCI_CLI_AUTH=instance_principal" >> ~/.bashrc
