output "db_ip" {
    value = oci_mysql_mysql_db_system.mysql_db.endpoints[0].ip_address 
}

output "db_port" {
    value = oci_mysql_mysql_db_system.mysql_db.endpoints[0].port
}
