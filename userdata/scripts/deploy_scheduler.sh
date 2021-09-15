#?/bin/bash
set -x

#build_dir="$HOME/airflow/build"
#mkdir -p $build_dir
#cd $build_dir

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

# Deploy airflow containers
kubectl -n ${namespace} apply -f scheduler.yaml

