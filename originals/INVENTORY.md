# Complete Kubernetes Resources Extraction - Inventory

This directory contains the complete extraction of all Kubernetes resources from three namespaces.

## Extraction Date
Generated: $(date)

## Namespaces Extracted
- airflow-test
- mmjc-test
- mmjc-dev

---

## airflow-test

### Summary
- **Deployments**: 4
- **StatefulSets**: 2
- **Services**: 4
- **ConfigMaps**: 4
- **Secrets**: 19
- **PersistentVolumeClaims**: 3
- **ServiceAccounts**: 9
- **Roles**: 2
- **RoleBindings**: 2

### Deployments
$(ls originals/airflow-test/deployments/ 2>/dev/null | sed 's/.yaml$//' | sed 's/^/- /' || echo "None")

### StatefulSets
$(ls originals/airflow-test/statefulsets/ 2>/dev/null | sed 's/.yaml$//' | sed 's/^/- /' || echo "None")

### Services
$(ls originals/airflow-test/services/ 2>/dev/null | sed 's/.yaml$//' | sed 's/^/- /' || echo "None")

### Secrets (Contains sensitive data)
$(ls originals/airflow-test/secrets/ 2>/dev/null | sed 's/.yaml$//' | sed 's/^/- /' || echo "None")

---

## mmjc-test

### Summary
- **Deployments**: 13
- **StatefulSets**: 6
- **Services**: 25
- **ConfigMaps**: 17
- **Secrets**: 24
- **PersistentVolumeClaims**: 17
- **Ingresses**: 2
- **NetworkPolicies**: 1
- **ServiceAccounts**: 5
- **Roles**: 1
- **RoleBindings**: 1
- **HorizontalPodAutoscalers**: 3

### Deployments
$(ls originals/mmjc-test/deployments/ 2>/dev/null | sed 's/.yaml$//' | sed 's/^/- /' || echo "None")

### StatefulSets
$(ls originals/mmjc-test/statefulsets/ 2>/dev/null | sed 's/.yaml$//' | sed 's/^/- /' || echo "None")

### Secrets (Contains sensitive data)
$(ls originals/mmjc-test/secrets/ 2>/dev/null | sed 's/.yaml$//' | sed 's/^/- /' || echo "None")

---

## mmjc-dev

### Summary
- **Deployments**: 23
- **StatefulSets**: 6
- **Services**: 42
- **ConfigMaps**: 29
- **Secrets**: 37
- **PersistentVolumeClaims**: 24
- **Ingresses**: 3
- **NetworkPolicies**: 1
- **ServiceAccounts**: 7
- **Roles**: 2
- **RoleBindings**: 2
- **HorizontalPodAutoscalers**: 5
- **Jobs**: 1

### Deployments
$(ls originals/mmjc-dev/deployments/ 2>/dev/null | sed 's/.yaml$//' | sed 's/^/- /' || echo "None")

### StatefulSets
$(ls originals/mmjc-dev/statefulsets/ 2>/dev/null | sed 's/.yaml$//' | sed 's/^/- /' || echo "None")

### Secrets (Contains sensitive data)
$(ls originals/mmjc-dev/secrets/ 2>/dev/null | sed 's/.yaml$//' | sed 's/^/- /' || echo "None")

---

## Security Notice

⚠️ **WARNING: Secrets contain sensitive data!**

The extracted secrets contain actual credentials and sensitive information. Do NOT commit these to version control.

### Recommended Actions:
1. Use the `template-secrets.sh` script to create templated versions
2. Store actual secrets in a secure vault (HashiCorp Vault, Sealed Secrets, etc.)
3. Add `originals/*/secrets/` to `.gitignore`
4. Use environment-specific secret management for deployment

### Secret Types Found:
- Database connection strings
- API keys and tokens
- TLS certificates
- Docker registry credentials
- JWT secrets
- Fernet keys

---

## Directory Structure

```
originals/
├── airflow-test/
│   ├── deployments/
│   ├── statefulsets/
│   ├── services/
│   ├── configmaps/
│   ├── secrets/          ⚠️ SENSITIVE
│   ├── pvcs/
│   ├── serviceaccounts/
│   ├── roles/
│   └── rolebindings/
├── mmjc-test/
│   ├── deployments/
│   ├── statefulsets/
│   ├── services/
│   ├── configmaps/
│   ├── secrets/          ⚠️ SENSITIVE
│   ├── pvcs/
│   ├── ingresses/
│   ├── networkpolicies/
│   ├── serviceaccounts/
│   ├── roles/
│   ├── rolebindings/
│   └── hpas/
├── mmjc-dev/
│   ├── deployments/
│   ├── statefulsets/
│   ├── services/
│   ├── configmaps/
│   ├── secrets/          ⚠️ SENSITIVE
│   ├── pvcs/
│   ├── ingresses/
│   ├── networkpolicies/
│   ├── serviceaccounts/
│   ├── roles/
│   ├── rolebindings/
│   ├── hpas/
│   └── jobs/
├── INVENTORY.md
├── README.md
└── template-secrets.sh
```

## Usage

### View a specific resource
```bash
cat originals/mmjc-test/deployments/agents-mmjc-test.yaml
```

### Count all resources
```bash
find originals -name "*.yaml" | wc -l
```

### List all secrets
```bash
find originals -path "*/secrets/*.yaml" -exec basename {} .yaml \;
```

### Template secrets for version control
```bash
./originals/template-secrets.sh
```
