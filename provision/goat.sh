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
# - Four flags are the player's own (CTF_FLAG_*, given at launch): /root/flag.txt on the node
#   (container escape), the cache-store's Redis key, and the goatvault and vaultapikey Secrets.
set -eu
SRC=/opt/isoloom/kubernetes-goat
HERE=/opt/isoloom/provision
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

echo 'L /run/containerd/containerd.sock - - - - /run/k3s/containerd/containerd.sock' \
  > /etc/tmpfiles.d/kubernetes-goat-containerd.conf
mkdir -p /run/containerd
systemd-tmpfiles --create /etc/tmpfiles.d/kubernetes-goat-containerd.conf

# CyberCTF per-player flags, given by the launcher; without them (CI, a run by hand) the
# development values, upstream's flags where upstream has one.
dev_main='FLAG{dev-kubernetes-goat}'
dev_bypass='k8s-goat-a5a3e446faafa9d0514b3ff396ab8a40'
dev_env='k8s-goat-cd2da27224591da2b48ef83826a8a6c3'
dev_rbac='k8s-goat-85057846a8046a25b35f38f3a2649dce'
flag_main=${CTF_FLAG_MAIN:-$dev_main}
flag_bypass=${CTF_FLAG_NAMESPACES_BYPASS:-$dev_bypass}
flag_env=${CTF_FLAG_ENVIRONMENT_INFORMATION:-$dev_env}
flag_rbac=${CTF_FLAG_RBAC_LEAST_PRIVILEGE:-$dev_rbac}

# Container escape: a root-only file on the node.
printf '%s\n' "$flag_main" > /root/flag.txt
chmod 600 /root/flag.txt
# Namespaces bypass: the Redis seed the cache-store loads at start (mounted by the kustomization).
kubectl create namespace secure-middleware --dry-run=client -o yaml | kubectl apply -f -
printf 'SET SECRETSTUFF "%s"\n' "$flag_bypass" > /tmp/ctf-data.redis
kubectl -n secure-middleware create configmap cache-store-ctf-data \
  --from-file=data.redis=/tmp/ctf-data.redis --dry-run=client -o yaml | kubectl apply -f -
rm -f /tmp/ctf-data.redis

cd "$SRC"
echo "deploying insecure super admin scenario"
kubectl apply -f scenarios/insecure-rbac/setup.yaml
echo "deploying helm chart metadata-db scenario"
helm status metadata-db >/dev/null 2>&1 || helm install metadata-db scenarios/metadata-db/ \
  --set image.tag='latest@sha256:ef7031853252f16396a2ae2a9f8ec3c8355fa1f2979eadf4b64121a2bc7a1f95'
echo "deploying the vulnerable scenarios manifests"
kubectl kustomize --load-restrictor LoadRestrictionsNone "$HERE/scenarios" | kubectl apply -f -

# Environment information and RBAC: the two Secrets upstream's manifests just created, with the
# player's values; the system-monitor reads its Secret at start, the cache-store its seed.
kubectl -n default create secret generic goatvault --from-literal=k8sgoatvaultkey="$flag_env" \
  --dry-run=client -o yaml | kubectl apply -f -
kubectl -n big-monolith create secret generic vaultapikey --from-literal=k8svaultapikey="$flag_rbac" \
  --dry-run=client -o yaml | kubectl apply -f -
kubectl -n default rollout restart deploy/system-monitor-deployment
kubectl -n secure-middleware rollout restart deploy/cache-store-deployment

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
