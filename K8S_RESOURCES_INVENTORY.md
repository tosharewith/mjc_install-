# Kubernetes Resources Inventory
## Cluster Context: mjc-cluster/d091ramd0q70n6ktn9v0

---

## Namespace: airflow-test

### Deployments (4)
- airflow-test-api-server
- airflow-test-dag-processor
- airflow-test-scheduler
- airflow-test-statsd

### StatefulSets (2)
- airflow-test-triggerer
- airflow-test-worker

### Services (4)
- airflow-test-api-server (ClusterIP)
- airflow-test-statsd (ClusterIP)
- airflow-test-triggerer (ClusterIP - Headless)
- airflow-test-worker (ClusterIP - Headless)

### ConfigMaps (4)
- airflow-test-config
- airflow-test-statsd
- istio-ca-root-cert
- kube-root-ca.crt

### Secrets (18)
- airflow-postgres-cert-test
- airflow-postgres-connection-test
- airflow-redis-connection-test
- airflow-test-fernet-key
- airflow-test-jwt-secret
- airflow-test-webserver-secret-key
- all-icr-io-mmjc
- cos-mmjc-airflow-secret
- mmjc-cos-test-secrets
- sh.helm.release.v1.airflow-test.v1-v10 (Helm releases)

### PersistentVolumeClaims (3)
- logs-airflow-test-triggerer-0
- logs-airflow-test-worker-0
- mmjc-airflow-dags-test

### Images Used
- icr.io/mjc-cr/mmjc-airflow-service:latest
- quay.io/prometheus/statsd-exporter:v0.28.0

---

## Namespace: mmjc-test

### Deployments (12)
- agents-mmjc-test
- frontend-mmjc-test
- mcp-gateway-test
- mcp-git-s3-server
- mcp-milvus-db-test
- mermaid-validator-api
- milvus-mmjc-test-datanode
- milvus-mmjc-test-indexnode
- milvus-mmjc-test-mixcoord
- milvus-mmjc-test-proxy
- milvus-mmjc-test-querynode
- my-attu
- po-mmjc-test

### StatefulSets (10)
- mcp-arc-s3-server
- milvus-mmjc-test-etcd
- milvus-mmjc-test-kafka
- milvus-mmjc-test-minio
- milvus-mmjc-test-zookeeper
- redis-cluster-test

### Services (23)
- agents-mmjc-test (ClusterIP)
- frontend-mmjc-test (ClusterIP)
- mcp-arc-s3-service (ClusterIP)
- mcp-gateway-test (ClusterIP)
- mcp-git-s3-server (ClusterIP)
- mcp-git-s3-server-headless (ClusterIP - Headless)
- mcp-git-s3-server-lb (LoadBalancer)
- mcp-milvus-db-test (ClusterIP)
- mermaid-validator-api (ClusterIP)
- milvus-mmjc-test (ClusterIP)
- milvus-mmjc-test-datanode (ClusterIP - Headless)
- milvus-mmjc-test-etcd (ClusterIP)
- milvus-mmjc-test-etcd-headless (ClusterIP - Headless)
- milvus-mmjc-test-indexnode (ClusterIP - Headless)
- milvus-mmjc-test-kafka (ClusterIP)
- milvus-mmjc-test-kafka-headless (ClusterIP - Headless)
- milvus-mmjc-test-minio (ClusterIP)
- milvus-mmjc-test-minio-svc (ClusterIP - Headless)
- milvus-mmjc-test-mixcoord (ClusterIP)
- milvus-mmjc-test-querynode (ClusterIP - Headless)
- milvus-mmjc-test-zookeeper (ClusterIP)
- milvus-mmjc-test-zookeeper-headless (ClusterIP - Headless)
- my-attu-svc (ClusterIP)
- po-mmjc-test (ClusterIP)
- redis-service-test (ClusterIP)

### ConfigMaps (17)
- istio-ca-root-cert
- kube-root-ca.crt
- lang-detect-config
- mcp-arc-s3-config
- mcp-arc-s3-custom-result-config
- mcp-arc-s3-ssh-config
- mcp-git-s3-config
- mcp-git-s3-jvm-config
- mcp-git-s3-monitoring
- mcp-git-s3-tls-config
- mermaid-syntax-rules
- mermaid-validator-api-config
- milvus-mmjc-test
- milvus-mmjc-test-kafka-scripts
- milvus-mmjc-test-minio
- milvus-mmjc-test-zookeeper-scripts
- redis-cluster-configmap-test

### Secrets (24)
- airflow-secret-test
- all-icr-io-mmjc
- api-auth-tokens-agents
- api-key-po
- azure-openai-api-key-agents
- azure-openai-deployment-name-agents
- basic-auth-pass-bff
- db-password-po
- git-password-secret-agents
- github-app-secrets
- ibmid-jwt-secret-bff
- jwt-secret-bff
- mcp-gateway-jwt
- mcp-gateway-jwt-token
- mcp-gateway-pwd
- mcp-milvus-db-model-api-key
- mcp-milvus-db-password
- mcp-tls-cert
- milvus-mmjc-test-minio
- openai-api-key-agents
- postgresql-secret-test
- s3-access-key-tools
- s3-secret-key-tools
- sh.helm.release.v1.milvus-mmjc-test.v1

### PersistentVolumeClaims (17)
- data-milvus-mmjc-test-etcd-0
- data-milvus-mmjc-test-etcd-1
- data-milvus-mmjc-test-etcd-2
- data-milvus-mmjc-test-kafka-0
- data-milvus-mmjc-test-kafka-1
- data-milvus-mmjc-test-kafka-2
- data-milvus-mmjc-test-zookeeper-0
- data-milvus-mmjc-test-zookeeper-1
- data-milvus-mmjc-test-zookeeper-2
- data-redis-cluster-test-0
- export-milvus-mmjc-test-minio-0
- export-milvus-mmjc-test-minio-1
- export-milvus-mmjc-test-minio-2
- export-milvus-mmjc-test-minio-3
- run-folder-mcp-arc-s3-server-0
- run-folder-mcp-arc-s3-server-1
- run-folder-mcp-arc-s3-server-2

### Ingresses (2)
- lang-detect
- mermaid-validator-api

### Images Used
- icr.io/mjc-cr/mmjc-agents:0.0.2
- icr.io/mjc-cr/mmjc-frontend:0.0.2
- icr.io/mjc-cr/mmjc-po:0.0.2
- icr.io/mjc-cr/go-mcp-git-s3:1.0.31
- icr.io/mjc-cr/mcp-milvus-db:0.0.2
- icr.io/mjc-cr/mjc-mermaid-validator:1.0.17-llm-ready-amd64
- ghcr.io/ibm/mcp-context-forge:0.6.0
- milvusdb/milvus:v2.5.15
- zilliz/attu:v2.5.6

---

## Summary
- **Total Namespaces**: 2
- **Total Deployments**: 16
- **Total StatefulSets**: 12
- **Total Services**: 27
- **Total ConfigMaps**: 21
- **Total Secrets**: 42
- **Total PVCs**: 20
- **Total Ingresses**: 2

## Image Registries Identified
1. icr.io/mjc-cr/* (IBM Cloud Registry - Custom)
2. quay.io/prometheus/*
3. ghcr.io/ibm/*
4. milvusdb/*
5. zilliz/*
