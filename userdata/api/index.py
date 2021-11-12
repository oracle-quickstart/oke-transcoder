from flask import Flask, jsonify, request
from flask_httpauth import HTTPBasicAuth
from flask_cors import CORS
from werkzeug.security import generate_password_hash, check_password_hash
from kubernetes import client, config
from kubernetes.client.rest import ApiException
from datetime import datetime, timedelta
import pymysql
import json
import pytz
import os
import oci
from oci.object_storage.models import CreateBucketDetails
from oci.object_storage.models import CreatePreauthenticatedRequestDetails

db_host=os.environ['TC_DB_HOST']
db_name=os.environ['TC_DB_NAME']
db_user=os.environ['TC_DB_USER']
db_password=os.environ['TC_DB_PASSWORD']

app = Flask(__name__)
CORS(app)

auth = HTTPBasicAuth()

users = {
    "RestApiUser": generate_password_hash("Tr@nsc0de!"),
}

@auth.verify_password
def verify_password(username, password):
    if username in users and \
            check_password_hash(users.get(username), password):
        return username

def connect_db():
  # Open database connection
  con = pymysql.connect(host=db_host,
                       user=db_user,
                       password=db_password,
                       db=db_name)
  return con

# Get jobs info
@app.route('/api/v1/projects/<project_id>/jobs')
@auth.login_required
def get_jobs(project_id):

  db = connect_db()

  cursor = db.cursor()

  if (project_id == "*"):
    # Get list of jobs from all projects
    cursor.execute("SELECT * from jobs")
  else:
    # Get list of jobs from the project
    cursor.execute("SELECT * from jobs where project_id = %s", (project_id))

  row_headers=[x[0] for x in cursor.description] #this will extract row headers
  # Fetch all rows 
  rv = cursor.fetchall()

  # Combine column name and value in JSON format
  json_data=[]
  if rv:
    for result in rv:
        json_data.append(dict(zip(row_headers,result)))
  # disconnect from server
  db.close()
  return jsonify(data=json_data), 200

# Get job info
@app.route('/api/v1/jobs/<job_id>')
@auth.login_required
def get_job(job_id):
  # Open database connection
  db = connect_db()

  # prepare a cursor object using cursor() method
  cursor = db.cursor()

  # execute SQL query using execute() method.
  cursor.execute("SELECT * from jobs where id=%s",(job_id))

  row_headers=[x[0] for x in cursor.description] #this will extract row headers
  # Fetch all rows 
  rv = cursor.fetchone()
  
  if rv:
    json_data={}
    # Combine column name and value in JSON format
    json_data = dict(zip(row_headers,rv))
    db.close()
    return jsonify(data=json_data), 200
  else:
    db.close()
    return jsonify(error="Invalid job ID"), 400
  

# Get a list of transcoded files 
@app.route('/api/v1/projects/<project_id>/objects')
@auth.login_required
def get_objects(project_id):
  # Open database connection
  db = connect_db()

  # prepare a cursor object using cursor() method
  cursor = db.cursor()

  # execute SQL query using execute() method.
  if (project_id == "*"):
    cursor.execute("SELECT * from transcoded_files")
  else:
    cursor.execute("SELECT t.* from transcoded_files t, jobs j where t.job_id = j.id and j.project_id = %s", (project_id))

  row_headers=[x[0] for x in cursor.description] #this will extract row headers
  # Fetch all rows 
  rv = cursor.fetchall()
  # Combine column name and value in JSON format
  json_data=[]
  if rv:
    for result in rv:
        json_data.append(dict(zip(row_headers,result)))
  # disconnect from server
  db.close()
  return jsonify(data=json_data), 200

# Get a list of transcoded files in OS bucket 
@app.route('/api/v1/objects')
@auth.login_required
def get_objects_in_bucket():

  data = request.get_json()
  if not data:
    return jsonify(error="request body cannot be empty"), 400

  if data.get('bucket'):
    bucket = data['bucket']
  else:
    return jsonify(error="Failed to get objects - bucket is required"), 400

  # Open database connection
  db = connect_db()

  # prepare a cursor object using cursor() method
  cursor = db.cursor()

  # execute SQL query using execute() method.
  cursor.execute("SELECT * from transcoded_files where bucket=%s", (bucket))

  row_headers=[x[0] for x in cursor.description] #this will extract row headers
  # Fetch all rows 
  rv = cursor.fetchall()
  # Combine column name and value in JSON format
  json_data=[]
  if rv:
    for result in rv:
        json_data.append(dict(zip(row_headers,result)))
  # disconnect from server
  db.close()
  return jsonify(data=json_data), 200

@app.route('/api/v1/projects')
@auth.login_required
def get_projects():
  # Open database connection
  db = connect_db()

  # prepare a cursor object using cursor() method
  cursor = db.cursor()

  # execute SQL query using execute() method.
  cursor.execute("SELECT * from projects")

  row_headers=[x[0] for x in cursor.description] #this will extract row headers
  # Fetch all rows 
  rv = cursor.fetchall()
  # Combine column name and value in JSON format
  json_data=[]
  if rv:
    for result in rv:
        json_data.append(dict(zip(row_headers,result)))
  # disconnect from server
  db.close()
  return jsonify(data=json_data), 200

@app.route('/api/v1/projects/<project_id>')
@auth.login_required
def get_project(project_id):
  # Open database connection
  db = connect_db()

  # prepare a cursor object using cursor() method
  cursor = db.cursor()

  # execute SQL query using execute() method.
  cursor.execute("SELECT * from projects where id=%s", (project_id))

  row_headers=[x[0] for x in cursor.description] #this will extract row headers
  
  rv = cursor.fetchone()
  json_data={}
  if rv:
    # Combine column name and value in JSON format
    json_data = dict(zip(row_headers,rv))
  # disconnect from server
  db.close()
  return jsonify(data=json_data), 200

@app.route('/api/v1/projects/<project_id>/configuration')
@auth.login_required
def get_project_configuration(project_id):
  
  # Open database connection
  db = connect_db()

  # prepare a cursor object using cursor() method
  cursor = db.cursor()

  # execute SQL query using execute() method.
  cursor.execute("SELECT name from projects where id=%s", (project_id))
    
  rv = cursor.fetchone()
  
  if rv:
    project_name = rv[0]
  else:
    db.close()
    return jsonify(error="Invalid project ID"), 400
  
  # disconnect from server
  db.close() 
  
  config.load_incluster_config()
  api_instance = client.CoreV1Api()

  get_configmap_response = get_configmap(api_instance, project_name)
  if get_configmap_response:
    return jsonify(data=get_configmap_response.data), 200
  else:
    return jsonify(error="Failed to get project configuration"), 400


@app.route('/api/v1/projects/<project_id>/configuration', methods=['PUT'])
@auth.login_required
def update_project_configuration(project_id):

  data = request.get_json()

# Open database connection
  db = connect_db()

  # prepare a cursor object using cursor() method
  cursor = db.cursor()

  # execute SQL query using execute() method.
  cursor.execute("SELECT name from projects where id=%s", (project_id))
    
  rv = cursor.fetchone()
  
  if rv:
    project_name = rv[0]
  else:
    db.close()
    return jsonify(error="Invalid project ID"), 400
  

  if data.get('TC_PROJECT_NAME'):
     if data['TC_PROJECT_NAME'] != project_name:
        db.close()
        return jsonify(error="Failed to update project configuration - project name cannot be changed"), 400

  config.load_incluster_config()
  api_instance = client.CoreV1Api()

  patch_configmap_response = patch_configmap(api_instance, project_name, data)
  if not patch_configmap_response:
        db.close()
        return jsonify(error="Failed to update project configuration"), 400
  
  if data.get('TC_SRC_BUCKET'):
    # Update the event rule
    update_rule_response = add_bucket_to_event_rule (data['TC_DST_BUCKET'], "${event_rule_id}")
    if not update_rule_response:
      db.close()
      return jsonify(error="Failed to update the event rule"), 400
    cursor.execute("update projects set src_bucket=%s where id=%s", (data['TC_SRC_BUCKET'], project_id))

  if data.get('TC_DST_BUCKET'):
    cursor.execute("update projects set dst_bucket=%s where id=%s", (data['TC_DST_BUCKET'], project_id))

  db.commit()
  db.close()
  return jsonify(data=patch_configmap_response.data), 200
  


@app.route('/api/v1/projects', methods=['POST'])
@auth.login_required
def add_project():

  data = request.get_json()

  if not data:
        return jsonify(error="request body cannot be empty"), 400

  if data.get('TC_PROJECT_NAME'):
    name = data['TC_PROJECT_NAME']
  else:
    return jsonify(error="TC_PROJECT_NAME must be set in the request body"), 400


  if data.get('TC_SRC_BUCKET'):
    input_bucket = data['TC_SRC_BUCKET']
  else:
    return jsonify(error="TC_SRC_BUCKET must be set in the request body"), 400


  if data.get('TC_DST_BUCKET'):
    output_bucket = data['TC_DST_BUCKET']
  else:
    return jsonify(error="TC_DST_BUCKET must be set in the request body"), 400

  if not data.get('TC_OS_NAMESPACE'):
    data['TC_OS_NAMESPACE'] = os.environ['TC_OS_NAMESPACE']

  if not data.get('TC_STREAM_ENDPOINT'): 
    data['TC_STREAM_ENDPOINT'] = os.environ['TC_STREAM_ENDPOINT']
  
  if not data.get('TC_STREAM_OCID'): 
    data['TC_STREAM_OCID'] = os.environ['TC_STREAM_OCID']

  if not data.get('TC_OKE_NODEPOOL'): 
    data['TC_OKE_NODEPOOL'] = os.environ['TC_OKE_NODEPOOL']
    
  if not data.get('TC_OCIR_REPO'): 
    data['TC_OCIR_REPO'] = os.environ['TC_OCIR_REPO']
    
  if not data.get('TC_IMAGE_LABEL'): 
    data['TC_IMAGE_LABEL'] = os.environ['TC_IMAGE_LABEL']

  if not data.get('TC_CPU_REQUEST_PER_JOB'): 
    data['TC_IMAGE_LABTC_CPU_REQUEST_PER_JOB'] = os.environ['TC_CPU_REQUEST_PER_JOB']

  if not data.get('TC_FFMPEG_CONFIG'): 
    data['TC_FFMPEG_CONFIG'] = os.environ['TC_FFMPEG_CONFIG']

  if not data.get('TC_FFMPEG_STREAM_MAP'): 
    data['TC_FFMPEG_STREAM_MAP'] = os.environ['TC_FFMPEG_STREAM_MAP']

  if not data.get('TC_FFMPEG_HLS_BASE_URL'): 
    data['TC_FFMPEG_HLS_BASE_URL'] = os.environ['TC_FFMPEG_HLS_BASE_URL']

  data['TC_DB_HOST'] = os.environ['TC_DB_HOST']
  data['TC_DB_NAME'] = os.environ['TC_DB_NAME']
  data['TC_DB_USER'] = os.environ['TC_DB_USER']

# Check if the project with this name already exists    
  db = connect_db()
  cursor = db.cursor()

  cursor.execute("SELECT * from projects where name=%s", (name))

  row_headers=[x[0] for x in cursor.description] #this will extract row headers
  # Fetch all rows 
  rv = cursor.fetchone()
  
  if rv:
    db.close()
    return jsonify(error="Project with this name already exists"), 400

# Create preauthentication requests (PAR) for input and output buckets
  signer = oci.auth.signers.InstancePrincipalsSecurityTokenSigner()
  object_storage_client = oci.object_storage.ObjectStorageClient(config={}, signer=signer)

  namespace = object_storage_client.get_namespace().data
  ipar = create_par(object_storage_client, namespace, input_bucket, "par-"+input_bucket,1000)
  opar = create_par(object_storage_client, namespace, output_bucket, "par-"+output_bucket,1000)

  if not ipar or not opar:
    db.close()
    return jsonify(error="Failed to create PAR"), 400

# Update the event rule
  update_rule_response = add_bucket_to_event_rule (input_bucket, "${event_rule_id}")
  if not update_rule_response:
    db.close()
    return jsonify(error="Failed to update the event rule"), 400

# Create a new configmap 
  config.load_incluster_config()
  api_instance = client.CoreV1Api()

  configmap = create_configmap_object(name, data)
  create_configmap_response = create_configmap(api_instance, configmap)

  if not create_configmap_response:
    db.close()
    return jsonify(error="Failed to create a configmap"), 400

# Add the new project to DB projects table

  cursor.execute("insert into projects (name, input_bucket, output_bucket, input_bucket_par, output_bucket_par, state) values (%s,%s,%s,%s,%s,%s)", (name, input_bucket, output_bucket, ipar, opar, 'active'))
  cursor.execute("select * from projects where name=%s", (name))
  row_headers=[x[0] for x in cursor.description] #this will extract row headers
  # Fetch all rows 
  rv = cursor.fetchone()
  json_data={}
  if rv:
    # Combine column name and value in JSON format
    json_data = dict(zip(row_headers,rv))
  # Commit changes and disconnect from server
  db.commit()
  db.close()
  return jsonify(data=json_data), 200
  
@app.route('/api/v1/projects/<project_id>', methods=['PUT'])
@auth.login_required
def update_project(project_id):

  data = request.get_json()

  if not data:
    return jsonify(error="request body cannot be empty"), 400

# Open database connection
  db = connect_db()

  # prepare a cursor object using cursor() method
  cursor = db.cursor()

  # execute SQL query using execute() method.
  cursor.execute("SELECT name from projects where id=%s", (project_id))
    
  rv = cursor.fetchone()
  
  if rv:
    project_name = rv[0]
  else:
    db.close()
    return jsonify(error="Invalid project ID"), 400
  
  # disconnect from server
   

  if not data.get('state'):
    db.close()
    return jsonify(error="Failed to update project state - state value cannot be empty"), 400

  if data['state'] == "active" or data['state'] == "inactive":
    rv = cursor.execute("update projects set state=%s where id=%s", (data['state'], project_id))
    db.commit()
    db.close()
    return jsonify(data={}), 200
  
  else:
    db.close()
    return jsonify(error="Unable to update project state - invalid state value"), 400
    
  
def create_par(client, namespace, bucket, par_name, expiration_days):
   try:
     par_ttl = (datetime.utcnow() + timedelta(hours=24*expiration_days)).replace(tzinfo=pytz.UTC)
     create_par_details = CreatePreauthenticatedRequestDetails()
     create_par_details.name = par_name
     create_par_details.bucket_listing_action = "ListObjects"
     create_par_details.access_type = CreatePreauthenticatedRequestDetails.ACCESS_TYPE_ANY_OBJECT_READ_WRITE
     create_par_details.time_expires = par_ttl.isoformat()
     par = client.create_preauthenticated_request(namespace_name=namespace, bucket_name=bucket,
                                                        create_preauthenticated_request_details=create_par_details)
     par_url = client.base_client.get_endpoint() + par.data.access_uri
     return par_url

   except oci.exceptions.ServiceError as e:
     print("Exception when calling create_preauthenticated_request: %s\n" % e)
     return None


def create_configmap_object(configmap_name, configmap_data):
    # Configureate ConfigMap metadata
    configmap_metadata = client.V1ObjectMeta(
        name=configmap_name,
        namespace="${namespace}",
    )
    # Instantiate the configmap object
    configmap = client.V1ConfigMap(
        kind="ConfigMap",
        metadata=configmap_metadata,
        data=configmap_data
    )
    return configmap

def create_configmap(api_instance, configmap):
    try:
        api_response = api_instance.create_namespaced_config_map(
            namespace="${namespace}",
            body=configmap,
            pretty = 'pretty_example',
        )
        return api_response

    except ApiException as e:
        print("Exception when calling CoreV1Api->create_namespaced_config_map: %s\n" % e)
        return None

def get_configmap(api_instance, configmap_name):
  try:  
 
    api_response = api_instance.read_namespaced_config_map(name=configmap_name, namespace="${namespace}")

    return api_response
  
  except ApiException as e:
    print("Exception when calling CoreV1Api->read_namespaced_config_map: %s\n" % e)
    return None


def patch_configmap(api_instance, configmap_name, configmap_data):
  try:  
 
    configmap = {
            "kind": "ConfigMap",
            "apiVersion": "v1",
            "metadata": {
                "name": configmap_name
            }}
    configmap["data"]=configmap_data
    api_response = api_instance.patch_namespaced_config_map(name=configmap_name, namespace="${namespace}", body=configmap)

    return api_response
  
  except ApiException as e:
    print("Exception when calling CoreV1Api->patch_namespaced_config_map: %s\n" % e)
    return None


def add_bucket_to_event_rule(bucket, event_rule_id):
    try:
      signer = oci.auth.signers.InstancePrincipalsSecurityTokenSigner()
      events_client = oci.events.EventsClient(config={}, signer=signer)
      rule_response = events_client.get_rule(event_rule_id)
      data=json.loads(str(rule_response.data))
      condition=json.loads(data['condition'])
      buckets=condition['data']['additionalDetails']['bucketName']
      if buckets.count(bucket) == 0:
         buckets.append(bucket)
      update_rule_response = events_client.update_rule(
        rule_id = event_rule_id,
        update_rule_details=oci.events.models.UpdateRuleDetails(
          condition='{"eventType":["com.oraclecloud.objectstorage.createobject"], "data":{"additionalDetails":{"bucketName":'+str(buckets).replace("'", "\"")+'}}}'
      ))
      return update_rule_response

    except oci.exceptions.ServiceError as e:
      print("Exception when calling events_client api: %s\n" % e)
      return None

@app.route('/api/v1/statistics')
@auth.login_required
def statistics():

    db = connect_db()

    cursor = db.cursor()

    # Get jobs statistics
    cursor.execute("select count(*) count, status from jobs group by status;")

    row_headers=[x[0] for x in cursor.description] #this will extract row headers
    # Fetch all rows 
    rv = cursor.fetchall()

    # Combine column name and value in JSON format
    jobs=[]
    if rv:
      for result in rv:
          jobs.append(dict(zip(row_headers,result)))

    # Get number of transcoded files
    cursor.execute("select count(*) count from transcoded_files;")
    row_headers=[x[0] for x in cursor.description] #this will extract row headers
    # Fetch all rows 
    rv = cursor.fetchone()
    number_of_files = rv[0]

    # disconnect from server
    db.close()
    json_data = {'jobs':jobs, 'transcoded_files': number_of_files}
    return jsonify(data=json_data), 200

@app.route('/api/v1/list_buckets')
@auth.login_required
def get_list_of_buckets():
    data = request.get_json()
    if not data:
      return jsonify(error="request body cannot be empty"), 400
    
    if data.get('compartment_id'):
      compartment_id = data['compartment_id']
    else:
      return jsonify(error="Failed to get bucket list - compartment_id is required"), 400

    try:
      signer = oci.auth.signers.InstancePrincipalsSecurityTokenSigner()
      object_storage_client = oci.object_storage.ObjectStorageClient(config={}, signer=signer)
      namespace = object_storage_client.get_namespace().data
      resp = object_storage_client.list_buckets(namespace, compartment_id)
      bucket_list = []
      for bucket in resp.data:
        bucket_list.append(bucket.name)
      return jsonify(data=bucket_list), 200
 
    except oci.exceptions.ServiceError as e:
      print("Exception when calling object_storage_client api: %s\n" % e)
      return None



if __name__ == '__main__':
   app.run(debug=True)

