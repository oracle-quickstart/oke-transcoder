FROM python:3.9-slim-buster

RUN pip install oci && pip install cx_Oracle
RUN pip install oci-cli
RUN apt update -y
RUN apt install -y default-mysql-client

WORKDIR /app

#RUN apt install ffmpeg -y
#Install the latest release version of ffmpeg (4.4)
RUN apt install -y wget
RUN apt install -y xz-utils
RUN wget https://johnvansickle.com/ffmpeg/releases/ffmpeg-release-amd64-static.tar.xz
RUN tar xvfJ ffmpeg-release-amd64-static.tar.xz
RUN ln -s /app/ffmpeg-4.4-amd64-static/ffmpeg /usr/local/bin/ffmpeg
RUN ln -s /app/ffmpeg-4.4-amd64-static/ffprob /usr/local/bin/ffprob

ADD transcode.sh /app/transcode.sh
RUN chmod +x /app/transcode.sh
