#!/bin/sh
# Kubernetes Goat's own applications answer: the portal names itself, the registry scenario
# serves the Docker Registry API, the SSRF scenario's proxy and the DoS scenario answer.
set -u
get() { curl -sS --max-time 20 "$1" 2>/dev/null; }
get http://goat:1234/ | grep -qi "kubernetes goat" || { echo "portal"; exit 1; }
get http://goat:1235/v2/_catalog | grep -q '"repositories"' || { echo "poor-registry"; exit 1; }
for p in 1230 1231 1232 1233 1236; do
  [ "$(curl -s -o /dev/null --max-time 20 -w '%{http_code}' "http://goat:$p/")" != 000 ] || { echo "port $p"; exit 1; }
done
echo "portal, registry and the scenario ports answer"
