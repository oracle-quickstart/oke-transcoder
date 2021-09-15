
#/bin/bash

# Install MySQL client
sudo yum install -y https://dev.mysql.com/get/mysql80-community-release-el7-3.noarch.rpm
sudo yum install -y mysql

# Connect to MySQL instance and create airflow database and user
mysql  -h ${db_ip} -u ${admin_db_user} -p${admin_db_password} -e "CREATE DATABASE IF NOT EXISTS ${db_name} CHARACTER SET utf8 COLLATE utf8_unicode_ci;;"
mysql  -h ${db_ip} -u ${admin_db_user} -p${admin_db_password} -e "CREATE USER IF NOT EXISTS ${db_user} IDENTIFIED WITH mysql_native_password BY '${db_password}'"
mysql  -h ${db_ip} -u ${admin_db_user} -p${admin_db_password} -e "GRANT ALL ON ${db_name}.* TO ${db_user}"

# Create transcoded_files table
mysql -h ${db_ip} -D ${db_name} -u ${db_user} -p${db_password} << EOF
create table if not exists transcoded_files(
   id INT NOT NULL AUTO_INCREMENT,
   name VARCHAR(100) NOT NULL UNIQUE,
   bucket VARCHAR(50) NOT NULL,
   object VARCHAR(100) NOT NULL, 
   url VARCHAR(100) NOT NULL, 
   create_date DATETIME NOT NULL,
   PRIMARY KEY ( id )
);
EOF
