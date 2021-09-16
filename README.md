# FFMPEG Transcoder on OCI OKE

![image](https://user-images.githubusercontent.com/54962742/129648917-6e62834a-45d0-4a5d-a1ee-e6673fe080ca.png)

Data Flow:

A media file is uploaded to the source object storage  bucket. It emits an event that creates a transcoding request in OSS streaming queue. Job scheduler container running on OKE is monitoring the queue and when a new request arrives it starts a new transcoding job running as a container on OKE. The transcoding job uses ffmpeg open source software to transcode to multiple resolutions and different bitrates. It combines the video and audio for every HLS stream, packages each combination, and create individual TS segments and the playlists. On completion it creates a master manifest file, uploads all the files to the destination bucket and updates transcoded_files table in MySQL  "tc" database with the playlist.


This quickstart template deploys [FFMPEG transcoder](https://www.ffmpeg.org/) on [Oracle Kubernetes Engine (OKE)](https://docs.oracle.com/en-us/iaas/Content/ContEng/Concepts/contengoverview.htm).  

# Pre-Requisites
Transcoder on OKE depends on use of [Instance Principals](https://docs.oracle.com/en-us/iaas/Content/Identity/Tasks/callingservicesfrominstances.htm) for container execution.  You should create a [dynamic group](https://docs.oracle.com/en-us/iaas/Content/Identity/Tasks/managingdynamicgroups.htm) for the compartment where you are deploying your OKE cluster. The Dynamic Group must match either all compute instancers in the compartment or compute instances that have a certain tag. In this example, I am using a [Default Tag](https://docs.oracle.com/en-us/iaas/Content/Tagging/Tasks/managingtagdefaults.htm) for all resources in the target compartment to define the Dynamic Group:

tag.DynamicGroup.InstancePrincipal.value='Enabled'

After creating the group, you should set specific [IAM policies](https://docs.oracle.com/en-us/iaas/Content/Identity/Reference/policyreference.htm) for OCI services that can be used by the Dynamic Group. 

**Due to enforcement of [OSMS](https://docs.oracle.com/en-us/iaas/os-management/osms/osms-getstarted.htm) for compute resources created using an `manage all-resources` policy, you need to specify each service in a separate policy syntax**

At a minimum, the following policies are required:

    Allow dynamic-group <dynamic group name> to manage cluster-family in compartment id <compartment OCID>
    Allow dynamic-group <dynamic group name> to manage secret-family in compartment id <compartment OCID>
    Allow dynamic-group <dynamic group name> to manage vaults in compartment id <compartment OCID>
    Allow dynamic-group <dynamic-group-name> to manage streams in compartment id <compartment OCID>
    Allow dynamic-group <dynamic-group-name> to manage repos in compartment id <compartment OCID>
    Allow dynamic-group <dynamic-group-name> to manage object-family in compartment id <compartment OCID>
    Allow dynamic-group <dynamic-group-name> to manage instance-family in compartment id <compartment OCID>
    Allow dynamic-group <dynamic-group-name> to manage virtual-network-family in compartment id <compartment OCID>
    Allow dynamic-group <dynamic-group-name> to manage cluster-node-pools in compartment id <compartment OCID>
    Allow dynamic-group <dynamic-group-name> to manage vnics in compartment id <compartment OCID>
    Allow dynamic-group <dynamic-group-name> to manage mysql-family in compartment id <compartment OCID>
    Allow dynamic-group <dynamic-group-name> to inspect compartments in compartment id <compartment OCID>

Also required prior to deployment are an [OCI Registry](https://docs.oracle.com/en-us/iaas/Content/Registry/Concepts/registryoverview.htm), [OCI Vault](https://docs.oracle.com/en-us/iaas/Content/KeyManagement/Concepts/keyoverview.htm), [Auth Token](https://docs.oracle.com/en-us/iaas/Content/Identity/Tasks/managingcredentials.htm#create_swift_password), and a [Vault Secret](https://docs.oracle.com/en-us/iaas/Content/KeyManagement/Tasks/managingsecrets.htm) which contains the Auth Token.  

**The OCI registry must be in the tenanacy root and the user account associated with the auth token will need relevant privileges for the repo**

You will need to gather the repo name, and user login to access the registry.  You will also need to configure the registry field to the region where your registry is deployed.
![OKE Registry Settings]](https://user-images.githubusercontent.com/54962742/133593737-d2d766df-32ac-4d08-b7a2-399c4ff7a376.png)

Note that in this example the registry username uses [Oracle Cloud Identity Service Federation](https://docs.oracle.com/en-us/iaas/Content/Identity/Tasks/federatingIDCS.htm).  If you are not using IDCS and using a local account, simply use the local account login (email address).

The auth token is fetched from OCI Vault Secrets - you will need to capture the secret OCID prior to deployment.

![Vault Secret](images/vault_secret.png)

# Deployment
The main branch of this deployment uses [Oracle Resource Manager](https://docs.oracle.com/en-us/iaas/Content/ResourceManager/Concepts/resourcemanager.htm).  The shell branch uses stand-alone Terraform (CLI).   

This template deploys the following:

* Virtual Cloud Network
  * Public (Edge) Subnet
  * Private Subnet
  * Internet Gateway
  * NAT Gateway
  * Service Gateway
  * Route tables
  * Security Lists
    * TCP 22 for Edge SSH on public subnet
    * Ingress to both subnets from VCN CIDR
    * Egress to Internet for both subnets
* OCI Virtual Machine Staging-Server Instance
* OCI MySQL as a Service with a database where the list of transcoded filed is stored (transcoded-files table)
* OKE Cluster with a nodepool where cluster autoscaler is enabled
  * Scheduler container 
  * Transcoding container when a new media file is uploaded


Simply click the Deploy to OCI button to create an ORM stack, then walk through the menu driven deployment.  Once the stack is created, use the Terraform Actions drop-down menu to Plan, then Apply the stack.

[![Deploy to Oracle Cloud](https://oci-resourcemanager-plugin.plugins.oci.oraclecloud.com/latest/deploy-to-oracle-cloud.svg)](https://console.us-ashburn-1.oraclecloud.com/resourcemanager/stacks/create?region=home&zipUrl=https://github.com/oracle-quickstart/oke-airflow/archive/2.0.0.zip)
    
Remote execution logging is done in terraform output directly. 

Upload a new video file to the source OS bucket and check in Event Metrics that a new event is emitted. 

If you see a new event emitted, go to OSS stream and check in OSS Metrics that a new request is added to the queue

After that check that a new transcoder job is created

kubectl -n transcode get pods

You should see a transcoder pod is running. If the pod fails describe it and check the log.

If you see a transcoder pod you can attach to the container log by running

    kubectl -n logs "pod NAME" --follow
