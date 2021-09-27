output "STAGING_SERVER_PUBLIC_IP" { value = var.public_edge_node ? module.stg-server.public_ip : "No public IP assigned" }
output "INFO" { value = var.use_remote_exec ? "Remote Execution used for deployment, check output for SSH key to access staging server": "CloudInit on staging server drives Airflow deployment.  Login to staging server and check /var/log/OCI-airflow-initialize.log for status" }
output "SSH_PRIVATE_KEY" { 
   value = nonsensitive(var.use_remote_exec ? tls_private_key.oke_ssh_key.private_key_pem : "SSH Key provided by user" )
}

output "CONNECT_DB_FROM_STAGING_SERVER" {
	value = "mysql -h var.db_ip -u var.db_user -D var.db_name -p"	
}

