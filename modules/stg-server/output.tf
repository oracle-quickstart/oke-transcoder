output "stg-server" {
  value = oci_core_instance.stg-server
}

locals {

  private_ip = oci_core_instance.stg-server.private_ip

  public_ip = oci_core_instance.stg-server.public_ip

  instance_id = oci_core_instance.stg-server.id
    
}

output "private_ip" {
  value = local.private_ip
}

output "public_ip" {
  value = local.public_ip
}

output "instance_id" {
  value = local.instance_id
}
