# IMMEDIATE FIX: Checkpoints Table Missing Error

**Issue**: Agents failing with `relation 'checkpoints' does not exist`
**Severity**: HIGH - Agents are non-functional
**Estimated Fix Time**: 5-10 minutes

---

## Problem

The `mmjc-agents` service uses LangGraph for AI agent orchestration. LangGraph requires a PostgreSQL table called `checkpoints` to persist agent conversation state. This table doesn't exist in the current database.

**Error Message**:
```
LINE 34: from checkpoints WHERE thread_id = %s AND checkpoint_ns = %...
psycopg2.errors.UndefinedTable: relation 'checkpoints' does not exist
```

---

## Solution

Run the database initialization job to create the missing table.

### Option 1: Kubernetes Job (Recommended)

```bash
# 1. Apply the initialization job
kubectl apply -f kustomize/mmjc-test/jobs/init-database.yaml

# 2. Monitor the job
kubectl get jobs -n mmjc-test -w

# 3. Check logs
kubectl logs -n mmjc-test job/init-mmjc-database -f

# 4. Wait for completion
kubectl wait --for=condition=complete \
  job/init-mmjc-database \
  -n mmjc-test \
  --timeout=300s

# 5. Verify checkpoints table was created
kubectl exec -n mmjc-test deployment/agents-mmjc-test -- \
  psql -h 7bce9b8c-e602-4ae6-8a44-ad87cc332d96.c9v3nahd0oekcvsra2t0.private.databases.appdomain.cloud \
       -p 32337 \
       -U ibm_cloud_971c0f4f_db43_4a27_9d6b_45d548902957 \
       -d mmjc \
       -c "\d checkpoints"

# 6. Restart agents to clear error
kubectl rollout restart deployment/agents-mmjc-test -n mmjc-test

# 7. Verify agents are working
kubectl logs -n mmjc-test -l app=agents-mmjc --tail=50
```

### Option 2: Manual SQL Execution

If the job fails or you prefer manual execution:

```bash
# 1. Get database password from secret
DB_PASSWORD=$(kubectl get secret postgresql-secret-test -n mmjc-test \
  -o jsonpath='{.data.POSTGRESQL_PASSWORD}' | base64 -d)

# 2. Connect to PostgreSQL
kubectl run -it --rm psql-client \
  --image=postgres:16.8 \
  --env="PGPASSWORD=$DB_PASSWORD" \
  --restart=Never \
  -- psql \
    -h 7bce9b8c-e602-4ae6-8a44-ad87cc332d96.c9v3nahd0oekcvsra2t0.private.databases.appdomain.cloud \
    -p 32337 \
    -U ibm_cloud_971c0f4f_db43_4a27_9d6b_45d548902957 \
    -d mmjc

# 3. Once connected, run this SQL:
```

```sql
-- Create checkpoints table
CREATE TABLE IF NOT EXISTS checkpoints (
    thread_id TEXT NOT NULL,
    checkpoint_ns TEXT NOT NULL DEFAULT '',
    checkpoint_id TEXT NOT NULL,
    parent_checkpoint_id TEXT,
    type TEXT,
    checkpoint JSONB NOT NULL,
    metadata JSONB NOT NULL DEFAULT '{}',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (thread_id, checkpoint_ns, checkpoint_id)
);

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_checkpoints_thread_id
    ON checkpoints (thread_id);

CREATE INDEX IF NOT EXISTS idx_checkpoints_parent
    ON checkpoints (parent_checkpoint_id)
    WHERE parent_checkpoint_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_checkpoints_created_at
    ON checkpoints (created_at DESC);

CREATE INDEX IF NOT EXISTS idx_checkpoints_metadata_gin
    ON checkpoints USING gin (metadata);

-- Create trigger function
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_checkpoints_updated_at
    BEFORE UPDATE ON checkpoints
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Verify creation
\d checkpoints
SELECT COUNT(*) FROM checkpoints;
```

---

## Verification

After running the fix, verify the agents are working:

```bash
# Check if checkpoints table exists
kubectl exec -n mmjc-test deployment/agents-mmjc-test -- bash -c '
  export PGPASSWORD=$POSTGRESQL_PASSWORD
  psql -h $POSTGRESQL_HOST \
       -p $POSTGRESQL_PORT \
       -U $POSTGRESQL_USERNAME \
       -d $POSTGRESQL_DATABASE \
       -c "SELECT COUNT(*) as checkpoint_count FROM checkpoints;"
'

# Check agents logs for errors
kubectl logs -n mmjc-test -l app=agents-mmjc --tail=100 | grep -i "checkpoint\|error"

# If no errors, you should see:
# - No "relation 'checkpoints' does not exist" errors
# - Successful checkpoint operations
```

---

## Why This Happened

LangGraph (the framework used by mmjc-agents) stores conversation state in PostgreSQL for:
- Conversation history persistence
- Agent state management
- Multi-turn dialogue tracking
- Checkpoint/restore functionality

The `checkpoints` table should have been created during initial setup, but it was missed. This is a one-time initialization task.

---

## Prevention for AWS Migration

When migrating to AWS:

1. ✅ Use the `database/init-mmjc-database.sql` script during RDS setup
2. ✅ Include database initialization in deployment pipeline
3. ✅ Add to pre-deployment checklist
4. ✅ Document in runbooks

See `SYNC_PLAN_IBM_TO_AWS.md` Section 2.3 for migration details.

---

## Troubleshooting

### Job Fails with "Connection Refused"

The database might not be accessible from the Kubernetes network. Check:

```bash
# Test connectivity
kubectl run -it --rm netcat-test \
  --image=busybox \
  --restart=Never \
  -- nc -zv 7bce9b8c-e602-4ae6-8a44-ad87cc332d96.c9v3nahd0oekcvsra2t0.private.databases.appdomain.cloud 32337
```

### Job Fails with "Permission Denied"

The database user might not have CREATE TABLE permissions:

```bash
# Check user permissions
kubectl exec -n mmjc-test deployment/agents-mmjc-test -- bash -c '
  export PGPASSWORD=$POSTGRESQL_PASSWORD
  psql -h $POSTGRESQL_HOST \
       -p $POSTGRESQL_PORT \
       -U $POSTGRESQL_USERNAME \
       -d $POSTGRESQL_DATABASE \
       -c "\du"
'
```

Contact your DBA to grant CREATE privileges:
```sql
GRANT CREATE ON DATABASE mmjc TO ibm_cloud_971c0f4f_db43_4a27_9d6b_45d548902957;
```

### Agents Still Failing After Fix

1. Verify table exists:
   ```bash
   kubectl exec -n mmjc-test deployment/agents-mmjc-test -- env | grep POSTGRES
   ```

2. Check if agents are using correct database:
   ```bash
   kubectl get deployment agents-mmjc-test -n mmjc-test -o yaml | grep -A 5 POSTGRESQL
   ```

3. Restart agents:
   ```bash
   kubectl rollout restart deployment/agents-mmjc-test -n mmjc-test
   kubectl rollout status deployment/agents-mmjc-test -n mmjc-test
   ```

---

## Additional Resources

- **Full DB Schema**: `database/init-mmjc-database.sql`
- **LangGraph Docs**: https://python.langchain.com/docs/langgraph/
- **AWS Migration Plan**: `SYNC_PLAN_IBM_TO_AWS.md`
- **Gap Analysis**: `GAP_ANALYSIS_REPORT.md`

---

**Last Updated**: 2025-11-02
**Priority**: HIGH
**Status**: Solution Ready
