# Kubernetes deployment of OGC API DGT

This projects migrates the [OGCAPI](https://github.com/dgterritorio/OGCAPI) suite of services, implemented with docker compose, towards a kubernetes based architecture.

This directory contains a Kubernetes deployment of:

* A [pygeoapi](https://pygeoapi.io/) instance, configured to show some - and eventually, all - collections 
  from [OGC API DGT](https://github.com/dgterritorio/OGCAPI). 
* Tiles servers for the CAOP and cadastro collections (tiles-caop, tiles-inspire). The servers use [martin](https://github.com/maplibre/martin) a blazing fast and lightweight PostGIS tile server.

The Kubernetes manifests needed to run this server are generated with
[Kustomize](https://kustomize.io/). They build upon [a common base definition](./base/).

![architecture](./diagram.png)

## Required tools

To deploy and run these samples you will need the following tools:
* [Kustomize](https://kustomize.io/),
* The [kubectl](https://kubernetes.io/docs/tasks/tools/#kubectl) command-line tool,
* [Flannel](https://github.com/flannel-io/flannel), a container networking interface (CNI) plugin,
* [Ingress](https://kubernetes.io/docs/concepts/services-networking/ingress/), a resource that manages external access to services within the cluster,
* [MetalLB](https://metallb.io/), a load balancer.

## Deplying to a local cluster

Tested under Linux.

## Bring the cluster up

The cluster should be up and running now. Try the following command to
view its state:

    kubectl get pods -n kube-system
        NAME                                      READY   STATUS    RESTARTS   AGE
        coredns-674b8bbfcf-2zwpp                  1/1     Running   0          6d19h
        coredns-674b8bbfcf-47cq6                  1/1     Running   0          6d19h
        etcd-srvquaintergeo1                      1/1     Running   17         6d19h
        kube-apiserver-srvquaintergeo1            1/1     Running   17         6d19h
        kube-controller-manager-srvquaintergeo1   1/1     Running   1          6d19h
        kube-proxy-44rmd                          1/1     Running   0          6d17h
        kube-proxy-kv4d4                          1/1     Running   0          6d17h
        kube-proxy-wvvtk                          1/1     Running   0          6d17h
        kube-scheduler-srvquaintergeo1            1/1     Running   23         6d19h

    kubectl get nodes
        NAME              STATUS   ROLES           AGE     VERSION
        srvquaintergeo1   Ready    control-plane   6d19h   v1.33.3
        srvquaintergeo2   Ready    <none>          6d19h   v1.33.3
        srvquaintergeo3   Ready    <none>          6d19h   v1.33.3

## Deploy pygeoapi

If you need to reset a previous installation, go to [troubleshooting](#troubleshooting).

Create the Kubernetes namespace to host pygeoapi:

    kubectl create ns pygeoapi-demo
    namespace/pygeoapi-demo created

From this directory, generate and apply the Kubernetes manifests with the
following command:

    kustomize build . | kubectl apply -f -
    configmap/database-config-fmfm5hc2m5 created
    configmap/initdb-kcdht48dgb created
    configmap/pygeoapi-config-4gmh495k44 created
    secret/database-credentials-4ctbtbgmb5 created
    service/postgresql created
    service/pygeoapi created
    deployment.apps/pygeoapi created
    statefulset.apps/postgresql created
    ingress.networking.k8s.io/pygeoapi created

Check the pods are up and running:

```
  kubectl -n pygeoapi-demo get pods
  NAME                        READY   STATUS    RESTARTS   AGE
  pygeoapi-6d989df987-2v2p4   1/1     Running   0          9m1s
  pygeoapi-6d989df987-klkwb   1/1     Running   0          9m1s
```

You can check the logs of one deployment with:

    kubectl logs -f pygeoapi-6d989df987-2v2p4 -n pygeoapi-demo

## Create secrets from .env file

```bash
kubectl create secret generic app-secrets \
  --from-env-file=.env \
  -n pygeoapi-demo
```
In case it exists, delete it first:

```bash
kubectl delete secret app-secrets -n pygeoapi-demo
```

## SSL

Create secret in the pygeoapi-demo namespace:

```bash
kubectl create secret tls pygeoapi-tls-secret \
  --cert=/home/byteroad/fullchain1.pem \
  --key=/home/byteroad/privkey1.pem \
  -n pygeoapi-demo
```

In case it exists, delete it first:

```bash
kubectl delete secret pygeoapi-tls-secret -n pygeoapi-demo
```

## Access the server

Get ingress ports (here, 30184 and 32064):

```
kubectl get service -n ingress-nginx NAME                                 TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)                      AGE
ingress-nginx-controller             LoadBalancer   10.101.67.114   <pending>     80:30184/TCP,443:32064/TCP   90m
ingress-nginx-controller-admission   ClusterIP      10.98.112.13    <none>        443/TCP                      90m         
```

Check where ingress is running (here, srvquaintergeo3):

```
kubectl get pods -n ingress-nginx -o wide
NAME                                        READY   STATUS      RESTARTS   AGE   IP            NODE              NOMINATED NODE   READINESS GATES
ingress-nginx-admission-create-rrgz6        0/1     Completed   0          93m   10.244.2.48   srvquaintergeo3   <none>           <none>
ingress-nginx-admission-patch-w62d9         0/1     Completed   0          93m   10.244.2.47   srvquaintergeo3   <none>           <none>
ingress-nginx-controller-659c88cdd9-b7d4w   1/1     Running     0          93m   10.244.2.49   srvquaintergeo3   <none>           <none>
```

Get IP of that server (here, 192.168.10.130):

```
kubectl get nodes -o wide
NAME              STATUS   ROLES           AGE    VERSION   INTERNAL-IP      EXTERNAL-IP   OS-IMAGE             KERNEL-VERSION     CONTAINER-RUNTIME
srvquaintergeo1   Ready    control-plane   104m   v1.33.3   192.168.10.128   <none>        Ubuntu 24.04.2 LTS   6.8.0-71-generic   containerd://1.7.27
srvquaintergeo2   Ready    <none>          99m    v1.33.3   192.168.10.129   <none>        Ubuntu 24.04.2 LTS   6.8.0-71-generic   containerd://1.7.27
srvquaintergeo3   Ready    <none>          97m    v1.33.3   192.168.10.130   <none>        Ubuntu 24.04.2 LTS   6.8.0-71-generic   containerd://1.7.27
```

Connect to the server:

    curl 192.168.10.130:30184

## Load Balancer

To activate a load balancer that assigns IPs, we use MetalLB. Install with:

    kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.14.5/config/manifests/metallb-native.yaml

Check that is running:

        kubectl get pods -n metallb-system
        NAME                          READY   STATUS    RESTARTS   AGE
        controller-654858564f-ff8wb   1/1     Running   0          15m
        speaker-6xv9t                 1/1     Running   0          15m
        speaker-d6ff7                 1/1     Running   0          15m
        speaker-s6dws                 1/1     Running   0          15m

Apply manifest (setting up the range of reserved IPs):

        kubectl apply -f base/metallb-config.yaml

In this case, the set of reserved IPs is 192.168.10.140-192.168.10.150.

Check that ingress is running, this time with an external IP:

        kubectl get service -n ingress-nginx
        NAME                                 TYPE           CLUSTER-IP      EXTERNAL-IP      PORT(S)                      AGE
        ingress-nginx-controller             LoadBalancer   10.101.67.114   192.168.10.140   80:30184/TCP,443:32064/TCP   2d19h
        ingress-nginx-controller-admission   ClusterIP      10.98.112.13    <none>           443/TCP                      2d19h

Get a rule on the router, to redirect traffic to that address to the Internet.

## Applying sidecar

Sidecar is running a container that reads the nginx logs and sends them to matomo.

First we need to create a secret that stores the matomo token (replace [SOME TOKEN] by your matomo token):

    kubectl create secret generic matomo-credentials -n ingress-nginx --from-literal=token='[SOME TOKEN]'

Then apply the ingress controller and fluentd configuration:

    kubectl apply -f ingress-controller-with-sidecar.yaml

    kubectl apply -f fluentd-matomo-config.yaml

Rollout restart ingress with:

    kubectl rollout restart deployment ingress-nginx-contller -n ingress-nginx

If you need to check the ingress logs, first get the name of the pod:

    kubectl get pods -n ingress-nginx

And then:

    kubectl logs -f -n ingress-nginx ingress-nginx-controller-6f7f884f45-6gnb7 -c fluentd-sidecar

## Redeploying pygeoapi

Redeploying pygeoapi and its supporting services, comes down to reapplying the manifest:

    kustomize build . | kubectl apply -f -

If you also need to restart the deployment:

    kubectl -n pygeoapi-demo rollout restart deployment pygeoapi
    deployment.apps/pygeoapi restarted

Kubernetes takes care of reapplying the configuration with minimum downtime.

## Troubleshooting

Delete namespace:

    kubectl delete namespace pygeoapi-demo
    namespace "pygeoapi-demo" deleted

Reload ingress:

    kubectl apply -f base/ingress-ssl.yaml

Restart the pygeoapi pods:

    kubectl -n pygeoapi-demo rollout restart deployment pygeoapi
    deployment.apps/pygeoapi restarted

Recreate Flannel:

    kubectl delete -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml
    namespace "kube-flannel" deleted
    serviceaccount "flannel" deleted
    clusterrole.rbac.authorization.k8s.io "flannel" deleted
    clusterrolebinding.rbac.authorization.k8s.io "flannel" deleted
    configmap "kube-flannel-cfg" deleted
    daemonset.apps "kube-flannel-ds" deleted
    byteroad@srvquaintergeo1:~/git/hello-k8$ kubectl get pods -n kube-system | grep flannel
    byteroad@srvquaintergeo1:~/git/hello-k8$ kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml
    namespace/kube-flannel created
    serviceaccount/flannel created
    clusterrole.rbac.authorization.k8s.io/flannel created
    clusterrolebinding.rbac.authorization.k8s.io/flannel created
    configmap/kube-flannel-cfg created
    daemonset.apps/kube-flannel-ds created

## Next Steps

- Install postgreSQL database on a separate server: https://github.com/byteroad/postgres-dgt
- Port the rest of the pygeoapi configuration
- Add a tool for publishing the logs. Note: matomo is supported!
- Add README for k8 install

## Generate Diagrams

    kubectl kustomize base | docker run -v "$(pwd)":/work -i philippemerle/kubediagrams kube-diagrams - -o diagram.png


## License

This project is released under a [MIT License](./LICENSE)

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)