# Architecture

## Layers

```
Makefile               cluster name, registry name and port, the make targets
cluster-init.sh        creates or restarts the k3d registry and cluster, namespaces, ingress-nginx
devspace.yaml          image build, Helm deployment and dev sync, all driven by DevSpace 6.2.5
api/
  Dockerfile           python:3.10, Poetry install of the project, python3 main.py
  pyproject.toml       package api 0.1.0: fastapi ^0.89.1, uvicorn ^0.18.2, python ^3.10
  src/main.py          FastAPI app, GET / and the uvicorn entrypoint (reload=True, port 8080)
k8s/
  nginx/nginx.yaml     ingress-nginx 1.5.1 controller manifests (namespace, RBAC, Service, Deployment, webhook)
  charts/api/
    Chart.yaml         chart api 0.0.1 (apiVersion v1)
    values.yaml        registry endpoint, image name and tag, replicas, resources, scaler
    templates/         deployment.yaml, service.yaml, ingress.yaml, hpa.yaml
resources/             the original architecture image
docs/assets/           logo, draw.io diagram and its PNG export
```

## Cluster bootstrap

`make start` runs `cluster-init.sh develop-with-k8s develop-with-k8s.localhost 5111 1`. When the
cluster already exists the script starts the registry container and the cluster and switches the
kubectl context. Otherwise it:

1. creates a k3d registry named `k3d-develop-with-k8s.localhost` listening on `0.0.0.0:5111`;
2. creates the cluster `develop-with-k8s` with one agent node, ports 80, 443 and 4200 mapped to
   the load balancer, Traefik disabled and the registry attached (`--registry-use`);
3. taints the server node with `node-role.kubernetes.io/master:NoSchedule` so workloads land on
   the agent;
4. creates the `ingress-nginx` and `api` namespaces;
5. applies `k8s/nginx/nginx.yaml`.

In both cases it waits for CoreDNS and restarts it, so the registry name resolves inside the
cluster.

## Ingress controller

`k8s/nginx/nginx.yaml` is the upstream ingress-nginx 1.5.1 deploy manifest: the controller
Deployment, its ServiceAccounts, Roles and bindings, the admission webhook with its certificate
jobs, and the `nginx` IngressClass. Its Service is of type LoadBalancer with three ports: 80 and
443 as usual, plus 4200 forwarded to the HTTPS target port. k3d maps those ports to the host, so
`http://develop-with-k8s.local/` reaches the controller once `/etc/hosts` points the name at
`127.0.0.1`.

## Image

`api/Dockerfile` starts from `python:3.10`, copies `src/` and `pyproject.toml` into `/app`,
installs Poetry, disables virtualenv creation and runs `poetry install`. The container runs
`python3 main.py`, which starts uvicorn on `0.0.0.0:8080` with `reload=True`. The `workers=2`
argument in `main.py` has no effect while reload is enabled: uvicorn runs a single reloading
process.

DevSpace builds that image with context `api`, tags it `dev-${DEVSPACE_RANDOM}` and pushes it to
`k3d-develop-with-k8s.localhost:5111/api`.

## Helm chart

| Template | Resource | Notes |
|----------|----------|-------|
| `deployment.yaml` | Deployment `api-deployment` | one replica, container `api` on port 8080, `imagePullPolicy: Always`, liveness probe `GET /` after 30 s, resources from `api.resources` |
| `service.yaml` | Service `api-service` | ClusterIP, port 80 to target port 8080, selector `app: api` |
| `ingress.yaml` | Ingress `api-ingress` | class `nginx`, host from `domain` (`develop-with-k8s.local`), path `/` to the service |
| `hpa.yaml` | HorizontalPodAutoscaler `api-hpa` | min and max replicas from `api.scaler`, 80 % CPU target |

The HPA targets a Deployment named `core-api-deployment`, which does not match
`api-deployment`, so it has no effect. It is harmless for the demonstration.

## DevSpace loop

`devspace.yaml` declares one image, one deployment and one dev configuration, all named `api`.

```
  devspace deploy --dependency api
     |   builds api/Dockerfile, pushes the image, installs k8s/charts/api in namespace api
  devspace dev --dependency api
     |   deploys again, selects the pod with label app=api, container api
     |   syncs ./api/src to /app in both directions
     |   streams the last 100 log lines and follows
  uvicorn (inside the container)
     |   reload=True: restarts the app on every file change under /app
```

## Configuration values

Values set by `devspace.yaml` for the chart (the chart's own `values.yaml` has the same keys with
`tag: latest` and the registry host without the `k3d-` prefix).

| Key | Value | Role |
|-----|-------|------|
| `domain` | `develop-with-k8s.local` | Ingress host |
| `registry.endpoint` | `k3d-develop-with-k8s.localhost:5111` | prefix of the image reference |
| `api.image.name` / `api.image.tag` | `api` / `dev-${DEVSPACE_RANDOM}` | image pulled by the Deployment |
| `api.replicas` | `1` | Deployment replicas |
| `api.resources` | 0.1 CPU and 256 Mi requested, 0.5 CPU and 512 Mi limit | container resources |
| `api.scaler` | min 1, max 5 | HPA bounds |
| `global.storageClass` | `local-path` | unused by the templates |

Makefile variables: `CLUSTER_NAME=develop-with-k8s`, `NB_NODES=1`,
`REGISTRY_NAME=develop-with-k8s.localhost`, `REGISTRY_PORT=5111`.
