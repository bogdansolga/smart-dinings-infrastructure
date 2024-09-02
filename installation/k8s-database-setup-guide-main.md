# Comprehensive Kubernetes Setup Guide: Databases, Applications, and Networking

## Table of Contents
1. Prerequisites
2. Helm Installation
3. Longhorn Setup
4. PostgreSQL Installation
5. Redis Installation
6. Milvus Installation
7. Application Deployment
8. Kubernetes Networking
9. Traefik Ingress Setup
10. Monitoring and Logging
11. Backup and Disaster Recovery
12. Troubleshooting
13. Best practices and Considerations

## 1. Prerequisites

Ensure you have the following:

- A running Kubernetes cluster (e.g., minikube, EKS, GKE, AKS)
- kubectl installed and configured
- Helm 3 installed
- Access to pull images from Docker Hub
- Domain name (for Ingress configuration)

#### Passwords generation

```bash
POSTGRES_PASSWORD=$(openssl rand -base64 32)
POSTGRES_REPLICATION_PASSWORD=$(openssl rand -base64 32)
REDIS_PASSWORD=$(openssl rand -base64 32)
MINIO_ACCESS_KEY=$(openssl rand -base64 32)
MINIO_SECRET_KEY=$(openssl rand -base64 32)

echo "PostgreSQL Password: $POSTGRES_PASSWORD"
echo "PostgreSQL Replication Password: $POSTGRES_REPLICATION_PASSWORD"
echo "Redis Password: $REDIS_PASSWORD"
echo "MinIO Access Key: $MINIO_ACCESS_KEY"
echo "MinIO Secret Key: $MINIO_SECRET_KEY"
```

---------------------------------------------------------------------------------

## 2. Helm Installation

Install Helm 3:

```bash
curl https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 | bash
```

Verify the installation:

```bash
helm version
```

---------------------------------------------------------------------------------

## 3. Longhorn Setup

Before setting up our applications, we need to configure Longhorn as our storage provider.

Install Longhorn using Helm:

```bash
helm repo add longhorn https://charts.longhorn.io
helm repo update
helm install longhorn longhorn/longhorn --namespace longhorn-system --create-namespace
```

Create a default StorageClass for Longhorn (`longhorn-storage-class.yaml`):

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: longhorn
provisioner: driver.longhorn.io
allowVolumeExpansion: true
parameters:
  numberOfReplicas: "3"
  staleReplicaTimeout: "2880"
  fromBackup: ""
```

Apply the StorageClass:

```bash
kubectl apply -f longhorn-storageclass.yaml
```

Set Longhorn as the default StorageClass:

```bash
kubectl patch storageclass longhorn -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
```

---------------------------------------------------------------------------------

## 4. PostgreSQL Installation

Add the Bitnami Helm repository:

```bash
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update
```

Create `postgres-values.yaml`:

```yaml
global:
  postgresql:
    auth:
      postgresPassword: ${POSTGRES_PASSWORD}
      database: smartdinings
primary:
  persistence:
    storageClass: "longhorn"
    size: 8Gi
  resources:
    requests:
      memory: 256Mi
      cpu: 250m
    limits:
      memory: 512Mi
      cpu: 500m
```

PostgreSQL secret (`postgres-secret.yaml`):
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: postgres-secret
type: Opaque
stringData:
  postgres-password: ${POSTGRES_PASSWORD}
  postgres-replication-password: ${POSTGRES_REPLICATION_PASSWORD}
```

Apply the secret:
```bash
kubectl apply -f postgres-secret.yaml
```

Install PostgreSQL:

```bash
helm install smart-dinings-postgres bitnami/postgresql \
    --set global.postgresql.auth.existingSecret=postgres-secret \
    --set global.postgresql.auth.secretKeys.adminPasswordKey=postgres-password \
    --set global.postgresql.auth.secretKeys.replicationPasswordKey=postgres-replication-password \
    --set primary.persistence.size=8Gi
```

---------------------------------------------------------------------------------

## 5. Redis Installation

Create `redis-values.yaml`:

```yaml
auth:
   password: ${REDIS_PASSWORD}
master:
   persistence:
      storageClass: "longhorn"
      size: 8Gi
   resources:
      requests:
         memory: 128Mi
         cpu: 100m
      limits:
         memory: 256Mi
         cpu: 250m
replica:
   persistence:
      storageClass: "longhorn"
      size: 8Gi
   resources:
      requests:
         memory: 128Mi
         cpu: 100m
      limits:
         memory: 256Mi
         cpu: 250m
```

### Redis secret (`redis-secret.yaml`)::
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: redis-secret
type: Opaque
stringData:
  redis-password: ${REDIS_PASSWORD}
```

Apply the secret:
```bash
kubectl apply -f redis-secret.yaml
```

Install Redis:

```bash
helm install smart-dinings-redis bitnami/redis \
    --set auth.existingSecret=redis-secret \
    --set auth.existingSecretPasswordKey=redis-password \
    --set master.persistence.size=8Gi \
    --set replica.persistence.size=8Gi
```

---------------------------------------------------------------------------------

## 6. Milvus Installation

Add the Milvus Helm repository:

```bash
helm repo add milvus https://milvus-io.github.io/milvus-helm/
helm repo update
```

Create `milvus-values.yaml`:

```yaml
cluster:
   enabled: true
etcd:
   replicaCount: 3
   persistence:
      storageClass: "longhorn"
   resources:
      requests:
         memory: 256Mi
         cpu: 250m
      limits:
         memory: 512Mi
         cpu: 500m
minio:
   mode: distributed
   persistence:
      storageClass: "longhorn"
      size: 10Gi
   resources:
      requests:
         memory: 256Mi
         cpu: 250m
      limits:
         memory: 512Mi
         cpu: 500m
pulsar:
   persistence:
      storageClass: "longhorn"
      size: 10Gi
   resources:
      requests:
         memory: 512Mi
         cpu: 250m
      limits:
         memory: 1Gi
         cpu: 500m
proxy:
   replicas: 2
   resources:
      requests:
         memory: 256Mi
         cpu: 250m
      limits:
         memory: 512Mi
         cpu: 500m
```

#### Milvus secret (`milvus-secret.yaml`):
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: milvus-secret
type: Opaque
stringData:
  rootCoordinator-address: milvus-root-coord
  rootCoordinator-port: "19530"
  etcd-endpoints: milvus-etcd:2379
  pulsar-address: pulsar://milvus-pulsar:6650
  minio-address: milvus-minio:9000
  minio-accessKey: ${MINIO_ACCESS_KEY}
  minio-secretKey: ${MINIO_SECRET_KEY}
```
Apply the secret:
```bash
kubectl apply -f milvus-secret.yaml
```

Install Milvus:

```bash
helm install smart-dinings-milvus milvus/milvus \
    --set cluster.enabled=true \
    --set etcd.replicaCount=3 \
    --set minio.mode=distributed \
    --set minio.persistence.size=10Gi \
    --set pulsar.persistence.size=10Gi \
    --set externalSecret.existingSecret=milvus-secret
```

---------------------------------------------------------------------------------

## 7. Application Deployment

### ConfigMap (`configmap.yaml`)

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
   name: smart-dinings-config
data:
   DB_HOST: "smart-dinings-postgresql"
   DB_PORT: "5432"
   DB_NAME: "smartdinings"
   REDIS_HOST: "smart-dinings-redis-master"
   REDIS_PORT: "6379"
   MILVUS_HOST: "smart-dinings-milvus-proxy"
   MILVUS_PORT: "19530"
```

### Secrets (`secrets.yaml`)

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: smart-dinings-secrets
type: Opaque
stringData:
  POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
  REDIS_PASSWORD: ${REDIS_PASSWORD}
```

### Deployment (deployment.yaml)

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: smart-dinings-backend
spec:
  replicas: 2
  selector:
    matchLabels:
      app: smart-dinings-backend
  template:
    metadata:
      labels:
        app: smart-dinings-backend
    spec:
      containers:
      - name: smart-dinings-backend
        image: bogdansolga/smart-dinings-backend:0.0.1-SNAPSHOT-2024-09-02-147d22a
        envFrom:
        - configMapRef:
            name: smart-dinings-backend-config
        - secretRef:
            name: smart-dinings-backend-secrets
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 500m
            memory: 512Mi
        readinessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 10
          periodSeconds: 5
        livenessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 15
          periodSeconds: 10
```

Apply these configurations:

```bash
kubectl apply -f configmap.yaml
kubectl apply -f secrets.yaml
kubectl apply -f deployment.yaml
```

---------------------------------------------------------------------------------

## 8. Kubernetes configuration 

### 8.1 Networking

#### Ingress (ingress.yaml)

?

#### Service (service.yaml)

```yaml
apiVersion: v1
kind: Service
metadata:
  name: smart-dinings-backend-service
spec:
  selector:
    app: smart-dinings-backend
  ports:
    - protocol: TCP
      port: 80
      targetPort: 8080
```

Apply the service:

```bash
kubectl apply -f service.yaml
```

### 8.2. Kubernetes Integrations

#### Connecting to PostgreSQL

Use the following environment variables in your application:

```yaml
env:
  - name: DB_HOST
    value: "smart-dinings-postgres-postgresql"
  - name: DB_PORT
    value: "5432"
  - name: DB_NAME
    value: "your_database_name"
  - name: DB_USER
    value: "postgres"
  - name: DB_PASSWORD
    valueFrom:
      secretKeyRef:
        name: smart-dinings-postgres-postgresql
        key: postgres-password
```

### Connecting to Redis

Use the following environment variables:

```yaml
env:
  - name: REDIS_HOST
    value: "smart-dinings-redis-master"
  - name: REDIS_PORT
    value: "6379"
  - name: REDIS_PASSWORD
    valueFrom:
      secretKeyRef:
        name: smart-dinings-redis
        key: redis-password
```

### Connecting to Milvus

Use the following environment variables:

```yaml
env:
  - name: MILVUS_HOST
    value: "smart-dinings-milvus-proxy"
  - name: MILVUS_PORT
    value: "19530"
```

---------------------------------------------------------------------------------

## 8. Traefik Ingress Setup

First, install Traefik using Helm:

```bash
helm repo add traefik https://helm.traefik.io/traefik
helm repo update
helm install traefik traefik/traefik
```

Create an Ingress resource (ingress.yaml):

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: smart-dinings-ingress
  annotations:
    kubernetes.io/ingress.class: traefik
    traefik.ingress.kubernetes.io/router.entrypoints: web, websecure
    traefik.ingress.kubernetes.io/router.tls: "true"
spec:
  rules:
  - host: smartdinings.yourdomain.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: smart-dinings-app-service
            port: 
              number: 80
  tls:
  - hosts:
    - smartdinings.yourdomain.com
    secretName: smartdinings-tls
```

Apply the Ingress:

```bash
kubectl apply -f ingress.yaml
```

Note: You'll need to set up TLS certificates for HTTPS. You can use cert-manager with Let's Encrypt for automatic certificate management.

---------------------------------------------------------------------------------

## 9. Monitoring and Logging

For monitoring, consider setting up Prometheus and Grafana:

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
helm install prometheus prometheus-community/kube-prometheus-stack
```

For logging, you can use the ELK stack or Loki:

```bash
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update
helm install loki grafana/loki-stack
```

Add Longhorn dashboard to Grafana:

1. Access your Grafana dashboard
2. Go to "Configuration" > "Data Sources"
3. Add a new Prometheus data source if not already present
4. Import the Longhorn dashboard using ID 13032 or using the JSON from the Longhorn documentation

## 10. Backup and Disaster Recovery

For PostgreSQL, you can use pgBackRest for backups. Install it alongside your PostgreSQL instance and configure regular backups.

For Redis, enable AOF (Append-Only File) persistence and configure regular RDB snapshots.

For Milvus, regular backups of the MinIO storage are crucial. You can use the MinIO Client (mc) to set up scheduled backups.

Consider using Velero for cluster-wide backups:

```bash
helm repo add vmware-tanzu https://vmware-tanzu.github.io/helm-charts
helm repo update
helm install velero vmware-tanzu/velero --namespace velero --create-namespace
```

### Longhorn Backup and Restore

For Longhorn-specific backups:

1. Create a backup target (e.g., S3-compatible storage):

```yaml
apiVersion: longhorn.io/v1beta1
kind: BackupTarget
metadata:
  name: s3-backup-target
  namespace: longhorn-system
spec:
  backupTargetURL: s3://your-bucket-name@region/
  credentialSecret: s3-backup-secret
```

2. Create a recurring backup job:

```yaml
apiVersion: longhorn.io/v1beta1
kind: RecurringJob
metadata:
  name: backup-daily
  namespace: longhorn-system
spec:
  cron: "0 0 * * *"
  task: "backup"
  groups:
  - default
  retain: 7
  concurrency: 2
```

Apply these configurations:

```bash
kubectl apply -f backup-target.yaml
kubectl apply -f recurring-backup.yaml
```

---------------------------------------------------------------------------------

## 11. Troubleshooting

1. Check pod status:
   ```bash
   kubectl get pods
   ```

2. View pod logs:
   ```bash
   kubectl logs <pod-name>
   ```

3. Describe a pod for more details:
   ```bash
   kubectl describe pod <pod-name>
   ```

4. Check service status:
   ```bash
   kubectl get services
   ```

5. Test database connections from within a pod:
   ```bash
   kubectl run -it --rm --image=postgres:13 postgres-client -- psql -h smart-dinings-postgres-postgresql -U postgres -d smartdinings
   kubectl run -it --rm --image=redis:6 redis-client -- redis-cli -h smart-dinings-redis-master -a your_secure_redis_password
   ```

6. Check Ingress status:
   ```bash
   kubectl get ingress
   kubectl describe ingress smart-dinings-ingress
   ```

7. View Traefik logs:
   ```bash
   kubectl logs -l app.kubernetes.io/name=traefik -n default
   ```

#### Longhorn-specific troubleshooting:

1. Check Longhorn system health:
   ```bash
   kubectl -n longhorn-system get pods
   ```

2. View Longhorn manager logs:
   ```bash
   kubectl -n longhorn-system logs -l app=longhorn-manager
   ```

3. Check volume status:
   ```bash
   kubectl -n longhorn-system get volumes
   ```

4. Describe a problematic volume:
   ```bash
   kubectl -n longhorn-system describe volume <volume-name>
   ```

5. Access Longhorn UI (first, set up port-forwarding):
   ```bash
   kubectl -n longhorn-system port-forward service/longhorn-frontend 8080:80
   ```
   Then, access the UI at `http://localhost:8080`

Remember to replace placeholder values (like passwords, bucket names, and domain names) with your actual values. 
Always follow security best practices, especially when handling sensitive information.

This guide now includes Longhorn as the storage provider, with configurations for persistent storage in PostgreSQL, Redis, and Milvus. 
It also covers Longhorn-specific monitoring, backup, and troubleshooting steps. 

This should provide a DevOps engineer with comprehensive information to set up and maintain the entire SmartDinings stack on a Kubernetes cluster using Longhorn for storage.

---------------------------------------------------------------------------------

## 13. Best Practices and Considerations

1. **Security**:
   - Regularly rotate passwords and update Kubernetes secrets.
   - Use network policies to restrict traffic between services.
   - Enable encryption at rest for sensitive data.

2. **Scalability**:
   - Configure a `HorizontalPodAutoscaler` for your applications based on CPU or custom metrics for your applications
   - Monitor resource usage and adjust limits as needed

3. **High Availability**:
   - Use multiple replicas for each service (at least 3)
   - Implement proper liveness and readiness probes.

4. **Backup and Disaster Recovery**:
   - Regularly backup PostgreSQL and Redis data.
   - Implement a disaster recovery plan.

5. **Monitoring and Logging**:
   - Set up monitoring for all services (e.g., Prometheus and Grafana).
   - Implement centralized logging (e.g., ELK stack).

6. **Resource Management**:
   - Regularly review and optimize resource requests and limits.
   - Implement ResourceQuotas and LimitRanges at the namespace level.

7. **Updates and Maintenance**:
   - Regularly update Helm charts to get the latest security patches.
   - Plan for zero-downtime updates using rolling update strategy.

Remember to adjust configurations based on your specific requirements and always test thoroughly in a non-production environment before applying changes to production.