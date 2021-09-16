# FFMPEG Transcoder on OCI OKE

This quickstart template deploys [FFMPEG transcoder](https://www.ffmpeg.org/) on [Oracle Kubernetes Engine (OKE)](https://docs.oracle.com/en-us/iaas/Content/ContEng/Concepts/contengoverview.htm).  

# Data Flow

![image](https://user-images.githubusercontent.com/54962742/129648917-6e62834a-45d0-4a5d-a1ee-e6673fe080ca.png)



A media file is uploaded to the source object storage  bucket. It emits an event that creates a transcoding request in OSS streaming queue. Job scheduler container running on OKE is monitoring the queue and when a new request arrives it starts a new transcoding job running as a container on OKE. The transcoding job uses ffmpeg open source software to transcode to multiple resolutions and different bitrates. It combines the video and audio for every HLS stream, packages each combination, and create individual TS segments and the playlists. On completion it creates a master manifest file, uploads all the files to the destination bucket and updates transcoded_files table in MySQL  "tc" database with the playlist.

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

![image](https://user-images.githubusercontent.com/54962742/133594168-eb66ec6b-e384-4639-9c66-71239b68ab9a.png)


Note that in this example the registry username uses [Oracle Cloud Identity Service Federation](https://docs.oracle.com/en-us/iaas/Content/Identity/Tasks/federatingIDCS.htm).  If you are not using IDCS and using a local account, simply use the local account login (email address).

The auth token is fetched from OCI Vault Secrets - you will need to capture the secret OCID prior to deployment.

![Vault Secret](images/vault_secret.png)

A user uploads media files to OCI Object Storage Source Bucket. The transcoded files are stored in OCI Object Storage Destination Bucket. Both Source and Destination Buckets must be pre-created in advance and their names should be configured in the stack variables:

![image](https://user-images.githubusercontent.com/54962742/133596330-1818ef4a-94c1-4e00-b57d-53a96fd43c93.png)


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
* OCI Streaming Service (OSS) stream for transocding requests
* Event rule that sends a transcoding request to OSS stream when a new file is uploaded to OCI Object Storage Source Bucket
* OKE Cluster with a nodepool with cluster autoscaler is enabled
  * Scheduler container checking OSS stream for transcoding requests
  * Transcoding container is started when a new media file is uploaded

Simply click the Deploy to OCI button to create an ORM stack, then walk through the menu driven deployment.  Once the stack is created, use the Terraform Actions drop-down menu to Plan, then Apply the stack.

[![Deploy to Oracle Cloud](https://oci-resourcemanager-plugin.plugins.oci.oraclecloud.com/latest/deploy-to-oracle-cloud.svg)](https://console.us-ashburn-1.oraclecloud.com/resourcemanager/stacks/create?region=home&zipUrl=https://github.com/oracle-quickstart/oke-airflow/archive/2.0.0.zip)
    
When applying the stack remote execution logging is done in terraform output directly. When the stack is successfully applied it prints SSH key and public IP address of the staging-server VM. SSH access is enabled to the staging-server VM. 

After the stack is successfully applied to check that the transcoder is working
* Upload a new video file to the OCI Object Storage Source Bucket
* Check in Event Metrics that a new event is emitted
* Open OSS stream and check in OSS Metrics that a new request is added to the stream queue
* SSH the staging-server VVM and check that a new transcoder job is created using:
  kubectl -n transcode get pods
  You should see a transcoder pod is running. 
  
  ![image](https://user-images.githubusercontent.com/54962742/133600135-f40b3a5c-657c-46e4-b29c-193ea44a94d5.png)
  
  If the transcoder job fails to start describe the associated pod to check the log
  kubectl -n transcode describe pod <pod name>

  If the transcoder pod STATUS is in ERROR state check the pod log
  kubectl -n transcode logs <pod name>
  
 
* If transcoder pod started successfully attach to the container log and monitor the status

    kubectl -n transcode logs "pod NAME" --follow
    
* If the transcoder pod status is COMPLETED check OCI Object Storage Destination Bucket. For each transcoded file it creates a folder in the Destination Bucket with HLS manifest files (*.m3us) and segment files (*.ts) 
