#!/usr/bin/env bash
set -euo pipefail

docker service rm http-host 2>/dev/null || true
docker service create --name http-host \
  --constraint "node.hostname==lpi4aServer" \
  --mode replicated --replicas 1 \
  --publish mode=host,target=30081,published=30081,protocol=tcp \
  busybox:1.36 sh -lc 'mkdir -p /www && \
    dd if=/dev/zero of=/www/large bs=1K count=1024 && \
    dd if=/dev/zero of=/www/medium bs=1K count=100 && \
    dd if=/dev/zero of=/www/small bs=1K count=1 && \
    echo ok >/www/index.html && httpd -f -p 30081 -h /www'
sleep 3
curl -sS "http://192.168.1.127:30081/" | head -n1

