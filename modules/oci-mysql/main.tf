resource "oci_mysql_mysql_db_system" "mysql_db" {
    admin_password = var.mysqladmin_password
    admin_username = var.mysqladmin_username
    availability_domain = var.availability_domain
    compartment_id = var.compartment_ocid
    shape_name = var.mysql_shape
    subnet_id = var.subnet_id
    backup_policy {
    is_enabled        = var.enable_mysql_backups
    retention_in_days = "10"
    }
    description = "Transcode Database"
    port          = "3306"
    port_x        = "33306"
    data_storage_size_in_gb = 50
}

