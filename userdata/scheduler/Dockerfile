FROM python:3.9-slim-buster

RUN pip install oci
RUN pip install kubernetes
RUN pip install pymysql

ADD consumer.py /app/consumer.py
ADD new_job.py /app/new_job.py
WORKDIR /app
CMD [ "python3", "./consumer.py" ]
