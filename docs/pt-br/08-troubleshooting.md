# Troubleshooting - Resolução de Problemas

Este documento lista problemas comuns e suas soluções durante e após a migração.

## Problemas Gerais

### Problema: kubectl não conecta ao cluster EKS

**Sintomas**:
```
Unable to connect to the server: dial tcp: lookup xxx on xxx:53: no such host
```

**Solução**:
```bash
# Atualizar kubeconfig
aws eks update-kubeconfig --name SEU_CLUSTER_EKS --region us-east-1

# Verificar contexto
kubectl config current-context

# Testar conexão
kubectl cluster-info
```

### Problema: Imagens não são encontradas

**Sintomas**:
```
Failed to pull image "icr.io/mjc-cr/mmjc-airflow-service:latest": rpc error: code = Unknown desc = Error response from daemon: pull access denied
```

**Solução**:
```bash
# Verificar se imagens foram migradas
docker images | grep airflow

# Se não, migrar:
./scripts/migrate-container-images.sh

# Verificar referências no kustomization.yaml
grep "newName:" kustomize/*/kustomization.yaml

# Se usar ECR, fazer login
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin ${AWS_ACCOUNT_ID}.dkr.ecr.us-east-1.amazonaws.com
```

## Problemas com Airflow

### Problema: Scheduler não inicia

**Sintomas**:
```
CrashLoopBackOff
airflow.exceptions.AirflowException: Can't connect to database
```

**Solução**:
```bash
# Verificar logs
kubectl logs -n airflow-test -l component=scheduler --tail=100

# Testar conexão com RDS
kubectl run -it --rm debug --image=postgres:15 --restart=Never -n airflow-test -- \
  psql -h RDS_ENDPOINT -U airflow_admin -d airflow

# Verificar secret
kubectl get secret airflow-postgresql -n airflow-test -o yaml

# Verificar security groups do RDS
aws rds describe-db-instances --db-instance-identifier itau-airflow-postgres
```

### Problema: Workers não executam tasks

**Sintomas**:
```
Tasks ficam em "queued" indefinidamente
```

**Solução**:
```bash
# Verificar logs do worker
kubectl logs -n airflow-test -l component=worker --tail=100

# Verificar conexão com Redis
kubectl exec -it -n airflow-test deployment/airflow-test-worker-0 -- \
  redis-cli -h REDIS_ENDPOINT ping

# Verificar se worker está registrado
kubectl exec -it -n airflow-test deployment/airflow-test-scheduler -- \
  airflow celery inspect active

# Escalar workers se necessário
kubectl scale statefulset airflow-test-worker -n airflow-test --replicas=2
```

### Problema: DAGs não aparecem

**Sintomas**:
```
UI mostra "No DAGs found"
```

**Solução**:
```bash
# Verificar DAGS_FOLDER
kubectl exec -it -n airflow-test deployment/airflow-test-scheduler -- \
  airflow config get-value core dags_folder

# Se usar S3, verificar acesso
kubectl exec -it -n airflow-test deployment/airflow-test-scheduler -- \
  aws s3 ls s3://BUCKET_DAGS/dags/

# Verificar permissões IAM/IRSA
kubectl describe pod -n airflow-test -l component=scheduler | grep -A 5 "AWS"

# Forçar refresh de DAGs
kubectl exec -it -n airflow-test deployment/airflow-test-scheduler -- \
  airflow dags reserialize
```

### Problema: Logs não aparecem

**Sintomas**:
```
"Log file does not exist" na UI
```

**Solução**:
```bash
# Verificar configuração de remote logging
kubectl exec -it -n airflow-test deployment/airflow-test-scheduler -- \
  airflow config get-value logging remote_logging

# Verificar REMOTE_BASE_LOG_FOLDER
kubectl exec -it -n airflow-test deployment/airflow-test-scheduler -- \
  airflow config get-value logging remote_base_log_folder

# Verificar acesso ao S3
kubectl exec -it -n airflow-test deployment/airflow-test-scheduler -- \
  aws s3 ls s3://BUCKET_LOGS/logs/

# Testar escrita
kubectl exec -it -n airflow-test deployment/airflow-test-scheduler -- \
  bash -c 'echo "test" | aws s3 cp - s3://BUCKET_LOGS/test.txt'
```

## Problemas com Milvus

### Problema: Etcd cluster não forma quorum

**Sintomas**:
```
etcd-0 Running, etcd-1 CrashLoopBackOff, etcd-2 Pending
```

**Solução**:
```bash
# Verificar logs de cada pod
kubectl logs -n milvus-dev milvus-mmjc-dev-etcd-0
kubectl logs -n milvus-dev milvus-mmjc-dev-etcd-1

# Verificar PVCs
kubectl get pvc -n milvus-dev | grep etcd
# Todos devem estar Bound

# Verificar network connectivity
kubectl exec -it -n milvus-dev milvus-mmjc-dev-etcd-0 -- \
  nslookup milvus-mmjc-dev-etcd-1.milvus-mmjc-dev-etcd

# Se necessário, deletar e recriar
kubectl delete statefulset milvus-mmjc-dev-etcd -n milvus-dev
kubectl apply -k kustomize/milvus/
```

### Problema: Kafka pods não inicializam

**Sintomas**:
```
Error: Connection to node -1 (localhost/127.0.0.1:9092) could not be established
```

**Solução**:
```bash
# Verificar Zookeeper primeiro
kubectl get pods -n milvus-dev -l app=zookeeper
# Todos devem estar Running

# Verificar logs Kafka
kubectl logs -n milvus-dev milvus-mmjc-dev-kafka-0 --tail=100

# Verificar conectividade com Zookeeper
kubectl exec -it -n milvus-dev milvus-mmjc-dev-kafka-0 -- \
  bash -c 'echo stat | nc milvus-mmjc-dev-zookeeper-0.milvus-mmjc-dev-zookeeper 2181'

# Reset Kafka se necessário
kubectl delete statefulset milvus-mmjc-dev-kafka -n milvus-dev
kubectl delete pvc -l app=kafka -n milvus-dev
kubectl apply -k kustomize/milvus/
```

### Problema: Milvus API não responde

**Sintomas**:
```
Connection refused on port 19530
```

**Solução**:
```bash
# Verificar proxy pod
kubectl get pods -n milvus-dev -l component=proxy

# Verificar logs
kubectl logs -n milvus-dev -l component=proxy --tail=100

# Verificar service
kubectl get svc -n milvus-dev milvus-mmjc-dev-proxy

# Testar port-forward
kubectl port-forward -n milvus-dev svc/milvus-mmjc-dev-proxy 19530:19530 &
python3 -c "from pymilvus import connections; connections.connect('localhost', '19530')"
```

### Problema: MinIO pods falham

**Sintomas**:
```
Readiness probe failed: HTTP probe failed with statuscode: 503
```

**Solução**:
```bash
# Verificar logs
kubectl logs -n milvus-dev milvus-mmjc-dev-minio-0 --tail=100

# Verificar PVCs
kubectl get pvc -n milvus-dev | grep minio

# Verificar storage class
kubectl get sc

# Se usar S3 em vez de MinIO, atualizar configuração do Milvus
# Ver 05-milvus-migration.md seção "Usar S3 Nativo"
```

## Problemas de Storage

### Problema: PVC não faz bind

**Sintomas**:
```
PersistentVolumeClaim is in Pending state
```

**Solução**:
```bash
# Verificar eventos
kubectl describe pvc PVC_NAME -n NAMESPACE

# Verificar storage class
kubectl get sc

# Se gp3 não existe, criar:
cat <<EOF | kubectl apply -f -
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: gp3
provisioner: ebs.csi.aws.com
parameters:
  type: gp3
  fsType: ext4
volumeBindingMode: WaitForFirstConsumer
EOF

# Verificar EBS CSI driver
kubectl get pods -n kube-system | grep ebs-csi

# Se não existe, instalar:
kubectl apply -k "github.com/kubernetes-sigs/aws-ebs-csi-driver/deploy/kubernetes/overlays/stable/?ref=release-1.25"
```

### Problema: Disco cheio

**Sintomas**:
```
no space left on device
```

**Solução**:
```bash
# Verificar uso de disco
kubectl exec -it POD_NAME -n NAMESPACE -- df -h

# Aumentar tamanho do PVC (se suportado)
kubectl patch pvc PVC_NAME -n NAMESPACE -p '{"spec":{"resources":{"requests":{"storage":"200Gi"}}}}'

# Ou criar novo PVC maior e migrar dados
# 1. Criar novo PVC
# 2. Copiar dados
# 3. Atualizar StatefulSet
# 4. Deletar PVC antigo
```

## Problemas de Rede

### Problema: Pods não conseguem se comunicar

**Sintomas**:
```
dial tcp: lookup service-name on xxx:53: no such host
```

**Solução**:
```bash
# Verificar DNS interno
kubectl run -it --rm debug --image=busybox --restart=Never -- \
  nslookup kubernetes.default

# Verificar network policies
kubectl get networkpolicies -A

# Verificar security groups do EKS
aws eks describe-cluster --name SEU_CLUSTER_EKS \
  --query 'cluster.resourcesVpcConfig.clusterSecurityGroupId'

# Testar conectividade entre pods
kubectl run -it --rm debug --image=busybox --restart=Never -- \
  wget -O- http://service-name.namespace:port
```

### Problema: Ingress não funciona

**Sintomas**:
```
502 Bad Gateway ou timeout
```

**Solução**:
```bash
# Verificar ALB Ingress Controller
kubectl get pods -n kube-system | grep aws-load-balancer-controller

# Se não existe, instalar:
# https://docs.aws.amazon.com/eks/latest/userguide/aws-load-balancer-controller.html

# Verificar ingress
kubectl get ingress -n NAMESPACE
kubectl describe ingress INGRESS_NAME -n NAMESPACE

# Verificar target groups na AWS Console
aws elbv2 describe-target-groups

# Verificar health checks
aws elbv2 describe-target-health --target-group-arn arn:aws:...
```

## Problemas com RDS/Redis

### Problema: Timeout conectando ao RDS

**Sintomas**:
```
timeout: connection timed out
```

**Solução**:
```bash
# Verificar security group do RDS
aws rds describe-db-instances \
  --db-instance-identifier itau-airflow-postgres \
  --query 'DBInstances[0].VpcSecurityGroups'

# Verificar security group do EKS
aws eks describe-cluster --name SEU_CLUSTER_EKS \
  --query 'cluster.resourcesVpcConfig.clusterSecurityGroupId'

# Adicionar regra no security group do RDS
aws ec2 authorize-security-group-ingress \
  --group-id sg-rds \
  --protocol tcp \
  --port 5432 \
  --source-group sg-eks

# Testar de dentro do cluster
kubectl run -it --rm psql-test --image=postgres:15 --restart=Never -- \
  psql -h RDS_ENDPOINT -U airflow_admin -d airflow
```

### Problema: ElastiCache inacessível

**Sintomas**:
```
Error connecting to Redis: Connection refused
```

**Solução**:
```bash
# Verificar endpoint
aws elasticache describe-cache-clusters \
  --cache-cluster-id itau-airflow-redis \
  --show-cache-node-info

# Verificar security group
aws elasticache describe-cache-clusters \
  --cache-cluster-id itau-airflow-redis \
  --query 'CacheClusters[0].SecurityGroups'

# Adicionar regra
aws ec2 authorize-security-group-ingress \
  --group-id sg-redis \
  --protocol tcp \
  --port 6379 \
  --source-group sg-eks

# Testar
kubectl run -it --rm redis-test --image=redis:7 --restart=Never -- \
  redis-cli -h REDIS_ENDPOINT ping
```

## Problemas com OAuth2

### Problema: Redirect loop

**Sintomas**:
```
Browser fica redirecionando infinitamente
```

**Solução**:
```bash
# Verificar logs OAuth2 Proxy
kubectl logs -n airflow-test -l app=oauth2-proxy --tail=100

# Verificar redirect URI no Azure AD
# Deve ser: https://airflow.exemplo.com/oauth2/callback

# Verificar cookie domain
kubectl get configmap oauth2-proxy-config -n airflow-test -o yaml
# Deve incluir: cookie_domains = [".exemplo.com"]

# Verificar HTTPS
curl -I https://airflow.exemplo.com
# Deve retornar 302 com Location header
```

### Problema: "Invalid client" no Azure AD

**Sintomas**:
```
AADSTS700016: Application with identifier 'xxx' was not found
```

**Solução**:
```bash
# Verificar Client ID
kubectl get secret oauth2-proxy-secrets -n airflow-test -o jsonpath='{.data.client-id}' | base64 -d

# Comparar com Azure AD Portal
# App registrations → Application (client) ID

# Se diferente, atualizar secret:
kubectl delete secret oauth2-proxy-secrets -n airflow-test
kubectl create secret generic oauth2-proxy-secrets \
  --from-literal=client-id="CLIENT_ID_CORRETO" \
  --from-literal=client-secret="CLIENT_SECRET" \
  --from-literal=cookie-secret="COOKIE_SECRET" \
  -n airflow-test

# Restart OAuth2 Proxy
kubectl rollout restart deployment oauth2-proxy -n airflow-test
```

## Problemas de Performance

### Problema: Pods lentos ou OOMKilled

**Sintomas**:
```
OOMKilled or high CPU usage
```

**Solução**:
```bash
# Ver recursos atuais
kubectl top pods -n NAMESPACE

# Aumentar recursos
kubectl edit deployment DEPLOYMENT_NAME -n NAMESPACE
# Aumentar:
# resources:
#   requests:
#     memory: "2Gi"
#     cpu: "1000m"
#   limits:
#     memory: "4Gi"
#     cpu: "2000m"

# Ou via patch
kubectl patch deployment DEPLOYMENT_NAME -n NAMESPACE -p '
{
  "spec": {
    "template": {
      "spec": {
        "containers": [{
          "name": "container-name",
          "resources": {
            "requests": {"memory": "2Gi", "cpu": "1000m"},
            "limits": {"memory": "4Gi", "cpu": "2000m"}
          }
        }]
      }
    }
  }
}'
```

## Scripts Úteis

### Debug de Pods

```bash
# Ver todas as informações de um pod
kubectl describe pod POD_NAME -n NAMESPACE

# Ver logs de todos os containers
kubectl logs POD_NAME -n NAMESPACE --all-containers=true

# Executar shell no pod
kubectl exec -it POD_NAME -n NAMESPACE -- /bin/bash

# Ver eventos recentes
kubectl get events -n NAMESPACE --sort-by='.lastTimestamp' | tail -20
```

### Limpeza de Recursos

```bash
# Deletar pods em erro
kubectl delete pods --field-selector=status.phase=Failed -A

# Limpar imagens não utilizadas
kubectl get pods -A -o jsonpath='{range .items[*]}{.spec.containers[*].image}{"\n"}{end}' | sort -u

# Forçar restart de deployment
kubectl rollout restart deployment DEPLOYMENT_NAME -n NAMESPACE
```

## Contatos e Suporte

Para problemas não cobertos por este guia:
1. Verificar logs detalhados
2. Consultar documentação oficial dos componentes
3. Abrir issue no repositório do projeto
4. Contatar equipe de infraestrutura

## Documentação Adicional

- [Documentação AWS EKS](https://docs.aws.amazon.com/eks/)
- [Documentação Apache Airflow](https://airflow.apache.org/docs/)
- [Documentação Milvus](https://milvus.io/docs/)
- [kubectl Cheat Sheet](https://kubernetes.io/docs/reference/kubectl/cheatsheet/)
