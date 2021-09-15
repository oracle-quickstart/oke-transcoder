import oci
import time
import subprocess
import json
import os

from base64 import b64decode

def get_cursor_by_group(sc, sid, group_name, instance_name):
    print(" Creating a cursor for group {}, instance {}".format(group_name, instance_name), flush=True)
    cursor_details = oci.streaming.models.CreateGroupCursorDetails(group_name=group_name, instance_name=instance_name,
                                                                   type=oci.streaming.models.
                                                                   CreateGroupCursorDetails.TYPE_TRIM_HORIZON,
                                                                   commit_on_get=True)
    response = sc.create_group_cursor(sid, cursor_details)
    return response.data.value

def simple_message_loop(client, stream_id, initial_cursor, src_bucket):
    cursor = initial_cursor
    while True:
        get_response = client.get_messages(stream_id, cursor, limit=10)
        #If the stream is empty - wait 5 sec and check again
        if not get_response.data:
            time.sleep(5)

        # Process the messages
        if len(get_response.data)>0:
           print(" Read {} message(s)".format(len(get_response.data)), flush=True)

        for message in get_response.data:
            try:
#              print(b64decode(message.value.encode()).decode())
              msg_body = json.loads(b64decode(message.value.encode()).decode())
              if msg_body['eventType']=='com.oraclecloud.objectstorage.createobject' and \
                 msg_body['source']=='ObjectStorage' and \
                 msg_body['data']['additionalDetails']['bucketName']==src_bucket:

                 new_file = msg_body['data']['resourceName']
                 print("New file {} found".format(new_file), flush=True)
 
                 #Create a new job and pass the file name and job name
                 p = subprocess.call(['python3', 'new_job.py', new_file]) 
            except subprocess.CalledProcessError as e:
                print(e, flush=True) 
                exit(1)
            except Exception as e:
                print("Unknown request", flush=True)
                print(e, flush=True)

        # get_messages is a throttled method; clients should retrieve sufficiently large message
        # batches, as to avoid too many http requests.
        time.sleep(1)
        # use the next-cursor for iteration
        cursor = get_response.headers["opc-next-cursor"]


def main():
  try:
    oci_message_endpoint = os.environ['TC_STREAM_ENDPOINT']
    oci_stream_ocid = os.environ['TC_STREAM_OCID']
    src_bucket = os.environ['TC_SRC_BUCKET']

    signer = oci.auth.signers.InstancePrincipalsSecurityTokenSigner()
    stream_client = oci.streaming.StreamClient(config={}, signer=signer, service_endpoint=oci_message_endpoint)

# A cursor can be created as part of a consumer group.
# Committed offsets are managed for the group, and partitions
# are dynamically balanced amongst consumers in the group.
    group_cursor = get_cursor_by_group(stream_client, oci_stream_ocid, "transcode-group", "transcode-instance-1")
    simple_message_loop(stream_client, oci_stream_ocid, group_cursor, src_bucket)

  except Exception as e:
    print("ERROR: "+str(e), flush=True)
    raise Exception(e)

if __name__ == '__main__':
    main()

