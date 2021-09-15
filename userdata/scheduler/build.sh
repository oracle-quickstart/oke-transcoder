docker build -t scheduler:latest . --no-cache
docker tag scheduler:latest iad.ocir.io/ocisateam/mikep/scheduler:latest
docker push iad.ocir.io/ocisateam/mikep/scheduler:latest
