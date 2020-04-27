# Wallarm Sidecar Injection though Mutating Webhook

Based on ["Kubernetes Mutating Webhook for Sidecar Injection"](https://github.com/morvencao/kube-mutating-webhook-tutorial)

This repository to show how to deploy MutatingAdmissionWebhook for wallarm-sidecar container injection

## Prerequisites

- [git](https://git-scm.com/downloads)
- [go](https://golang.org/dl/) version v1.12+
- [docker](https://docs.docker.com/install/) version 17.03+
- [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/) version v1.11.3+
- Access to a Kubernetes v1.11.3+ cluster with the `admissionregistration.k8s.io/v1beta1` API enabled. Verify that by the following command:

```
kubectl api-versions | grep admissionregistration.k8s.io
```
The result should be either
```
admissionregistration.k8s.io/v1
```
or
```
admissionregistration.k8s.io/v1beta1
```
or both

## Build

1. Build docker image
   
```
make build-image
```

2. Push docker image into a registry

```
make push-image
```

> NB: log in to docker registry is required

## Deploy

1. Create namespace `sidecar-injector` in which the sidecar injector webhook is deployed

```
kubectl create ns sidecar-injector
```

2. Create a signed cert/key pair and store it in a Kubernetes `secret` that will be consumed by sidecar injector deployment

```
./deployment/webhook-create-signed-cert.sh \
    --service sidecar-injector-webhook-svc \
    --secret sidecar-injector-webhook-certs \
    --namespace sidecar-injector
```

3. Patch the `MutatingWebhookConfiguration` by set `caBundle` with correct value from Kubernetes cluster

```
cat deployment/mutatingwebhook.yaml | \
    deployment/webhook-patch-ca-bundle.sh > \
    deployment/mutatingwebhook-ca-bundle.yaml
```

4. Deploy resources:

```
kubectl create -f sidecar-deployment/injection-configmap.yaml
kubectl create -f sidecar-deployment/sidecar-deployment.yaml
kubectl create -f sidecar-deployment/sidecar-service.yaml
kubectl create -f sidecar-deployment/mutatingwebhook-ca-bundle.yaml
```

## Verify

1. The sidecar inject webhook should be in running state

```
kubectl -n sidecar-injector get pod
```

2. Create new namespace `injection` and label it with `sidecar-injector=enabled`:

```
kubectl create ns injection
kubectl label namespace injection sidecar-injection=enabled
kubectl get namespace -L sidecar-injection
NAME                 STATUS   AGE   SIDECAR-INJECTION
default              Active   26m
injection            Active   13s   enabled
kube-public          Active   26m
kube-system          Active   26m
sidecar-injector     Active   17m
```

3. Ensure a Node Token to be used. Change '<NODE_TOKEN>' to the relevant value from Wallarm UI

```
./deployment/wallarm-token-patch.sh '<NODE_TOKEN>'
```

4. Deploy [dvwa](https://hub.docker.com/r/vulnerables/web-dvwa/) app in Kubernetes cluster

```
kubectl create -f deployment/wallarm-nginx-configmap.yaml
kubectl create -f deployment/wallarm-secret-patched.yaml
kubectl create -f deployment/wallarm-deploy.yaml
kubectl create -f deployment/wallarm-service.yaml
kubectl create -f deployment/mutatingwebhook-ca-bundle.yaml
```

5. Verify sidecar container is injected:

```
kubectl get pods -n injection
NAME                     READY   STATUS        RESTARTS   AGE
myapp-84886f8ff9-4gwpr   3/3     Running       0          17s
```

## Troubleshooting guide

1. Webhook is in running state
2. The namespace in which application pod is deployed has the correct labels as configured in `mutatingwebhookconfiguration`
3. Check the `caBundle` is patched to `mutatingwebhookconfiguration` object by checking if `caBundle` fields is empty
4. Check the `WALLARM_TOKEN` is patched to `wallarm-secret-patched.yaml`
6. The targetPort of the service has changed to `56245`, the port of the wallarm-sidecar container
7. Ensure that deployment and service have the annotation `sidecar-injector-webhook.wallarm.injected/inject: "true"`
8. Make sure that `proxy_pass http://localhost:80;` defined in `wallarm-nginx-configmap.yaml` is appropriate for your App. App should be listening on the :80 port, if not you can easily change it to a suitable one, for instance `proxy_pass http://localhost:8080;`
9. If port `56245` is occupied in your App, it is feasible to alter to different one in the `webhook.go:L200`
10. You might want to use your own docker hub to locate sidecar-container. In this case, you may use the `docker-wallarm-node` folder with all necessary information to fulfill it. When all is said and done you are meant to sustitute `awallarm/wallarm-node-sidecar:slim` in the `injection-configmap.yaml` to yours.
> NB: `wallarm-nginx-configmap.yaml` still needs to be in the correct namespace distinct from webhook's one

## Reference

* [Diving into Kubernetes MutatingAdmissionWebhook](https://medium.com/ibm-cloud/diving-into-kubernetes-mutatingadmissionwebhook-6ef3c5695f74)