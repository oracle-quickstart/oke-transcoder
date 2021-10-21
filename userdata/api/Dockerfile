FROM python:3.9-slim-buster

# Installing packages
RUN pip install flask
RUN pip install flask_httpauth
RUN pip install werkzeug
RUN pip install pymysql
RUN pip install kubernetes
RUN pip install oci


# Defining working directory and adding source code
WORKDIR /app
COPY bootstrap.sh ./
RUN chmod +x bootstrap.sh
COPY index.py cert.pem key.pem ./
# Start app
EXPOSE 5000
ENTRYPOINT ["/app/bootstrap.sh"]