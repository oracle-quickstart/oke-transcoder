#!/bin/bash

#curl -L -O https://raw.githubusercontent.com/oracle/oci-cli/master/scripts/install/install.sh && chmod a+x install.sh && ./install.sh --accept-all-defaults

sudo yum install python36-oci-cli

echo "export OCI_CLI_AUTH=instance_principal" >> ~/.bash_profile
echo "export OCI_CLI_AUTH=instance_principal" >> ~/.bashrc