#!/bin/bash
# Copyright 2017, 2019, Oracle Corporation and/or affiliates.  All rights reserved.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl

sudo dnf -y install oracle-olcne-release-el8
sudo dnf config-manager --enable ol8_olcne19
sudo dnf -y install kubectl

echo "alias k='kubectl'" >> ~/.bashrc
