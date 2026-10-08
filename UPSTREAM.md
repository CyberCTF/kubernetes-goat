# Upstream

| Dir | Repository | Version | Commit | Licence |
| --- | --- | --- | --- | --- |
| kubernetes-goat | https://github.com/madhuakula/kubernetes-goat | v2.3.0 | aa72b6173320ebe23fe7b5395d026dae3336e399 | MIT |

`kubernetes-goat/` is that release without its Git history, unchanged but for one entry: the
symlink `infrastructure/metadata-db/metadata/latest/latest`, which points at itself (a loop with
no content), is left out, because copying the project into the VM fails on it (`Too many levels
of symbolic links`). Its scenario images are
pulled from Docker Hub (`madhuakula/k8s-goat-*`), pinned to the digests `latest` had at this
release (`provision/scenarios/kustomization.yaml` and the metadata-db tag in `provision/goat.sh`).
To update, replace `kubernetes-goat/` with a newer release, then this table and the digests.
