#!/bin/sh
export FLASK_APP=./index.py
uwsgi --socket 0.0.0.0:5000 --buffer-size=32768 --wsgi-file index.py --callable app --processes 4 --threads 2 --stats 127.0.0.1:9191