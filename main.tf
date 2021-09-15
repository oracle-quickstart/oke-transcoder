module "network" { 
  source = "./modules/network"
  tenancy_ocid = var.tenancy_ocid
  compartment_ocid = var.compartment_ocid
  region = var.region
  useExistingVcn = var.useExistingVcn
  VCN_CIDR = var.VCN_CIDR
  edge_cidr = var.edge_cidr
  private_cidr = var.private_cidr
  vcn_dns_label  = var.vcn_dns_label
  custom_vcn = [var.myVcn]
  OKESubnet = var.OKESubnet
  edgeSubnet = var.edgeSubnet
  myVcn = var.myVcn
}

module "oci-stream" {
  source = "./modules/oci-stream"
  compartment_ocid = var.compartment_ocid
  stream_name = var.stream_name
  stream_partitions = var.stream_partitions
  stream_retention_in_hours = var.stream_retention_in_hours
#  subnet_id =  var.useExistingVcn ? var.OKESubnet : local.is_oke_public
}

module "oci-event" {
  source = "./modules/oci-event"
  compartment_ocid = var.compartment_ocid
  stream_id = module.oci-stream.stream_id
  bucket_name = var.src_bucket
}

module "oci-mysql" {
  source = "./modules/oci-mysql"
  availability_domain = data.oci_identity_availability_domain.ad.name
  compartment_ocid = var.compartment_ocid
  mysqladmin_password = var.mysql_admin_password
  mysqladmin_username = var.mysql_admin_username
  mysql_shape = var.mysql_shape
  enable_mysql_backups = var.enable_backups
  subnet_id =  var.useExistingVcn ? var.OKESubnet : local.is_oke_public
 
}

module "oke" {
  source = "./modules/oke"
  create_new_oke_cluster = var.create_new_oke_cluster
  existing_oke_cluster_id = var.existing_oke_cluster_id
  tenancy_ocid = var.tenancy_ocid
  compartment_ocid = var.compartment_ocid
  cluster_name = var.cluster_name
  kubernetes_version = var.kubernetes_version
  oke_nodepool_name = var.oke_nodepool_name
  oke_nodepool_shape = var.oke_nodepool_shape
  oke_nodepool_size = var.oke_nodepool_size
  cluster_options_add_ons_is_kubernetes_dashboard_enabled =  var.cluster_options_add_ons_is_kubernetes_dashboard_enabled
  cluster_options_admission_controller_options_is_pod_security_policy_enabled = var.cluster_options_admission_controller_options_is_pod_security_policy_enabled
  image_id = data.oci_core_images.oraclelinux7.images.0.id 
  vcn_id = var.useExistingVcn ? var.myVcn : module.network.vcn-id
  subnet_id = var.useExistingVcn ? var.OKESubnet : local.is_oke_public
  lb_subnet_id = module.network.edge-id
  ssh_public_key = var.use_remote_exec ? tls_private_key.oke_ssh_key.public_key_openssh : var.ssh_provided_public_key
  cluster_endpoint_config_is_public_ip_enabled = var.cluster_endpoint_config_is_public_ip_enabled
}

module "stg-server" {
  depends_on = [module.oke, module.oci-mysql, module.network]
  source = "./modules/stg-server"
  user_data = var.use_remote_exec ? base64encode(file("userdata/scripts/init.sh")) : base64encode(file("userdata/scripts/cloudinit.sh"))
  compartment_ocid = var.compartment_ocid
  availability_domain = data.oci_identity_availability_domain.ad.name
  image_id = data.oci_core_images.oraclelinux7.images.0.id 
  instance_shape   = var.stg_server_shape
  instance_name = var.stg_server_name
  subnet_id =  module.network.edge-id
  ssh_public_key = var.use_remote_exec ? tls_private_key.oke_ssh_key.public_key_openssh : var.ssh_provided_public_key
  public_edge_node = var.public_edge_node
  image_label = var.image_label
  oke_cluster_id = module.oke.cluster_id
  nodepool_id = module.oke.nodepool_id
  repo_name = var.repo_name
  registry = var.registry
  registry_user = var.registry_user
  secret_id = var.vault_secret_id
  tenancy_ocid = var.tenancy_ocid
  admin_db_user = var.mysql_admin_username
  admin_db_password = var.mysql_admin_password
  db_name = var.db_name
  db_ip = module.oci-mysql.db_ip
  db_port = module.oci-mysql.db_port
  namespace = var.oke_namespace
  db_user = var.db_user
  db_password = var.db_password
  kube_label = var.kube_label
}

module "transcoder" {
  count = var.use_remote_exec ? 1 : 0
  source                = "./modules/transcoder"
  transcoder_depends_on = [module.stg-server, module.oke, module.oci-mysql, module.network]
  compartment_ocid       = var.compartment_ocid
  tenancy_ocid           = var.tenancy_ocid
  instance_ip          = module.stg-server.public_ip
  cluster_id           = module.oke.cluster_id
  nodepool_id          = module.oke.nodepool_id
  nodepool_label       = module.oke.nodepool_label
  region               = var.region
  ssh_public_key = var.use_remote_exec ? tls_private_key.oke_ssh_key.public_key_openssh : var.ssh_provided_public_key
  ssh_private_key = tls_private_key.oke_ssh_key.private_key_pem
  registry = var.registry
  repo_name = var.repo_name
  registry_user = var.registry_user
  image_label = var.image_label
  secret_id = var.vault_secret_id
  namespace = var.oke_namespace
  kube_label = var.kube_label
  admin_db_user = var.mysql_admin_username
  admin_db_password = var.mysql_admin_password
  db_user = var.db_user
  db_password = var.db_password
  db_name = var.db_name
  db_ip = module.oci-mysql.db_ip
  db_port = module.oci-mysql.db_port
  src_bucket = var.src_bucket
  dst_bucket = var.dst_bucket
  stream_ocid = module.oci-stream.stream_id
  stream_endpoint = module.oci-stream.messages_endpoint
  ffmpeg_config = var.ffmpeg_config
  ffmpeg_stream_map = var.ffmpeg_stream_map
  hls_stream_url = var.hls_stream_url
  cpu_request_per_job = var.cpu_request_per_job
  cluster_autoscaling = var.cluster_autoscaling
  oci_cluster_autoscaler_image = var.oci_cluster_autoscaler_image
  min_worker_nodes = var.min_worker_nodes
  max_worker_nodes = var.max_worker_nodes
}
