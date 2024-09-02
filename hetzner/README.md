## Services at the end:
* http://longhorn.pre.smartdinings.com/
* http://traefik.pre.smartdinings.com/dashboard/
* http://argocd.pre.smartdinings.com
  * user: admin
  * pass: UuYabYq4PVItfmkV

## Install

### Deploy kubernetes klaster
* Install: https://github.com/vitobotta/hetzner-k3s
*run: `hetzner-k3s create --config cluster_config.yaml`

#### Connect to it
export KUBECONFIG=/srv/git/k3s/hetzern-k3s/kubeconfig
kubectl get nodes

### Install traefik (optional)
helm repo add traefik https://traefik.github.io/charts
helm repo update
helm install traefik traefik/traefik --values=traefik_custom.yaml --namespace traefik --create-namespace

### Install Longhorn
helm repo add longhorn https://charts.longhorn.io
helm repo update
helm upgrade -i longhorn longhorn/longhorn --namespace longhorn-system --create-namespace

### Enable ingress for services
kubectl apply -f ingress*.yaml

### Install ArgoCD
```
kubectl create namespace argocd
helm repo update
helm install argocd argo/argo-cd --namespace argocd --create-namespace --values=argocd_custom.yaml
```

## Postgresql
https://medium.com/@martin.hodges/adding-a-postgres-high-availability-database-to-your-kubernetes-cluster-634ea5d6e4a1