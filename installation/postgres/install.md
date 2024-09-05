
#### 2. PostgreSQL HA Installation with Helm

Set up PostgreSQL in a high-availability configuration using the Bitnami Helm chart.

1. Create a `values-postgresql-ha.yaml` file with the following content:
```yaml
global:
  storageClass: "longhorn-postgresql-ha"
  postgresql:
    auth:
      postgresPassword: "your_secure_postgres_password"
      replicationPassword: "your_secure_replication_password"
      database: "smartdinings"

primary:
  persistence:
    size: 8Gi
  resources:
    requests:
      memory: 1Gi
      cpu: 500m
    limits:
      memory: 2Gi
      cpu: 1000m

readReplicas:
  replicaCount: 2
  persistence:
    size: 8Gi
  resources:
    requests:
      memory: 1Gi
      cpu: 500m
    limits:
      memory: 2Gi
      cpu: 1000m

pgpool:
  replicaCount: 2
  adminPassword: "your_secure_pgpool_admin_password"

metrics:
  enabled: true
```

2. Install PostgreSQL using Helm:

```bash
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update
helm install smart-dinings-postgres bitnami/postgresql-ha \
  --namespace smart-dinings-infrastructure \
  --create-namespace \
  -f values-postgresql-ha.yaml
```

To connect to your database from outside the cluster execute the following commands:
```
kubectl port-forward --namespace smart-dinings-infrastructure svc/smart-dinings-postgres-postgresql-ha-pgpool 5432:5432 &
psql -h 127.0.0.1 -p 5432 -U postgres -d postgres
```