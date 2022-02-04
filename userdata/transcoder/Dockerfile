FROM python:3.9-slim-buster

RUN pip install oci
RUN pip install oci-cli
RUN apt update -y
RUN apt install -y default-mysql-client

WORKDIR /app

#RUN apt install ffmpeg -y
#Install the latest release version of ffmpeg (4.4)
RUN apt install -y wget
RUN apt install -y xz-utils
RUN apt install -y bc
RUN wget https://johnvansickle.com/ffmpeg/releases/ffmpeg-release-${cpu_arch}-static.tar.xz
RUN tar xvfJ ffmpeg-release-${cpu_arch}-static.tar.xz; rm ffmpeg-release-${cpu_arch}-static.tar.xz

RUN fname=$(ls -d ffmpeg*); ln -s /app/$fname/ffmpeg /usr/local/bin/ffmpeg; \
                            ln -s /app/$fname/ffprobe /usr/local/bin/ffprobe

ADD transcode.sh /app/transcode.sh
RUN chmod +x /app/transcode.sh

