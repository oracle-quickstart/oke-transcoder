#?/bin/bash
set -x

# Create airflow namespace (if it does not exist)
kubectl get namespaces | grep ${namespace}
if [[ $? -ne 0 ]]; then
kubectl create namespace ${namespace}
fi

# Get authentication token stored in OCI vault 
auth_token=`oci secrets secret-bundle get --secret-id ${secret_id} --stage CURRENT | jq  ."data.\"secret-bundle-content\".content" |  tr -d '"' | base64 --decode`

# Create ocir registry secret (if it does not exist already)
kubectl -n ${namespace} get secrets | grep 'ocir-secret' 
if [[ $? -ne 0 ]]; then
	kubectl -n ${namespace} create secret docker-registry ocir-secret --docker-server=${registry} --docker-username=${tenancy_name}/${registry_user} --docker-password=$auth_token
fi

cd $HOME/transcoder/build

# Create config map with container environment variables
kubectl -n ${namespace} apply -f configmap.yaml

# Create secret (encoded DB password)
kubectl -n ${namespace} apply -f db-secret.yaml

# Deploy scheduler container
kubectl -n ${namespace} apply -f scheduler.yaml

# Deploy api-server container
kubectl -n ${namespace} apply -f api-server.yaml

#Create preauthentucation request (PAR) for input and output buckets
ipar=$(oci os preauth-request create -bn ${src_bucket} --name 'par1' --bucket-listing-action 'ListObjects' --access-type 'AnyObjectReadWrite'  --time-expires '2023-12-31' --query 'data."access-uri"' | tr -d '"')
opar=$(oci os preauth-request create -bn ${dst_bucket} --name 'par2' --bucket-listing-action 'ListObjects' --access-type 'AnyObjectReadWrite'  --time-expires '2023-12-31' --query 'data."access-uri"' | tr -d '"')

ipar_url="https://objectstorage.${region}.oraclecloud.com$ipar"
opar_url="https://objectstorage.${region}.oraclecloud.com$opar"

# Add the project to DB Projects table
mysql -h ${db_ip} -D ${db_name} -u ${db_user} -p${db_password} -e \
"delete from projects where name = '${project_name}'; insert into projects (name, input_bucket, output_bucket, input_bucket_PAR, output_bucket_PAR, state) values ('${project_name}', '${src_bucket}', '${dst_bucket}', '$ipar_url', '$opar_url', 'active')"


