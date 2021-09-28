import os
import sys
from kubernetes import client, config
from oci.object_storage.models import CreateBucketDetails
import oci.object_storage

def create_job_object(os_file):
    # Configureate Pod template container
    print("Starting a new transcoding job", flush=True)
    repo=os.environ['TC_OCIR_REPO']
    oke_nodepool = os.environ['TC_OKE_NODEPOOL']
    cpu_per_job = os.environ['TC_CPU_REQUEST_PER_JOB']
    image_label = os.environ['TC_IMAGE_LABEL']
    requested_resources=client.V1ResourceRequirements(
        requests={"cpu": cpu_per_job}
    )
    container = client.V1Container(
        name="transcoder",
        image=repo+"/transcoder:"+image_label,
        env_from=[ client.V1EnvFromSource( config_map_ref=client.V1ConfigMapEnvSource(name="transcoder-config") ) ],
        env=[client.V1EnvVar(name="TC_DB_PASSWORD", value_from=client.V1EnvVarSource(secret_key_ref=client.V1SecretKeySelector(key="password", name="db-password")))],
        resources=requested_resources,
        command=["./transcode.sh",  os_file])
    image_pull_secret = client.V1LocalObjectReference(name="ocir-secret")
    node_selector = client.V1LocalObjectReference(name=oke_nodepool)
    # Create and configurate a spec section
    pod_template = client.V1PodTemplateSpec(
        metadata=client.V1ObjectMeta(name="transcode", labels={"app": "transcode"}), 
        spec=client.V1PodSpec(restart_policy="Never",
                              containers=[container],
                              image_pull_secrets=[image_pull_secret],
                              node_selector=node_selector))
    # Create the specification of deployment
    spec = client.V1JobSpec(
        template=pod_template,
        backoff_limit=2)
    # Instantiate the job object
    job = client.V1Job(
        api_version="batch/v1",
        kind="Job",
        metadata=client.V1ObjectMeta(generate_name="transcoder-"),
        spec=spec)

    return job

def create_job(api_instance, job):
    # Create job
    api_response = api_instance.create_namespaced_job(
        body=job,
        namespace="transcode")
    print("Job created. status='%s'" % str(api_response.status), flush=True)

def delete_job(api_instance, job_name):
    api_response = api_instance.delete_namespaced_job(
        name=job_name,
        namespace="transcode",
        body=client.V1DeleteOptions(
            propagation_policy='Foreground',
            grace_period_seconds=5))
    print("Job deleted. status='%s'" % str(api_response.status))

def main():
    # Configs can be set in Configuration class directly or using helper
    # utility. If no argument provided, the config will be loaded from
    # default location.

    if len(sys.argv) != 2:
        print("Usage: sys.argv[0] <name of object storage file>", flush=True)
        exit (1)

    os_file = sys.argv[1]

    # config.load_kube_config()
    config.load_incluster_config() # <-- IMPORTANT
    batch_v1 = client.BatchV1Api()

    # Create a job object with client-python API. The job we
    job = create_job_object(os_file)

    create_job(batch_v1, job)

#    delete_job(batch_v1, job_name)

if __name__ == '__main__':
    main()

