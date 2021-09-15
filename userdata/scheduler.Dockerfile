FROM python:3.9-slim-buster

RUN pip install oci && pip install cx_Oracle
RUN pip install kubernetes

ADD consumer.py /app/consumer.py
ADD new_job.py /app/new_job.py
WORKDIR /app
CMD [ "python3", "./consumer.py" ]
