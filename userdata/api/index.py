from flask import Flask, jsonify, request, session
from flask_httpauth import HTTPBasicAuth
import functools
from flask_cors import CORS
from werkzeug.security import generate_password_hash, check_password_hash
from kubernetes import client, config
from kubernetes.client.rest import ApiException
from datetime import datetime, timedelta
import pymysql
import json
import pytz
import os
import re
import secrets
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
    "RestApiUser": generate_password_hash("Tr@nsc0de!", method='sha256'),
}

app.secret_key = 'Tr@nsc0de!'

@auth.verify_password
def verify_password(username, password):
    if username in users and \
            check_password_hash(users.get(username), password):
        return username

def is_authorized(function):
    @functools.wraps(function)
    def wrapper(*a, **kw):

###        session_id = request.headers.get('Sessionid')
        
        # Check if this is an existing session
        if 'loggedin' in session:
          print("authorization succeeded - joining an existing session")
          return function(*a, **kw)
        
        # Authenticate using basic authentication
        auth = request.authorization
        if not auth:
          return jsonify(authentication_error='Unauthorized'), 401

        username = auth.get('username')
        password = auth.get('password')
        
        if not username or not password:
          return jsonify(authentication_error='Unauthorized'), 401
        
        if username in users and check_password_hash(users.get(username), password):   
          print("authorization succeeded using basic authentication")
          return function(*a, **kw)
        else:
          return jsonify(authentication_error='Unauthorized'), 401

    return wrapper

def is_admin_authorized(function):
    @functools.wraps(function)
    def wrapper(*a, **kw):
        
        # Check if this is an existing admin session
        if 'loggedin' in session and 'admin' in session:
          return function(*a, **kw)
#        else:
#          return jsonify(authentication_error='Unauthorized'), 401

        # Authenticate using basic authentication
        auth = request.authorization
        if not auth:
          return jsonify(authentication_error='Unauthorized'), 401

        username = auth.get('username')
        password = auth.get('password')
        
        if not username or not password:
          return jsonify(authentication_error='Unauthorized'), 401
        
        if username in users and check_password_hash(users.get(username), password):   
          print("authorization succeeded using basic authentication")
          return function(*a, **kw)
        else:
          return jsonify(authentication_error='Unauthorized'), 401

    return wrapper



def connect_db():
  # Open database connection
  con = pymysql.connect(host=db_host,
                       user=db_user,
                       password=db_password,
                       db=db_name)
  return con

# Get jobs info
@app.route('/api/v1/projects/<project_id>/jobs')
#@auth.login_required
@is_authorized
def get_jobs(project_id):

  print("in get_jobs")
  print(request.headers)

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
#@auth.login_required
@is_authorized
def get_job(job_id):
  # Open database connection
  db = connect_db()

  # prepare a cursor object using cursor() method
  cursor = db.cursor()

  # execute SQL query using execute() method.
  cursor.execute("SELECT * from jobs where id=%s",(job_id))

  row_headers=[x[0] for x in cursor.description] #this will extract row headers
  # Fetch one row 
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
#@auth.login_required
@is_authorized
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
#@auth.login_required
@is_authorized
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
#@auth.login_required
@is_authorized
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
#@auth.login_required
@is_authorized
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
#@auth.login_required
@is_authorized
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
#@auth.login_required
@is_authorized
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
    cursor.execute("update projects set input_bucket=%s where id=%s", (data['TC_SRC_BUCKET'], project_id))

  if data.get('TC_DST_BUCKET'):
    cursor.execute("update projects set output_bucket=%s where id=%s", (data['TC_DST_BUCKET'], project_id))

  db.commit()
  db.close()
  return jsonify(data=patch_configmap_response.data), 200
  


@app.route('/api/v1/projects', methods=['POST'])
#@auth.login_required
@is_authorized
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

#  if not data.get('TC_FFMPEG_STREAM_MAP'): 
#    data['TC_FFMPEG_STREAM_MAP'] = os.environ['TC_FFMPEG_STREAM_MAP']

  if not data.get('TC_CDN_BASE_URL'): 
    data['TC_CDN_BASE_URL'] = os.environ['TC_CDN_BASE_URL']

  data['TC_DB_HOST'] = os.environ['TC_DB_HOST']
  data['TC_DB_NAME'] = os.environ['TC_DB_NAME']
  data['TC_DB_USER'] = os.environ['TC_DB_USER']

# Check if the project with this name already exists    
  db = connect_db()
  cursor = db.cursor()

  cursor.execute("SELECT * from projects where name=%s", (name))

  row_headers=[x[0] for x in cursor.description] #this will extract row headers

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
#@auth.login_required
@is_authorized
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
          condition='{"eventType":["com.oraclecloud.objectstorage.createobject","com.oraclecloud.objectstorage.updateobject"], "data":{"additionalDetails":{"bucketName":'+str(buckets).replace("'", "\"")+'}}}'
      ))
      return update_rule_response

    except oci.exceptions.ServiceError as e:
      print("Exception when calling events_client api: %s\n" % e)
      return None

@app.route('/api/v1/statistics')
#@auth.login_required
@is_authorized
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
 
    rv = cursor.fetchone()
    number_of_files = rv[0]

    # disconnect from server
    db.close()
    json_data = {'jobs':jobs, 'transcoded_files': number_of_files}
    return jsonify(data=json_data), 200

@app.route('/api/v1/list_buckets')
#@auth.login_required
@is_authorized
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

@app.route('/api/v1/register', methods=['POST'])
def register():
  data = request.get_json()
  
  if data.get('email'):
    email = data['email']
    if not re.match(r'[^@]+@[^@]+\.[^@]+', email):
            return jsonify(error="failed to add user: Invalid email address!"), 400
  
  if data.get('name'):
    name = data['name']
  
  if data.get('password'):
    password = generate_password_hash(data['password'], method='sha256')  

  if not email or not name or not password:
    return jsonify(error="failed to add user: user email, name and password must be set in request body"), 400    
  
  is_admin = False 

  # add the new user to the database
  db = connect_db()
  cursor = db.cursor()

  # check if a user with this email already exists
  cursor.execute("select * from users where email=%s", (email))
  rv = cursor.fetchone()
  if rv:
    db.close()
    return jsonify(error="failed to add user: a user with this email already exists"), 400  

  api_key = secrets.token_hex(16) 

  cursor.execute("insert into users (email, name, password, is_admin, api_key, status) values (%s,%s,%s,%s,%s,%s)", (email, name, password, is_admin, api_key, "pending"))
  cursor.execute("select * from users where email=%s", (email))
  row_headers=[x[0] for x in cursor.description]
  rv = cursor.fetchone()
  if rv:
    # Combine column name and value in JSON format
    user = dict(zip(row_headers,rv))
  # Commit changes and disconnect from server
    db.commit()
    db.close()
    return jsonify(data=user), 200
  else:
    db.close()
    return jsonify(error="failed to add user"), 400    


@app.route('/api/v1/login', methods=['GET', 'POST'])
def login():
  data = request.get_json()
  
  if data.get('email'):
    email = data['email']
  
  if data.get('password'):
    password = data['password']

  if not email or not password:
    return jsonify(error="failed to autheiticate user: user email and password must be set in request body"), 400  

  db = connect_db()
  cursor = db.cursor()
  cursor.execute("select * from users where email=%s", (email))
  row_headers=[x[0] for x in cursor.description]
  rv = cursor.fetchone()
  if rv:
    # Combine column name and value in JSON format
    user = dict(zip(row_headers,rv))
    #Check that the user is active
    if user['status'] != "active":
      return jsonify(error="failed to authenticate user: the user is not active"), 401
    #Check user password 
    if check_password_hash(user['password'] , password):
      session['loggedin'] = True
      session['id'] = user['id'] 
      session['username'] = user['email']
      is_admin = user.get('is_admin')
      if is_admin:
        session['admin'] = True
      else:
        session['admin'] = False
      db.close()
      return jsonify(data={'username':user['email'], 'name':user['name']}, message="Logged on successfully!"), 200
    else:
      db.close()
      return jsonify(error="failed to authenticate user: incorrect password"), 401
    # if the above check passes, then we know the user has the right credentials
  else:
    db.close()
    return jsonify(error="failed to authenticate user: invalid username"), 401   


@app.route('/api/v1/logout')
@is_authorized
def logout():
    # Remove session data, this will log the user out
   username = session['username']
   session.pop('loggedin', None)
   session.pop('id', None)
   session.pop('username', None)
   # Redirect to login page
   return jsonify(data={'username':username},message="Logged out successfully!"), 200

@app.route('/api/v1/update_password', methods=['PUT'])
@is_authorized
def update_password():
  data = request.get_json()
  
  email = session['username']
  password = data.get('password')
  new_password = data.get('new_password')

  if not email:
    return jsonify(error="failed to reset: Not Authorized")

  if not password or not new_password:
    return jsonify(error="failed to reset password: user old password and new passwords must be set in request body"), 400  

  db = connect_db()
  cursor = db.cursor()
  cursor.execute("select * from users where email=%s", (email))
  row_headers=[x[0] for x in cursor.description]
  rv = cursor.fetchone()

  if rv:
    # Combine column name and value in JSON format
    user = dict(zip(row_headers,rv))
    if not check_password_hash(user['password'] , password):
      db.close()
      return jsonify(error="failed to change password: incorrect password"), 401
    elif new_password == password:
      db.close()
      return jsonify(error="failed to change password: new and old passwords are identical"), 400
    else:     
      password = generate_password_hash(new_password, method='sha256') 
      cursor.execute("update users set password=%s where email=%s", (password,email))
      db.commit() 
      db.close()
      return jsonify(data={}), 200
  else:
    db.close()
    return jsonify(error="failed to change password: user not found"), 400   

@app.route('/api/v1/reset_password', methods=['POST'])
#@is_authorized
def reset_password():
  data = request.get_json()
  
  email = data.get('email')

  api_key = data.get('api_key')

  password = data.get('password')

  if not email or not api_key or not password:
    return jsonify(error="failed to reset password: user email, api_key and the new password must be set in request body"), 400  

  db = connect_db()
  cursor = db.cursor()
  cursor.execute("select * from users where email=%s", (email))
  row_headers=[x[0] for x in cursor.description]
  rv = cursor.fetchone()

  if rv:
    # Combine column name and value in JSON format
    json_data = dict(zip(row_headers,rv))
    if api_key != json_data['api_key']:
      db.close()
      return jsonify(error="failed to reset password: incorrect api_key")
    password = generate_password_hash(data['password'], method='sha256') 
    cursor.execute("update users set password=%s where email=%s", (password,email))
    db.commit() 
    db.close()
    return jsonify(data={}), 200
  else:
    db.close()
    return jsonify(error="failed to reset password: invalid username"), 400   

@app.route('/api/v1/update_user', methods=['PUT'])
#@auth.login_required
@is_admin_authorized
def update_user():
  data = request.get_json()
  
  if data.get('email'):
    email = data['email']
  else:
    return jsonify(error="failed to update user: user email must be set in request body"), 400    

  db = connect_db()
  cursor = db.cursor()

  # check if a user with this email exists
  cursor.execute("select * from users where email=%s", (email))
  rv = cursor.fetchone()
  if not rv:
    db.close()
    return jsonify(error="failed to delete user: the user does not exists"), 400    
  
  if data.get('name'):
    name = data['name']
    cursor.execute("update users set name=%s where email=%s", (name, email))

  if data.get('status'):
    status = data['status'].lower()
    if status == "active" or status == "inactive" or status == "pending":
      cursor.execute("update users set status=%s where email=%s", (status, email))
    else:
      return jsonify(error="failed to update user: status is not set correctly in request body"), 400    

  if data.get('is_admin') != None:
    if data['is_admin'] == True:
      cursor.execute("update users set is_admin=%s where email=%s", (True, email))
    elif data['is_admin'] == False:
      cursor.execute("update users set is_admin=%s where email=%s", (False, email))
    else:
      return jsonify(error="failed to update user: is_admin is not set correctly in request body"), 400    
  
  db.commit()
  db.close()
  
  return jsonify(data={}), 200


@app.route('/api/v1/users/<string:status>')
@is_admin_authorized
def get_users(status):
 
  if status == '*':
    user_status = None
  elif status.lower() in ("active", "inactive", "pending"):
    user_status = status.lower()
  else:
    return jsonify(error="failed to get users: incorrect user status"), 400
  
  db = connect_db()
  cursor = db.cursor()

  if user_status:
    cursor.execute("select * from users where status=%s",(user_status))
  else:
    cursor.execute("select * from users")

  row_headers=[x[0] for x in cursor.description] #this will extract row headers
  # Fetch all rows 
  rv = cursor.fetchall()
  users=[]
  # Combine column name and value in JSON format
  if rv:
    for result in rv:
        user = dict(zip(row_headers,result))
        users.append({'id':user['id'],'email':user['email'],'name':user['name'],'is_admin':user['is_admin'],'status':user['status'],'api_key':user['api_key']})
  # disconnect from server
  db.close()
  return jsonify(data=users), 200


@app.route('/api/v1/users/id/<int:user_id>')
@is_admin_authorized
def get_user(user_id):
  db = connect_db()
  cursor = db.cursor()
  cursor.execute("SELECT * from users where id=%s",(user_id))

  row_headers=[x[0] for x in cursor.description] #this will extract row headers
  # Fetch one rows 
  rv = cursor.fetchone()
  
  if rv:
    # Combine column name and value in JSON format
    user = dict(zip(row_headers,rv))
    db.close()
    return jsonify(data={'id':user['id'],'email':user['email'],'name':user['name'],'is_admin':user['is_admin'],'status':user['status'],'api_key':user['api_key']}), 200
  else:
    db.close()
    return jsonify(error="Invalid user ID"), 400

@app.route('/api/v1/users/identity')
@is_authorized
def get_user_identity():
 
  if 'loggedin' in session:
    return jsonify(data={'username':session['username'], 'is_admin':session['admin']}), 200



if __name__ == '__main__':
   app.run(debug=True)