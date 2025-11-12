# Airflow Test Secrets

## Required Secrets

### Database Connection
- `airflow-postgres-connection-test`: PostgreSQL connection string  
  - **IMPORTANT**: Must use `postgresql://` scheme (not `postgres://`)
  - Format: `postgresql://user:password@host:port/database?params`

### Redis Connection  
- `airflow-redis-connection-test`: Redis connection string for Celery broker

### Airflow Keys
- `airflow-test-fernet-key`: Fernet key for encrypting passwords in metadata DB
- `airflow-test-jwt-secret`: JWT secret for API authentication
- `airflow-test-webserver-secret-key`: Flask secret key for webserver

### Certificates
- `airflow-postgres-cert-test`: PostgreSQL SSL certificate (root.crt)

### Image Registry
- `all-icr-io-mmjc`: Docker config for pulling from ICR

### Object Storage (optional, for logs)
- `cos-mmjc-airflow-secret`: IBM Cloud Object Storage credentials
- `mmjc-cos-test-secrets`: Additional COS secrets

## Usage

See `secrets-template.yaml` for the structure. Copy and fill in your actual base64-encoded values.

To encode a value:
```bash
echo -n "your-value" | base64
```

To decode a value:
```bash
echo "base64-value" | base64 -d
```
