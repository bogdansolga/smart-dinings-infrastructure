PostgreSQL can be accessed through Pgpool via port 5432 on the following DNS name from within your cluster:
```
smart-dinings-postgresql-ha-pgpool.smart-dinings-infrastructure.svc.cluster.local
```

Pgpool acts as a load balancer for PostgreSQL and forward read/write connections to the primary node while read-only connections are forwarded to standby nodes.

To get the password for "postgres" run:
```
export POSTGRES_PASSWORD=$(kubectl get secret --namespace smart-dinings-infrastructure smart-dinings-postgresql-ha-postgresql -o jsonpath="{.data.password}" | base64 -d)
```

To get the password for "repmgr" run:
```
export REPMGR_PASSWORD=$(kubectl get secret --namespace smart-dinings-infrastructure smart-dinings-postgresql-ha-postgresql -o jsonpath="{.data.repmgr-password}" | base64 -d)
```

To connect to your database run the following command:
```
kubectl run smart-dinings-postgresql-ha-client --rm --tty -i --restart='Never' --namespace smart-dinings-infrastructure --image docker.io/bitnami/postgresql-repmgr:16.4.0-debian-12-r7 --env="PGPASSWORD=$POSTGRES_PASSWORD"  \
    --command -- psql -h smart-dinings-postgresql-ha-pgpool -p 5432 -U postgres -d postgres
```

To connect to your database from outside the cluster execute the following commands:
```
kubectl port-forward --namespace smart-dinings-infrastructure svc/smart-dinings-postgresql-ha-pgpool 5432:5432 &
psql -h 127.0.0.1 -p 5432 -U postgres -d postgres
```

----------

WARNING: There are "resources" sections in the chart not set. Using "resourcesPreset" is not recommended for production. For production installations, please set the following values according to your workload needs:
- metrics.resources
- pgpool.resources
- postgresql.resources
- witness.resources
