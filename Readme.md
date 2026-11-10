# AKS Private Cluster — Terraform

Terraform project that provisions a **fully private Azure Kubernetes Service (AKS) cluster** backed by an **Azure SQL Database** accessible only through a **Private Endpoint**. All resources live inside a dedicated Virtual Network, ensuring no public exposure for either the cluster API server or the database.

---

## Architecture

```
Azure Resource Group (rg-private-aks)
│
├── Virtual Network  10.0.0.0/16
│   ├── Subnet: snet-aks               10.0.1.0/24   ← AKS nodes
│   └── Subnet: snet-private-endpoint  10.0.2.0/24   ← SQL Private Endpoint
│
├── AKS Cluster (private, System-assigned identity)
│   ├── Node pool: 2 × Standard_D2s_v5
│   ├── Network plugin: Azure CNI Overlay
│   └── Private DNS zone managed by Azure (System)
│
├── Azure SQL Server  (public access disabled, TLS 1.2+)
│   └── Database: appdb  (S0 SKU)
│
└── Private Endpoint  pe-azure-sql
    ├── Linked to snet-private-endpoint
    └── Private DNS zone: privatelink.database.windows.net
        └── VNet link → vnet-private-aks
```

---

## Modules

| Module | Path | Purpose |
|---|---|---|
| `network` | `modules/network` | VNet + AKS subnet + Private Endpoint subnet |
| `aks` | `modules/aks` | Private AKS cluster with Azure CNI Overlay |
| `sql` | `modules/sql` | Azure SQL Server + database (public access off) |
| `sql-private-endpoint` | `modules/sql-private-endpoint` | Private Endpoint, Private DNS zone, and VNet link for SQL |

---

## Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.5.0
- [Azure CLI](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli) installed and authenticated
- An active Azure subscription

---

## Usage

### 1. Authenticate to Azure

```bash
az login
az account set --subscription "<your-subscription-id>"
```

### 2. Configure variables

Copy the example values in `terraform.tfvars` and supply the two required secrets. You can either edit the file directly or pass them on the command line.

> **Never commit `sql_admin_password` or `subscription_id` to source control.**

```hcl
# terraform.tfvars
subscription_id     = "<your-subscription-id>"
sql_admin_password  = "<strong-password>"

# Optional overrides (defaults shown)
location            = "Central India"
resource_group_name = "rg-private-aks"
aks_name            = "aks-private-dev"
sql_database_name   = "appdb"
sql_admin_username  = "sqladminuser"
```

Alternatively, export them as environment variables:

```bash
$env:TF_VAR_subscription_id    = "<your-subscription-id>"
$env:TF_VAR_sql_admin_password = "<strong-password>"
```

### 3. Initialize

```bash
terraform init
```

### 4. Plan

```bash
terraform plan
```

### 5. Apply

```bash
terraform apply
```

---

## Input Variables

| Variable | Type | Default | Description |
|---|---|---|---|
| `subscription_id` | `string` | — | Azure Subscription ID |
| `location` | `string` | `Central India` | Azure region for all resources |
| `resource_group_name` | `string` | `rg-private-aks` | Name of the resource group |
| `aks_name` | `string` | `aks-private-dev` | Name of the AKS cluster |
| `sql_database_name` | `string` | `appdb` | Name of the SQL database |
| `sql_admin_username` | `string` | `sqladminuser` | SQL Server administrator login |
| `sql_admin_password` | `string` *(sensitive)* | — | SQL Server administrator password |

---

## Outputs

| Output | Description |
|---|---|
| `aks_cluster_name` | Name of the provisioned AKS cluster |
| `aks_private_fqdn` | Private FQDN of the AKS API server |
| `sql_server_fqdn` | Fully qualified domain name of the SQL Server |
| `sql_private_endpoint_ip` | Private IP assigned to the SQL Private Endpoint |

---

## Key Design Decisions

- **Private AKS API server** — `private_cluster_enabled = true` with no public FQDN, so the control plane is only reachable from within the VNet or connected networks.
- **Azure CNI Overlay** — Pods get IPs from an overlay range (`192.168.0.0/16`) separate from the VNet, reducing IP exhaustion risk on the node subnet.
- **SQL public access disabled** — `public_network_access_enabled = false` on the SQL Server; connectivity is exclusively through the Private Endpoint.
- **Private DNS auto-registration** — The `privatelink.database.windows.net` zone is linked to the VNet so SQL FQDN resolution works transparently for workloads inside the cluster.
- **System-assigned managed identity** — AKS uses a system-assigned identity, avoiding the need to manage service principal credentials.

---

## CI/CD — GitHub Actions

The workflow at `.github/workflows/terraform.yml` runs automatically whenever a `**.tf`, `**.tfvars`, or the workflow file itself changes.

### Trigger behaviour

| Event | Branch | What runs |
|---|---|---|
| Pull Request | `main` | Init → Fmt check → Validate → Plan → PR comment |
| Push | `main` | Init → Fmt check → Validate → Plan → **Apply** |
| Manual (`workflow_dispatch`) | any | Same as push |

### OIDC — no client secrets

Authentication uses [Workload Identity Federation (OIDC)](https://docs.github.com/en/actions/security-for-github-actions/security-hardening-your-deployments/configuring-openid-connect-in-azure). The workflow requests a short-lived token from GitHub and exchanges it with Azure AD — no `ARM_CLIENT_SECRET` is ever stored.

#### One-time Azure setup

```bash
# 1. Create a service principal (app registration)
az ad app create --display-name "github-aks-terraform"

# 2. Note the appId from the output, then create the SP
APP_ID=$(az ad app list --display-name "github-aks-terraform" --query "[0].appId" -o tsv)
az ad sp create --id $APP_ID

# 3. Add a federated credential for your repo
az ad app federated-credential create \
  --id $APP_ID \
  --parameters '{
    "name": "github-oidc",
    "issuer": "https://token.actions.githubusercontent.com",
    "subject": "repo:<your-org>/<your-repo>:ref:refs/heads/main",
    "audiences": ["api://AzureADTokenExchange"]
  }'

# 4. Assign Contributor role on the subscription
az role assignment create \
  --assignee $APP_ID \
  --role Contributor \
  --scope /subscriptions/<your-subscription-id>
```

For PR plan comments to work, also add a federated credential for pull requests:

```bash
az ad app federated-credential create \
  --id $APP_ID \
  --parameters '{
    "name": "github-oidc-pr",
    "issuer": "https://token.actions.githubusercontent.com",
    "subject": "repo:<your-org>/<your-repo>:pull_request",
    "audiences": ["api://AzureADTokenExchange"]
  }'
```

#### Required GitHub Secrets

Add these in **Settings → Secrets and variables → Actions**:

| Secret | Value |
|---|---|
| `AZURE_CLIENT_ID` | App Registration (client) ID |
| `AZURE_TENANT_ID` | Azure AD Tenant ID |
| `AZURE_SUBSCRIPTION_ID` | Azure Subscription ID |
| `SQL_ADMIN_PASSWORD` | SQL Server admin password |

---

## Cleanup

```bash
terraform destroy
```

---

## Provider Versions

| Provider | Version |
|---|---|
| `hashicorp/azurerm` | `~> 4.0` (locked at 4.81.0) |
| `hashicorp/random` | `~> 3.6` (locked at 3.9.1) |
