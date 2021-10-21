#!/bin/sh
export FLASK_APP=./index.py
flask run -h 0.0.0.0 --cert=cert.pem --key=key.pem