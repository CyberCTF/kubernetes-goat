# Kubernetes Goat

[Kubernetes Goat](https://github.com/madhuakula/kubernetes-goat) by Madhu Akula: an
intentionally vulnerable Kubernetes cluster for learning Kubernetes security, with about twenty
scenarios. This repository runs it with [Isoloom](https://www.isoloom.com):
[`isoloom.yml`](isoloom.yml) describes one VM that is the cluster. It installs single-node
[k3s](https://k3s.io) ([`provision/k3s.sh`](provision/k3s.sh)) and deploys upstream's own
manifests and Helm chart, vendored in [`kubernetes-goat/`](kubernetes-goat), the way upstream's
setup and access scripts do ([`provision/goat.sh`](provision/goat.sh)).

| Machine | Services |
| --- | --- |
| goat | SSH 22 (kubectl on the cluster), build-code 1230, health-check 1231, internal-proxy 1232, system-monitor 1233, portal 1234, poor-registry 1235, hunger-check 1236 |

## Run it

```bash
isoloom run vagrant
isoloom test vagrant
```

Then open `http://10.60.120.10:1234/` from a machine of the lab network for the portal. The cluster
is part of the lab: several scenarios start from `kubectl`, available in the VM's shell
(`isoloom connect vagrant goat`). The first start takes about 15 minutes (k3s, then a dozen
scenario images). 4 GB of memory for the machine, plus 1 GB for the controller that runs the
checks.

Differences from upstream's own setup:

- Upstream runs on kind (a cluster in Docker); here the cluster is k3s on the VM, v1.36.5, pinned
  by checksum with Helm v3.22.0. The health-check scenario mounts the container runtime socket at
  kind's path, `/run/containerd/containerd.sock`; a symlink to k3s's socket stands there.
- Upstream's manifests use untagged images (`latest`); here each is pinned to the digest `latest`
  had at release v2.3.0 ([`provision/scenarios/kustomization.yaml`](provision/scenarios/kustomization.yaml)).
- `access-kubernetes-goat.sh` port-forwards the scenarios from the user's shell; here the same
  forwards run as a systemd service on the VM, so ports 1230 to 1236 answer on its address.
- One self-referencing symlink of the source is left out (see [UPSTREAM.md](UPSTREAM.md)).

Lab guide: the [Kubernetes Goat guide](https://madhuakula.com/kubernetes-goat/) (also in
[`kubernetes-goat/guide/`](kubernetes-goat/guide)). Upstream version and commit:
[UPSTREAM.md](UPSTREAM.md).

## Licence

MIT, as Kubernetes Goat ([LICENSE](LICENSE)), copyright Madhu Akula. The cluster runs k3s
(Apache-2.0) and images published by upstream on Docker Hub. This cluster is deliberately
vulnerable (privileged pods, host mounts, cluster-admin service accounts): keep it isolated.
