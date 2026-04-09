# Testlab Cluster

Kubernetes homelab managed by [Flux CD](https://fluxcd.io/) with [SOPS](https://github.com/getsops/sops) + [age](https://github.com/FiloSottile/age) encryption.

## Bootstrap

```bash
# 1. Install Flux
kubectl apply -f https://github.com/fluxcd/flux2/releases/download/v2.7.5/install.yaml

# 2. Create the SOPS age secret (for decrypting secrets in-repo)
cat age.agekey | kubectl create secret generic sops-age \
  --namespace=flux-system --from-file=age.agekey=/dev/stdin

# 3. Apply the Git repo credentials secret
sops -d ./kubernetes/apps/flux-system/flux-instance/flux-system-secret.sops.yaml \
  | kubectl apply -f -

# 4. Apply the Flux sync configuration
kustomize build ./kubernetes/apps/flux-system/flux-instance | kubectl apply -f -

# 5. Wait — Flux reconciles everything else automatically
flux get kustomizations --watch
```

## Restore from Backup

Velero backs up to Azure Blob Storage (`velero76b1f66a064d` / container `velero`).
Daily backups at 3 AM (7-day retention), monthly on the 1st (60-day retention).

### Restore an individual app (e.g. aiostreams)

This is the reliable procedure for restoring a single app's PVC data. Velero uses
kopia (pod volume backup) and **requires the pod to start with a `restore-wait` init
container** that it injects at restore time. If the Deployment creates a pod first,
the kopia restore will stall. Follow these steps to avoid that.

```bash
APP=aiostreams
NS=services

# 1. Suspend Flux so it doesn't fight the restore
flux suspend kustomization $APP -n flux-system
flux suspend helmrelease $APP -n $NS

# 2. Scale down and delete the Deployment entirely (prevents Deployment from
#    recreating a pod before Velero can inject the restore-wait init container)
kubectl scale deployment $APP -n $NS --replicas=0
kubectl delete deployment $APP -n $NS

# 3. Delete the PVC so Velero recreates it fresh
kubectl delete pvc $APP -n $NS

# 4. Find the backup to restore from
velero backup get | grep $APP

# 5. Restart the Velero pod if the BackupStorageLocation shows "Unavailable"
#    (an I/O error writing credentials to /tmp is cleared by a pod restart)
kubectl get backupstoragelocation -n velero
# If PHASE != Available:
kubectl rollout restart deployment/velero -n velero
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=velero \
  -n velero --timeout=120s

# 6. Run the restore — do NOT use --existing-resource-policy update, as that
#    causes Velero to update the existing Deployment instead of creating the pod
#    directly (which breaks the restore-wait init container injection)
velero restore create --from-backup <backup-name> --wait

# 7. Monitor: Velero creates the PVC, then a pod with the restore-wait init
#    container, the node-agent restores kopia data, then the app starts
kubectl get pods -n $NS -w

# 8. Resume Flux once the pod is Running
flux resume kustomization $APP -n flux-system
flux resume helmrelease $APP -n $NS
```

### Troubleshooting restore issues

**Restore stuck in `New` phase — velero pod restart required**

If a restore stays in `New` for more than ~2 minutes with no activity in
`kubectl logs -n velero deployment/velero`, restart the velero pod:

```bash
kubectl rollout restart deployment/velero -n velero
```

The new pod picks up in-flight `New` restores immediately.

**BSL shows `Unavailable` (`input/output error` writing credentials)**

The Azure plugin writes a temp credential file to `/tmp` inside the velero container.
A node restart or stale pod can leave the container in a bad state. Restart the pod:

```bash
kubectl rollout restart deployment/velero -n velero
kubectl get backupstoragelocation -n velero   # wait for Available
```

**Kopia PodVolumeRestore stuck / `shouldProcess` returns false**

Velero's advanced kopia controller skips a PVR if the target pod is not running the
`restore-wait` init container. This happens when:
- `--existing-resource-policy update` was used (Deployment updates instead of Velero creating the pod)
- The pod was force-deleted before the restore completed

**Fix:** delete the restore, delete the Deployment and PVC, and re-run without
`--existing-resource-policy update` (step 6 above).

### Full-cluster restore (disaster recovery)

```bash
# 1. Bootstrap Flux (steps 1–4 in Bootstrap section above)
# 2. Wait for Velero
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=velero \
  -n velero --timeout=300s
# 3. List backups and pick one
velero backup get
# 4. Restore
velero restore create --from-backup <backup-name> --wait
velero restore describe <restore-name> --details
```
