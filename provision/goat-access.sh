#!/bin/sh
# The port forwards of upstream's access-kubernetes-goat.sh, same ports, kept running: each one
# is restarted when it ends (a pod restart ends a port-forward).
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
fwd() { # namespace service local:remote
  while :; do kubectl -n "$1" port-forward "svc/$2" --address 0.0.0.0 "$3" >/dev/null 2>&1; sleep 2; done &
}
fwd default build-code-service 1230:3000
fwd default health-check-service 1231:80
fwd default internal-proxy-api-service 1232:3000
fwd default system-monitor-service 1233:8080
fwd default kubernetes-goat-home-service 1234:80
fwd default poor-registry-service 1235:5000
fwd big-monolith hunger-check-service 1236:8080
wait
