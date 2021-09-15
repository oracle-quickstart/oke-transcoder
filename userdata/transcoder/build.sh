docker build -t transcoder:latest . --no-cache
docker tag transcoder:latest iad.ocir.io/ocisateam/mikep/transcoder:latest
docker push iad.ocir.io/ocisateam/mikep/transcoder:latest

