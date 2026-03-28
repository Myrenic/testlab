# Authentication Setup - Required SOPS Variables

The following variables must be added to `kubernetes/apps/common/cluster-secrets.sops.yaml`
before deploying the authentication stack. Use `sops` with the Age key to edit the file:

```bash
sops kubernetes/apps/common/cluster-secrets.sops.yaml
```

## Required Variables

### Authentik Core

| Variable | Description | Example |
|---|---|---|
| `AUTHENTIK_SECRET_KEY` | Random secret key for Authentik (min 50 chars). Generate with `openssl rand -hex 50` | `a1b2c3...` |
| `AUTHENTIK_BOOTSTRAP_PASSWORD` | Initial admin password for Authentik `akadmin` user | `your-strong-password` |
| `AUTHENTIK_BOOTSTRAP_TOKEN` | Initial API token for Authentik. Generate with `openssl rand -hex 32` | `d4e5f6...` |

### Azure Entra ID (for SSO federation)

| Variable | Description | Where to find |
|---|---|---|
| `AZURE_CLIENT_ID` | Application (client) ID from Azure App Registration | Azure Portal → App Registrations → Overview |
| `AZURE_CLIENT_SECRET` | Client secret value from Azure App Registration | Azure Portal → App Registrations → Certificates & secrets |
| `AZURE_TENANT_ID` | Directory (tenant) ID | Azure Portal → Azure Active Directory → Overview |

### OIDC Provider (for Envoy Gateway integration)

| Variable | Description | Example |
|---|---|---|
| `AUTHENTIK_OIDC_CLIENT_ID` | OIDC client ID for Envoy Gateway. Generate a unique identifier | `envoy-gateway` |
| `AUTHENTIK_OIDC_CLIENT_SECRET` | OIDC client secret for Envoy Gateway. Generate with `openssl rand -hex 32` | `f7g8h9...` |

## Azure Entra ID App Registration Setup

1. Go to **Azure Portal** → **Azure Active Directory** → **App Registrations** → **New Registration**
2. Set the name (e.g., `Authentik SSO`)
3. Set **Redirect URI** to: `https://auth.<your-domain>/source/oauth/callback/azure-entra-id/`
4. Under **Certificates & secrets**, create a new client secret
5. Under **API permissions**, ensure `openid`, `email`, and `profile` scopes are granted
6. Note the **Application (client) ID** and **Directory (tenant) ID**

## Architecture Overview

```
Internet → Cloudflare Tunnel → Envoy Gateway
                                    │
                    ┌───────────────┼───────────────┐
                    │               │               │
              flux.domain     longhorn.domain   auth.domain
              (OIDC protected)  (OIDC protected)  (Authentik UI)
                    │               │               │
                    └───────┬───────┘               │
                            │                       │
                    SecurityPolicy (OIDC)     No auth (IdP)
                            │                       │
                            └───────────────────────┘
                                        │
                                   Authentik
                                   (OIDC Provider)
                                        │
                                   Azure Entra ID
                                   (Federation Source)
```

Protected routes (`flux.*` and `longhorn.*`) use Envoy Gateway's OIDC SecurityPolicy
which redirects unauthenticated users to Authentik. Authentik federates with Azure
Entra ID for single sign-on.
