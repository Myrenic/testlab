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
Weekly backups run Sundays at 3 AM (30-day retention), monthly on the 1st (90-day retention).

```bash
# 1. Bootstrap Flux (steps 1–4 above) — Velero will be deployed automatically

# 2. Wait for Velero to be ready
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=velero \
  -n velero --timeout=300s

# 3. List available backups
velero backup get

# 4. Pick the latest completed backup and restore
velero restore create --from-backup <backup-name> --wait

# 5. Check restore status
velero restore describe <restore-name> --details
```

### Quick one-liner restore (latest weekly)

```bash
velero restore create --from-schedule velero-weekly --wait
```

> This auto-selects the most recent completed backup from the weekly schedule.
