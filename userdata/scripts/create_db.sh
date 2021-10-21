
#/bin/bash

# Install MySQL client
sudo yum install -y https://dev.mysql.com/get/mysql80-community-release-el7-3.noarch.rpm
sudo yum install -y mysql

# Connect to MySQL instance and create transcoding database and user
mysql  -h ${db_ip} -u ${admin_db_user} -p${admin_db_password} -e "CREATE DATABASE IF NOT EXISTS ${db_name} CHARACTER SET utf8 COLLATE utf8_unicode_ci;;"
mysql  -h ${db_ip} -u ${admin_db_user} -p${admin_db_password} -e "CREATE USER IF NOT EXISTS ${db_user} IDENTIFIED WITH mysql_native_password BY '${db_password}'"
mysql  -h ${db_ip} -u ${admin_db_user} -p${admin_db_password} -e "GRANT ALL ON ${db_name}.* TO ${db_user}"

# Create jobs table
mysql -h ${db_ip} -D ${db_name} -u ${db_user} -p${db_password} << EOF
create table if not exists jobs(
   id INT NOT NULL AUTO_INCREMENT,
   project_id INT NOT NULL references projects(id),
   input_file VARCHAR(100) NOT NULL,
   input_bucket VARCHAR(50) NOT NULL,
   output_bucket VARCHAR(50) NOT NULL,
   transcoded_path VARCHAR(100), 
   start_time DATETIME NOT NULL,
   end_time DATETIME,
   status VARCHAR(10) NOT NULL,
   PRIMARY KEY ( id )
);
EOF

# Create transcoded_files table
mysql -h ${db_ip} -D ${db_name} -u ${db_user} -p${db_password} << EOF
create table if not exists transcoded_files(
   id INT NOT NULL AUTO_INCREMENT,
   name VARCHAR(100) NOT NULL UNIQUE references jobs(input_file),
   object VARCHAR(100) NOT NULL UNIQUE references jobs(transcoded_path),
   bucket VARCHAR(50) NOT NULL references jobs(output_bucket),
   job_id INT NOT NULL references jobs(id),
   create_time DATETIME NOT NULL,
   thumbnail VARCHAR(100),
   url VARCHAR(100) NOT NULL, 
   PRIMARY KEY ( id )
);
EOF

# Create projects table
mysql -h ${db_ip} -D ${db_name} -u ${db_user} -p${db_password} << EOF
create table if not exists projects(
   id INT NOT NULL AUTO_INCREMENT,
   name VARCHAR(50) NOT NULL UNIQUE,
   input_bucket VARCHAR(50) NOT NULL,
   output_bucket VARCHAR(50) NOT NULL,
   state VARCHAR(10) NOT NULL,
   PRIMARY KEY ( id )
);
EOF


