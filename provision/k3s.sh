#!/bin/sh
# Installs a single-node Kubernetes cluster (k3s) and Helm, both pinned by version and SHA-256.
# Upstream runs Kubernetes Goat on kind (a cluster in Docker); here the cluster is k3s on the VM
# itself, which needs no Docker. Traefik and the service load balancer are left out (kind has
# neither and no scenario uses them). The kubeconfig is readable by every user of the VM, so the
# player's shell has kubectl on the cluster like upstream's setup.
set -eu
K3S_VERSION=v1.36.5+k3s1
K3S_SHA256=d73847bcd3c5fccef0115b372e2f9a91f3032dc84bbf71518a4617565294d313
K3S_INSTALL_SHA256=46177d4c99440b4c0311b67233823a8e8a2fc09693f6c89af1a7161e152fbfad
HELM_VERSION=v3.22.0
HELM_SHA256=1e4ab49e429626cf6c6958d914248b78c9730803c2751b87627e171dc800e7bb
tag=$(printf %s "$K3S_VERSION" | sed 's/+/%2B/')

command -v curl >/dev/null || { apt-get update -q && DEBIAN_FRONTEND=noninteractive apt-get install -yq curl; }

if [ ! -x /usr/local/bin/k3s ]; then
  curl -fsSL -o /usr/local/bin/k3s "https://github.com/k3s-io/k3s/releases/download/$tag/k3s"
  echo "$K3S_SHA256  /usr/local/bin/k3s" | sha256sum -c -
  chmod 755 /usr/local/bin/k3s
fi
if ! systemctl is-active -q k3s; then
  curl -fsSL -o /tmp/k3s-install.sh "https://raw.githubusercontent.com/k3s-io/k3s/$tag/install.sh"
  echo "$K3S_INSTALL_SHA256  /tmp/k3s-install.sh" | sha256sum -c -
  INSTALL_K3S_SKIP_DOWNLOAD=true INSTALL_K3S_VERSION="$K3S_VERSION" \
    INSTALL_K3S_EXEC="server --disable traefik --disable servicelb --write-kubeconfig-mode 644" \
    sh /tmp/k3s-install.sh
  rm -f /tmp/k3s-install.sh
fi

if ! command -v helm >/dev/null; then
  curl -fsSL -o /tmp/helm.tgz "https://get.helm.sh/helm-$HELM_VERSION-linux-amd64.tar.gz"
  echo "$HELM_SHA256  /tmp/helm.tgz" | sha256sum -c -
  tar -xzf /tmp/helm.tgz -C /tmp linux-amd64/helm
  install -m 755 /tmp/linux-amd64/helm /usr/local/bin/helm
  rm -rf /tmp/helm.tgz /tmp/linux-amd64
fi

echo 'export KUBECONFIG=/etc/rancher/k3s/k3s.yaml' > /etc/profile.d/kubeconfig.sh
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
i=0
until kubectl get nodes 2>/dev/null | grep -q ' Ready'; do
  i=$((i + 1)); [ $i -lt 90 ] || { echo "k3s node never became Ready"; exit 1; }; sleep 2
done
# k3s creates its add-ons (CoreDNS first) a little after the node is Ready.
i=0
until kubectl -n kube-system get deploy/coredns >/dev/null 2>&1; do
  i=$((i + 1)); [ $i -lt 90 ] || { echo "CoreDNS never deployed"; exit 1; }; sleep 2
done
kubectl -n kube-system rollout status deploy/coredns --timeout=300s
echo "k3s $K3S_VERSION and Helm $HELM_VERSION ready"
