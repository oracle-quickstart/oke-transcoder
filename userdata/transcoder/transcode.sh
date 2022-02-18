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
mkdir -p $OUTPUT_DIR/$INPUT_FILE
cd $OUTPUT_DIR/$INPUT_FILE

#Check duration of the video stream
video_duration=$(ffprobe -v error -of flat=s_ -select_streams v -show_entries stream=duration -of default=noprint_wrappers=1:nokey=1 $ifile)

#Check if there is an audio stream
audio_duration=$(ffprobe -v error -of flat=s_ -select_streams a -show_entries stream=duration -of default=noprint_wrappers=1:nokey=1 $ifile)

number_of_video_streams=$(echo $TC_FFMPEG_CONFIG | egrep -o "\-map +v" | wc -l)

# Check what streaming protocol is used

if [[ "$TC_FFMPEG_CONFIG" == *" -f hls"* ]]; then
    streaming_protocol="HLS"
    manifest_name="master.m3u8"
elif [[ "$TC_FFMPEG_CONFIG" == *" -f dash"* ]]; then
    streaming_protocol="DASH"
    manifest_name="dash.mpd"
else
    echo "Unsupported streaming protocol. Supported protocols are HLS & DASH"
    exit 1
fi

# If HLS protocol is used set FFMPEG Stream Map for HLS
# v:0,a:0 v:1,a:1 ... (if there are both video and audio streams) 
# v:0 v:1 ... (if there are only video streams)

TC_FFMPEG_STREAM_MAP=""

if [[ $streaming_protocol == "HLS" ]]; then
  #Set stream map between video and audio streams for HLS 

  if [ "$audio_duration" ]; then
    for ((i=0;i<$number_of_video_streams;i++)) 
    do   
        TC_FFMPEG_STREAM_MAP="$TC_FFMPEG_STREAM_MAP v:$i,a:$i"
    done
  else
    echo "No audio stream"
    for ((i=0;i<$number_of_video_streams;i++)) 
    do   
        TC_FFMPEG_STREAM_MAP="$TC_FFMPEG_STREAM_MAP v:$i"
    done
  fi

  #Run HLS transcoding
  echo "Transcoding file $INPUT_FILE"
  ffmpeg -i $ifile $TC_FFMPEG_CONFIG -var_stream_map "$TC_FFMPEG_STREAM_MAP" stream_%v.m3u8     

else  #Set stream map between video and audio streams for DASH   
  TC_FFMPEG_STREAM_MAP="id=0,streams=v id=1,streams=a"

  #Run DASH transcoding
  echo "Transcoding file $INPUT_FILE"
  ffmpeg -i $ifile $TC_FFMPEG_CONFIG -adaptation_sets "$TC_FFMPEG_STREAM_MAP" dash.mpd
fi


if [ $? -eq 0 ]; then
        echo "Successfully transcoded $INPUT_FILE"
else
        echo "Failed to transcode $INPUT_FILE"
        $SQL_CONNECT "update jobs set status='ERROR' where id=$job_id"
        exit 1
fi

#Upload the transcoded files to OCI object storage bucket
echo "Uploading transcoded files to $TC_DST_BUCKET OS bicket"
#Firt check if the folder with this name already exists. If found - delete it including all objects inside the folder.
oci os object bulk-delete --namespace $OS_NAMESPACE --bucket-name $OUTPUT_BUCKET --prefix $INPUT_FILE/ --force --auth instance_principal
oci os object bulk-upload --namespace $OS_NAMESPACE --bucket-name $OUTPUT_BUCKET --src-dir $OUTPUT_DIR --overwrite --auth instance_principal

if [ $? -eq 0 ]; then
        echo "Successfully uploaded the transcoded files of $INPUT_FILE to OS bucket $OUTPUT_BUCKET"
else
        echo "Failed to upload the transcoded files of  $INPUT_FILE to OS bucket $OUTPUT_BUCKET"
        $SQL_CONNECT "update jobs set status='ERROR' where id=$job_id"
        exit 1
fi

# Set thumbnail duration to 10 sec. If video duration is less than 10 sec set thumbnail duration to video duration
if (( $(echo "$video_duration > 10" |bc -l) )); then
    ffmpeg -i $ifile -ss 00:00:10 -s 1280x720 -frames:v 1 $THUMB_FILE
else
    ffmpeg -i $ifile -s 1280x720 -frames:v 1 $THUMB_FILE
fi

echo "Uploading thumbnail file to $TC_DST_BUCKET OS bucket"
oci os object put --namespace $OS_NAMESPACE --bucket-name $OUTPUT_BUCKET --file $THUMB_FILE --name thumbnails/$THUMB_FILE --force --auth instance_principal


#Update jobs table with the job status
echo "Updating jobs table with COMPLETED job status"
$SQL_CONNECT "update jobs set transcoded_path='$INPUT_FILE/$manifest_name', status='COMPLETED', end_time=now() where id=$job_id"

#Update transcoded_files table
echo "Adding $INPUT_FILE to transcoded_files table"

if [ ! -z $TC_CDN_BASE_URL ]; then
  URL="$TC_CDN_BASE_URL/$INPUT_FILE/$manifest_name"
else
  URL=""
fi

$SQL_CONNECT "delete from transcoded_files where name='$INPUT_FILE' and bucket='$OUTPUT_BUCKET'; insert into transcoded_files (name, object, bucket, job_id, create_time, thumbnail, url) values ('$INPUT_FILE', '$INPUT_FILE/$manifest_name', '$OUTPUT_BUCKET', $job_id, now(), 'thumbnails/$THUMB_FILE', '$URL')"