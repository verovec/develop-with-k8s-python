CLUSTER_NAME := develop-with-k8s
NB_NODES := 1

REGISTRY_NAME := develop-with-k8s.localhost
REGISTRY_PORT := 5111


all: start api

api: deploy dev

start:
	@bash cluster-init.sh $(CLUSTER_NAME) $(REGISTRY_NAME) $(REGISTRY_PORT) $(NB_NODES)

deploy:
	@devspace use namespace api
	@devspace deploy --dependency api

dev:
	@devspace use namespace api
	@devspace dev --dependency api

delete:
	@k3d cluster delete $(CLUSTER_NAME)

cleanup: delete
	@k3d registry delete $(REGISTRY_NAME)

stop:
	@k3d cluster stop $(CLUSTER_NAME) --all
	@docker stop k3d-develop-with-k8s.localhost

.PHONY: start deploy dev delete cleanup stop
