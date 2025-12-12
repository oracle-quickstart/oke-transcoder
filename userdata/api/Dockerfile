FROM python:3.11-slim

# Installing packages
RUN pip install flask
RUN pip install flask_httpauth
RUN pip install flask-cors
RUN pip install werkzeug
RUN pip install pymysql
RUN pip install kubernetes
RUN pip install oci
RUN pip install pytz

RUN apt -y update && apt -y install build-essential python-dev-is-python3
RUN pip install uwsgi

# Defining working directory and adding source code
WORKDIR /app
COPY bootstrap.sh ./
RUN chmod +x bootstrap.sh
COPY index.py ./
# Start app
EXPOSE 5000
ENTRYPOINT ["/app/bootstrap.sh"]
