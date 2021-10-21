#!/bin/bash
set -x
INPUT_FILE=$1
PROJECT_NAME=$TC_PROJECT_NAME
INPUT_BUCKET=$TC_SRC_BUCKET
OUTPUT_BUCKET=$TC_DST_BUCKET
OS_NAMESPACE=$TC_OS_NAMESPACE
OUTPUT_DIR="/tmp/ffmpeg"
THUMB_FILE=$INPUT_FILE'_thumb.png'

SQL_CONNECT="mysql -h $TC_DB_HOST -u $TC_DB_USER -p$TC_DB_PASSWORD -D $TC_DB_NAME -se"

#Download the input file from OCI object storage
echo "Downloading file $INPUT_FILE from $INPUT_BUCKET OS bucket"
ifile="/tmp/$(basename $INPUT_FILE)"
oci os object get --namespace $OS_NAMESPACE --bucket-name $INPUT_BUCKET --name $INPUT_FILE --file $ifile --auth instance_principal

if [ $? -eq 0 ]; then
        echo "Successfully downloaded the input file $INPUT_FILE from OS bucket $INPUT_BUCKET"
else
        echo "Failed to download the input file $INPUT_FILE from OS bucket  $INPUT_BUCKET"
        exit 1
fi

# Get project ID assigned to this input bucket
project_id=$($SQL_CONNECT "select id from projects where name='$PROJECT_NAME' and state='active'")

if [ -z $project_id ]; then
        echo "Failed to find an active project $project_name "
        exit 1
fi

# Update jobs table with a new job
job_id=$($SQL_CONNECT "insert into jobs (project_id, input_file, input_bucket, output_bucket, start_time, status) values ('$project_id', '$INPUT_FILE', '$INPUT_BUCKET', '$OUTPUT_BUCKET', now(), 'RUNNING'); SELECT LAST_INSERT_ID()")

#Check resolution of the video file
#res=`./ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=s=x:p=0 ../../images/big_buck_bunny_1080p_h264.mov`

#Create output directories
mkdir -p $OUTPUT_DIR
cd $OUTPUT_DIR

#Run ffmpeg transcoding
echo "Transcoding file $INPUT_FILE"
ffmpeg -i $ifile $TC_FFMPEG_CONFIG -var_stream_map "$TC_FFMPEG_STREAM_MAP" stream_%v.m3u8

if [ $? -eq 0 ]; then
        echo "Successfully transcoded $INPUT_FILE"
else
        echo "Failed to transcode $INPUT_FILE"
        $SQL_CONNECT "update jobs set status='ERROR' where job_id=$job_id"
        exit 1
fi

echo "Creating Thumbnail for $INPUT_FILE"
ffmpeg -i $ifile -ss 00:00:14.435 -s 1280x720 -frames:v 1 $THUMB_FILE

#Upload the transcoded files to OCI object storage bucket
echo "Uploading transcoded files to $TC_DST_BUCKET OS bicket"
#Firt check if the folder with this name already exists. If found - delete it including all objects inside the folder.
oci os object bulk-delete --namespace $OS_NAMESPACE --bucket-name $OUTPUT_BUCKET --prefix $INPUT_FILE/ --force --auth instance_principal
for file in *.{m3u8,ts}
do
   oci os object put --namespace $OS_NAMESPACE --bucket-name $OUTPUT_BUCKET --file $file --name $INPUT_FILE/$file --force --auth instance_principal
done

if [ $? -eq 0 ]; then
        echo "Successfully uploaded the transcoded files of $INPUT_FILE to OS bucket $OUTPUT_BUCKET"
else
        echo "Failed to upload the transcoded files of  $INPUT_FILE to OS bucket $OUTPUT_BUCKET"
        $SQL_CONNECT "update jobs set status='ERROR' where id=$job_id"
        exit 1
fi


echo "Uploading thumbnail file to $TC_DST_BUCKET OS bucket"
oci os object put --namespace $OS_NAMESPACE --bucket-name $OUTPUT_BUCKET --file $THUMB_FILE --name thumbnails/$THUMB_FILE --force --auth instance_principal

#Update jobs table with the job status
echo "Updating jobs table with COMPLETED job status"
$SQL_CONNECT "update jobs set transcoded_path='$INPUT_FILE/master.m3u8', status='COMPLETED', end_time=now() where id=$job_id"

#Update transcoded_files table
echo "Adding $INPUT_FILE to transcoded_files table"

if [ ! -z $TC_FFMPEG_HLS_BASE_URL ]; then
  URL="$TC_FFMPEG_HLS_BASE_URL/$INPUT_FILE/master.m3u8"
else
  URL=""
fi

$SQL_CONNECT "delete from transcoded_files where name='$INPUT_FILE'; insert into transcoded_files (name, object, bucket, job_id, create_time, thumbnail, url) values ('$INPUT_FILE', '$INPUT_FILE/master.m3u8', '$OUTPUT_BUCKET', $job_id, now(), 'thumbnails/$THUMB_FILE', '$URL')"