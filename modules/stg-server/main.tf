resource "oci_core_instance" "stg-server" {
  availability_domain = var.availability_domain
  compartment_id      = var.compartment_ocid
  shape               = var.instance_shape
  display_name        = var.instance_name

  source_details {
    source_id   = var.image_id
    source_type = "image"
  }

  shape_config {
    ocpus             = 1
    memory_in_gbs     = 16
  }

  create_vnic_details {
    subnet_id        = var.subnet_id
    assign_public_ip = var.public_edge_node
  }

  metadata = {
    ssh_authorized_keys = var.ssh_public_key
    user_data = var.user_data
  }

  extended_metadata = {
    image_label = var.image_label
    oke_cluster_id = var.oke_cluster_id
    nodepool_id = var.nodepool_id
    repo_name = var.repo_name
    registry = var.registry
    registry_user = var.registry_user
    secret_id = var.secret_id
    tenancy_ocid = var.tenancy_ocid
    namespace = var.namespace
    kube_label = var.kube_label
    admin_db_user = var.admin_db_user
    admin_db_password = base64encode(var.admin_db_password)
    db_ip = var.db_ip
    db_name = var.db_name
    db_user = var.db_user
    db_password = base64encode(var.db_password)
  }
}

