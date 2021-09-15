data "oci_identity_availability_domains" "ads" {
  compartment_id = var.compartment_ocid
}

data "oci_mysql_mysql_db_system" "mysql_db" {
  db_system_id = oci_mysql_mysql_db_system.mysql_db.id
}
