#!/bin/sh
# Deploys Kubernetes Goat on the VM's k3s cluster the way upstream's setup-kubernetes-goat.sh
# does (same manifests, same order, the metadata-db Helm chart), then exposes the scenarios on
# ports 1230 to 1236 like upstream's access-kubernetes-goat.sh. Differences, and why:
# - Images are pinned to the digests of upstream's release (provision/scenarios/kustomization.yaml)
#   instead of an untagged `latest`.
# - The health-check scenario mounts the container runtime socket from
#   /run/containerd/containerd.sock (kind's path); k3s keeps it in /run/k3s/containerd/, so a
#   symlink (made at every boot by systemd-tmpfiles) stands at upstream's path.
# - access-kubernetes-goat.sh runs `kubectl port-forward` in the background of the user's shell;
#   here the same forwards (to the scenarios' Services) run as a systemd service, restarted when
#   a pod restarts, so the ports answer on the VM's address after every boot.
set -eu
SRC=/opt/isoloom/kubernetes-goat
HERE=/opt/isoloom/provision
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

echo 'L /run/containerd/containerd.sock - - - - /run/k3s/containerd/containerd.sock' \
  > /etc/tmpfiles.d/kubernetes-goat-containerd.conf
mkdir -p /run/containerd
systemd-tmpfiles --create /etc/tmpfiles.d/kubernetes-goat-containerd.conf

cd "$SRC"
echo "deploying insecure super admin scenario"
kubectl apply -f scenarios/insecure-rbac/setup.yaml
echo "deploying helm chart metadata-db scenario"
helm status metadata-db >/dev/null 2>&1 || helm install metadata-db scenarios/metadata-db/ \
  --set image.tag='latest@sha256:ef7031853252f16396a2ae2a9f8ec3c8355fa1f2979eadf4b64121a2bc7a1f95'
echo "deploying the vulnerable scenarios manifests"
kubectl kustomize --load-restrictor LoadRestrictionsNone "$HERE/scenarios" | kubectl apply -f -

for d in default/build-code-deployment default/health-check-deployment \
         default/internal-proxy-deployment default/system-monitor-deployment \
         default/kubernetes-goat-home-deployment default/poor-registry-deployment \
         big-monolith/hunger-check-deployment secure-middleware/cache-store-deployment \
         default/metadata-db; do
  kubectl -n "${d%%/*}" rollout status "deploy/${d#*/}" --timeout=900s
done

install -m 755 "$HERE/goat-access.sh" /usr/local/bin/kubernetes-goat-access
cat > /etc/systemd/system/kubernetes-goat-access.service <<UNIT
[Unit]
Description=Kubernetes Goat scenarios on ports 1230-1236 (upstream's access-kubernetes-goat.sh)
After=k3s.service
Wants=k3s.service

[Service]
ExecStart=/usr/local/bin/kubernetes-goat-access
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
UNIT
systemctl daemon-reload
systemctl enable --now kubernetes-goat-access.service
echo "Kubernetes Goat deployed; the portal answers on port 1234"
