# ---------------------------------------------------------------------------------------------------------------------
# AD Settings. By default uses AD1 
# ---------------------------------------------------------------------------------------------------------------------
#variable "availability_domain" {
#  default = "1"
#}

data "oci_identity_availability_domain" "ad" {
          compartment_id = "${var.tenancy_ocid}"
          ad_number      = 1
}

variable "availability_domain" {}

# ---------------------------------------------------------------------------------------------------------------------
# SSH Keys - Put this to top level because they are required
# ---------------------------------------------------------------------------------------------------------------------
variable "ssh_provided_public_key" {
  default = ""
}


# ---------------------------------------------------------------------------------------------------------------------
# Network Settings
# --------------------------------------------------------------------------------------------------------------------- 

# If you want to use an existing VCN set useExistingVcn = "true" and configure OCID(s) of myVcn, OKESubnet and edgeSubnet

variable "useExistingVcn" {
  default = "false"
}

variable "myVcn" {
  default = " "
}
variable "OKESubnet" {
  default = " "
}
variable "edgeSubnet" {
  default = " "
}

variable "custom_cidrs" { 
  default = "false"
}

variable "VCN_CIDR" {
  default = "10.0.0.0/16"
}

variable "edge_cidr" {
  default = "10.0.1.0/24"
}

variable "private_cidr" {
  default =  "10.0.2.0/24"
}

variable "vcn_dns_label" {
  default = "tcvcn"
}

variable "public_edge_node" {
  default = true 
}

# ---------------------------------------------------------------------------------------------------------------------
# OKE Settings
# ---------------------------------------------------------------------------------------------------------------------

variable "create_new_oke_cluster" {
  default = "true"
}

variable "existing_oke_cluster_id" {
  default = " "
}

variable "cluster_name" {
  default = "tc-cluster"
}

variable "kubernetes_version" {
  default = "v1.20.8"
}

variable "oke_nodepool_name" {
  default = "tc-nodepool"
}

variable "oke_nodepool_shape" {
  default = "VM.Standard.E3.Flex"
}

variable "oke_node_ocpu" {
  default = 4
}

variable "oke_node_memory" {
  default = 64
}

variable "oke_nodepool_size" {
  default = 1
}

variable "oke_namespace" {
  default = "transcode"
}

variable "kube_label" {
  default = "transcode"
}

variable "cluster_options_add_ons_is_kubernetes_dashboard_enabled" {
  default = "false"
}

variable "cluster_options_admission_controller_options_is_pod_security_policy_enabled" {
  default = "false"
}

variable "cluster_endpoint_config_is_public_ip_enabled" {
  default = "false" 
}


# ---------------------------------------------------------------------------------------------------------------------
# Cluster auto-scaling settings
# ---------------------------------------------------------------------------------------------------------------------
variable "cluster_autoscaling" {
  default = "true"
}

# Cluster autoscaler image depends on k8s version and OCI region you are using. To get a list of available images go to
# https://docs.oracle.com/en-us/iaas/Content/ContEng/Tasks/contengusingclusterautoscaler.htm

variable "oci_cluster_autoscaler_image" {
  default = "iad.ocir.io/oracle/oci-cluster-autoscaler:1.20.0-4"
}

variable "min_worker_nodes" {
  default = 1
}

variable "max_worker_nodes" {
  default = 5
}

# The requested vCPU for one transcoding job 
variable "cpu_request_per_job" {
  default = 1.5
}


# ---------------------------------------------------------------------------------------------------------------------
# OCI registry settings
# ---------------------------------------------------------------------------------------------------------------------

variable "registry" {
  default = "iad.ocir.io"
}

variable "repo_name" {
  default = "<OCIR repo name>"
}

# Set the user to login OCIR registry
variable "registry_user" {
  default = "oracleidentitycloudservice/<username>"
}

variable "image_label" {
  default = "1.6"
}

# ---------------------------------------------------------------------------------------------------------------------
# OCI vault secret ID where authentication key is stored 
# it is used for authentication when pushing/pulling images to/from OCIR registry 
# Set it to secret OCID where you store authentication token that is used to push/pull images from OCIR
# ---------------------------------------------------------------------------------------------------------------------
variable "vault_secret_id" {
  default = "<OCID of valut secret where authemtication token is stored>"
}


# ---------------------------------------------------------------------------------------------------------------------
# DB settings
# ---------------------------------------------------------------------------------------------------------------------

variable "meta_db_type" {
  default = "OCI Mysql"
}

variable "mysql_admin_username" {
  default = "mysqladmin"
}

variable "mysql_admin_password" {
  type = string
  sensitive = true
}


variable "mysql_shape" {
  default = "VM.Standard.E2.2"
}

variable "enable_backups" {
  default = "false"
}

variable "db_name" {
  default = "tc"
}

variable "db_user" {
  default = "tc"
}

variable "db_password" {
  type = string
  sensitive = true
}

# ---------------------------------------------------------------------------------------------------------------------
# Object Storage settings
# ---------------------------------------------------------------------------------------------------------------------

variable "src_bucket" {
  default = "<name of the bucket where media files are uploaded>"
}

variable "dst_bucket" {
  default = "name of the bucket where transcoded files are uploaded"
}

# ---------------------------------------------------------------------------------------------------------------------
# OCI Streaming Service settings
# ---------------------------------------------------------------------------------------------------------------------

variable "stream_name" {
  default = "transcode-stream"
}

variable "stream_partitions" {
  default = "1"
}

variable "stream_retention_in_hours" {
  default = "24"
}


# ---------------------------------------------------------------------------------------------------------------------
# Staging VM Settings
# ---------------------------------------------------------------------------------------------------------------------


variable "stg_server_name" {
  default = "staging-server"
}

variable "stg_server_shape" {
  default = "VM.Standard.E4.Flex"
}

# ---------------------------------------------------------------------------------------------------------------------
# User Settings
# ---------------------------------------------------------------------------------------------------------------------

variable "admin_tc_user" {
  default = "admin@tcdemo.com"
}

variable "admin_tc_password" {
  default = "Tr@nsc0de!"
}

# ---------------------------------------------------------------------------------------------------------------------
# FFMPEG transcoding settings
# ---------------------------------------------------------------------------------------------------------------------

variable project_name {
  default = "transcode"
}

variable "ffmpeg_config" {
  type = string
  default = <<EOF
  -map v:0 -s:0 1920x1080 -b:v:0 5M -maxrate 5M -minrate 5M -bufsize 10M 
  -map v:0 -s:1 1280x720 -b:v:1 3M -maxrate 3M -minrate 3M -bufsize 3M 
  -map v:0 -s:2 640x360 -b:v:2 1M -maxrate 1M -minrate 1M -bufsize 1M 
  -map a:0? -map a:0? -map a:0? -c:a aac -b:a 128k -ac 1 -ar 44100 
  -g 48 -sc_threshold 0 -c:v libx264 
  -f hls 
  -hls_time 5  
  -hls_playlist_type vod 
  -hls_segment_filename stream_%v_%03d.ts
  -master_pl_name master.m3u8
  EOF
}

#variable "ffmpeg_stream_map" {
#  default = "v:0,a:0 v:1,a:1 v:2,a:2"
#}

# ---------------------------------------------------------------------------------------------------------------------
# CDN settings
# ---------------------------------------------------------------------------------------------------------------------

variable "hls_stream_url" {
  default = ""
}

# ---------------------------------------------------------------------------------------------------------------------
# Self signed SSL certificate subject
# ---------------------------------------------------------------------------------------------------------------------
variable "ssl_cert_subject" {
  default = "/CN=$commonname/emailAddress=administrator@tcdemo.com"
}

# ---------------------------------------------------------------------------------------------------------------------
# To deploy transcoding module terraform can use remote-exec or CloudInit. By default it uses remote-exec
# All remote-exec commands are executed from the staging server that is provisioned as a part of this stack. 
# The staging server must be provisioned on a public subnet and must have a public IP. If access to a public IP on your 
# VCN is prohibited CloudInit must be used instead of remote-exec. CLOUDINIT IS NOT IMPLEMENTED YET FOR THIS STACK.  
# ---------------------------------------------------------------------------------------------------------------------

variable "use_remote_exec" {
  default = "true"
}

# ---------------------------------------------------------------------------------------------------------------------
# Environmental variables
# You probably want to define these as environmental variables.
# Instructions on that are here: https://github.com/oracle/oci-quickstart-prerequisites
# ---------------------------------------------------------------------------------------------------------------------

variable "compartment_ocid" {}

# Required by the OCI Provider

variable "tenancy_ocid" {}
variable "region" {}

