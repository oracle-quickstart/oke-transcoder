variable "tenancy_ocid" {}
variable "compartment_ocid" {}
variable "vcn_id" {}
variable "subnet_id" {}
variable "lb_subnet_id" {}
variable "cluster_name" {}
variable "kubernetes_version" {}
variable "oke_nodepool_name" {}
variable "oke_nodepool_shape" {}
variable "oke_nodepool_size" {}
variable "oke_node_ocpu" {}
variable "oke_node_memory" {}
variable "cluster_options_add_ons_is_kubernetes_dashboard_enabled" {}
variable "cluster_options_admission_controller_options_is_pod_security_policy_enabled" {}
variable "image_id" {}
variable "ssh_public_key" {}
variable "create_new_oke_cluster" {}
variable "existing_oke_cluster_id" {}
variable "cluster_endpoint_config_is_public_ip_enabled" {}
