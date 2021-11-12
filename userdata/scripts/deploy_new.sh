#?/bin/bash
set -x

# Create airflow namespace (if it does not exist)
kubectl get namespaces | grep transcode
if [[ $? -ne 0 ]]; then
kubectl create namespace transcode
fi

# Get authentication token stored in OCI vault 
auth_token=`oci secrets secret-bundle get --secret-id ocid1.vaultsecret.oc1.iad.amaaaaaaxkh5s6iawmr2cuhp6t5jwc3ypootoy4ggrmfjd2p57mterrrtfzq --stage CURRENT | jq  ."data.\"secret-bundle-content\".content" |  tr -d '"' | base64 --decode`

# Create ocir registry secret (if it does not exist already)
kubectl -n transcode get secrets | grep 'ocir-secret' 
if [[ $? -ne 0 ]]; then
	kubectl -n transcode create secret docker-registry ocir-secret --docker-server=iad.ocir.io --docker-username=ocisateam/oracleidentitycloudservice/michael.prestin@oracle.com --docker-password=$auth_token
fi

cd $HOME/transcoder/build

# Create config map with container environment variables
kubectl -n transcode apply -f configmap.yaml

# Create secret (encoded DB password)
kubectl -n transcode apply -f db-secret.yaml

# Deploy scheduler container
kubectl -n transcode apply -f scheduler.yaml

# Deploy api-server container
kubectl -n transcode apply -f api-server.yaml

ipar=$(oci os preauth-request create -bn input_images --name 'par1' --bucket-listing-action 'ListObjects' --access-type 'AnyObjectReadWrite'  --time-expires '2023-12-31' --query 'data."access-uri"' | tr -d '"')
opar=$(oci os preauth-request create -bn output_images --name 'par2' --bucket-listing-action 'ListObjects' --access-type 'AnyObjectReadWrite'  --time-expires '2023-12-31' --query 'data."access-uri"' | tr -d '"')

ipar_url="https://objectstorage.us-ashburn-1.oraclecloud.com$ipar"
opar_url="https://objectstorage.us-ashburn-1.oraclecloud.com$opar"

# Add the project to DB Projects table
mysql -h 10.0.2.56 -D tc -u tc -pR@vell001234 -e \
"delete from projects where name = 'transcode'; insert into projects (name, input_bucket, output_bucket, input_bucket_PAR, output_bucket_PAR, state) values ('transcode', 'input_images', 'output_images', '$ipar_url', '$opar_url', 'active')"



