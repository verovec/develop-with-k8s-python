# Development

## Toolchain

- Docker (the cluster, the registry and the image builds all run in it).
- [k3d](https://k3d.io) and `kubectl`.
- Helm 3, used by DevSpace to install the chart.
- [DevSpace](https://www.devspace.sh) 6.2.5: `devspace.yaml` requires exactly that version.
- Python is not needed on the laptop: the dependencies are installed in the image.
- A line `127.0.0.1 develop-with-k8s.local` in `/etc/hosts`.

## Recipes

```bash
make start              # create or restart the k3d registry and cluster, ingress-nginx, namespaces
make deploy             # build the image, push it, install the chart (devspace deploy)
make dev                # deploy again, sync api/src into the pod, follow the logs (devspace dev)
make api                # deploy then dev
make all                # start then api
make cleanup-images     # remove the images DevSpace built (devspace cleanup images)
make stop               # k3d cluster stop and docker stop of the registry container
make delete             # delete the cluster, keep the registry
make cleanup            # delete the cluster and the registry
```

Checking the deployment while `make dev` runs:

```bash
curl http://develop-with-k8s.local/                 # {"message":"I am running !"}
kubectl get pods -n api                              # the api pod
kubectl get pods -n ingress-nginx                    # the controller must be Running
kubectl port-forward -n api deployment/api-deployment 8080:8080   # bypass the Ingress if needed
```

## Without DevSpace

The image can be built and run on its own:

```bash
docker build -t api api                  # python:3.10 plus the Poetry install
docker run --rm -p 8080:8080 api         # http://localhost:8080/
```

The chart can be installed by hand once an image is in the registry:

```bash
docker build -t k3d-develop-with-k8s.localhost:5111/api:latest api
docker push k3d-develop-with-k8s.localhost:5111/api:latest
helm upgrade --install api ./k8s/charts/api -n api -f k8s/charts/api/values.yaml \
  --set registry.endpoint=k3d-develop-with-k8s.localhost:5111
```

## Pitfalls

- `make dev` runs `devspace dev --dependency api` without `--skip-deploy`, so it redeploys before
  starting the sync. Expect a new image tag each time.
- The sync is bidirectional and has no exclusion: files created in `/app` by the container (for
  example `__pycache__/`) come back into `api/src`.
- The first `make start` pulls the k3s, registry and ingress-nginx images; the CoreDNS rollout
  wait at the end is normal.
- If `develop-with-k8s.local` does not answer, check the `/etc/hosts` line and that nothing else
  on the laptop listens on port 80.

## Conventions

- Only `api/src` is synced: a change to `pyproject.toml`, the Dockerfile, the chart or
  `devspace.yaml` needs a new `make deploy`.
- Run `make cleanup-images` from time to time: every deploy leaves a `dev-<random>` image behind.
