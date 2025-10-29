# 🔧 Setup Namespace: br-ibm-images

**Objective**: Create and configure `br-ibm-images` namespace in IBM Container Registry (Brazil region)

---

## ⚠️ Prerequisites

You need **Manager** access to create namespaces in IBM Cloud Container Registry.

### Check Your Access

```bash
# Check current access
ibmcloud cr region-set br.icr.io
ibmcloud cr namespace-list

# If you see "unauthorized" error, you need Manager access
```

---

## 🎯 Option 1: You Have Manager Access

```bash
# 1. Set region to Brazil
ibmcloud cr region-set br.icr.io

# 2. Create namespace
ibmcloud cr namespace-add br-ibm-images

# 3. Verify
ibmcloud cr namespace-list | grep br-ibm-images
```

**Expected Output**:
```
Incluindo o namespace 'br-ibm-images'...
✅ Namespace adicionado
```

---

## 🎯 Option 2: Request Access from Admin

If you don't have Manager access, ask your IBM Cloud admin to:

### For Admin to Run:

```bash
# 1. Login as admin
ibmcloud login --sso

# 2. Target the account
ibmcloud target -c 16bed81d1ae040c5bc9d55b6507ebdda -g mjc

# 3. Set Brazil region
ibmcloud cr region-set br.icr.io

# 4. Create namespace
ibmcloud cr namespace-add br-ibm-images

# 5. Grant access to user
ibmcloud iam user-policy-create gregoriomomm@br.ibm.com \
    --roles Manager \
    --service-name container-registry \
    --resource-type namespace \
    --resource br-ibm-images
```

---

## 🎯 Option 3: Use Existing Namespace

If you can't create `br-ibm-images`, use an existing namespace you have access to:

```bash
# 1. List namespaces you have access to
ibmcloud cr region-set br.icr.io
ibmcloud cr namespace-list

# 2. Pick one (example: if you have access to 'my-namespace')
export TARGET_NAMESPACE=my-namespace
export TARGET_REGISTRY=br.icr.io/my-namespace

# 3. Update config
vim config/migration.env
# Change:
# TARGET_NAMESPACE=my-namespace
# TARGET_REGISTRY=br.icr.io/my-namespace
```

---

## ✅ Verify Namespace Access

```bash
# 1. Set region
ibmcloud cr region-set br.icr.io

# 2. Login to registry
ibmcloud cr login

# 3. Try to list images (should work even if empty)
ibmcloud cr images --restrict br-ibm-images

# Expected output (if empty):
# Listando imagens...
#
# Repositório   Tag   Digest   Namespace   Criado   Tamanho   Status
# (empty)
# OK

# If you see error, you don't have access yet
```

---

## 🔐 Required IAM Permissions

To use the namespace, you need:

| Role | Permission | Required For |
|------|------------|--------------|
| **Reader** | View images | Pulling images |
| **Writer** | Push images | Migration (push) |
| **Manager** | Create namespace | Creating br-ibm-images |

### Check Your Current Role

```bash
# List your policies
ibmcloud iam user-policies gregoriomomm@br.ibm.com | grep container-registry

# Or check in console:
# https://cloud.ibm.com/iam/users
```

---

## 🚀 After Namespace is Ready

Once namespace is created and you have access:

```bash
# 1. Verify access
ibmcloud cr region-set br.icr.io
ibmcloud cr namespace-list | grep br-ibm-images

# 2. Set config
cat > config/migration.env << EOF
TARGET_ICR_REGION=br.icr.io
TARGET_NAMESPACE=br-ibm-images
TARGET_REGISTRY=br.icr.io/br-ibm-images
EOF

# 3. Run migration
./scripts/migrate-images-manual.sh
```

---

## 💡 Notes

1. **Namespace is Global per Region**: Once created, all users with access can use it
2. **Brazil Region**: `br.icr.io` is hosted in São Paulo
3. **Cost**: Free tier includes 500MB storage, then charged per GB/month
4. **Quota**: Check quota with `ibmcloud cr quota`

---

## 🆘 Troubleshooting

### Error: "Você não tem autorização"

**Solution**: You need Manager access. Ask admin or use Option 3 (existing namespace)

### Error: "Namespace already exists"

**Solution**: Good! Namespace exists. Just verify you have Writer access:
```bash
ibmcloud cr images --restrict br-ibm-images
```

### Error: "No namespaces found"

**Solution**: Switch to Brazil region first:
```bash
ibmcloud cr region-set br.icr.io
ibmcloud cr namespace-list
```

---

**Next**: After namespace is ready, see `START_HERE.md` to run migration
