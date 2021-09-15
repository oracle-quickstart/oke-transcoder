locals {
  cluster_id = var.create_new_oke_cluster ? oci_containerengine_cluster.oke_cluster[0].id : var.existing_oke_cluster_id
  nodepool_id = oci_containerengine_node_pool.oke_node_pool.id
  nodepool_label = oci_containerengine_node_pool.oke_node_pool.name
}


output "cluster_id" {
  value = local.cluster_id
}

output "nodepool_id" {
  value = local.nodepool_id
}

output "nodepool_label" {
  value = local.nodepool_label
}

