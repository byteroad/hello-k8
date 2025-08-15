# Sample Kubernetes deployments

This directory contains a sample Kubernetes deployment of:

* A [pygeoapi](https://pygeoapi.io/) instance, configured to show the [CRUS Obidos dataset](https://snig.dgterritorio.gov.pt/rndg/srv/por/catalog.search#/metadata/517c5023-04cc-47a4-99f7-bb32814dd62f)
  from [DGT](https://www.dgterritorio.gov.pt/?language=en), which is served by:
* A PostgreSQL instance set up with the PostGIS extension, which stores the
  lake data.

The Kubernetes manifests needed to run these samples are generated with
[Kustomize](https://kustomize.io/). They build upon [a common base definition](./base/), and the
following types of Kubernetes clusters are supported:

* A local [minikube](https://minikube.sigs.k8s.io/docs/) cluster (see [./minikube/](./minikube/))

## Required tools

To deploy and run these samples you will need the following tools:
* [Kustomize](https://kustomize.io/),
* The [kubectl](https://kubernetes.io/docs/tasks/tools/#kubectl) command-line tool, and
* [bzip2](https://man.freebsd.org/cgi/man.cgi?query=bunzip&apropos=0).

If you have [Nix](https://nix.dev/) installed on your computer, the [Nix flake
definition](./flake.nix) in this directory will install those tools for you.


## Deplying to a local cluster

Tested under Linux.

## Bring the cluster up


The cluster should be up and running now. Try the following command to
view its state:

    $ kubectl get pods -n kube-system
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

    $ kubectl get nodes
        NAME              STATUS   ROLES           AGE     VERSION
        srvquaintergeo1   Ready    control-plane   6d19h   v1.33.3
        srvquaintergeo2   Ready    <none>          6d19h   v1.33.3
        srvquaintergeo3   Ready    <none>          6d19h   v1.33.3


## Deploy pygeoapi and the PostgreSQL instance

Create the Kubernetes namespace to host pygeoapi:

    $ kubectl create ns pygeoapi-demo
    namespace/pygeoapi-demo created

Make NGINX Ingress Controller pods and services run in the pygeoapo-demo ns

Install ingres controller:

    $ kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.10.1/deploy/static/provider/cloud/deploy.yaml


You can check that ingress is running with the following command:

    $ kubectl -n pygeoapi-demo get ingress

From this directory, generate and apply the Kubernetes manifests with the
following command:

    $ kustomize build . | kubectl apply -f -
    configmap/database-config-fmfm5hc2m5 created
    configmap/initdb-kcdht48dgb created
    configmap/pygeoapi-config-4gmh495k44 created
    secret/database-credentials-4ctbtbgmb5 created
    service/postgresql created
    service/pygeoapi created
    deployment.apps/pygeoapi created
    statefulset.apps/postgresql created
    ingress.networking.k8s.io/pygeoapi created

At this points the pygeoapi pods should not be available yet --- because
they're trying to access the lake dataset from the PostgreSQL instance,
and we haven't loaded it yet:

    $ kubectl -n pygeoapi-demo get pods
    NAME                        READY   STATUS             RESTARTS      AGE
    postgresql-0                1/1     Running            0             4m32s
    pygeoapi-7b5d79d6fb-hnbrt   0/1     CrashLoopBackOff   5 (71s ago)   4m32s
    pygeoapi-7b5d79d6fb-xgt7q   0/1     CrashLoopBackOff   5 (66s ago)   4m32s

## Loading the CRUS Obidos dataset

Once the PostgreSQL instance is up and running, use the
[load-data](./load-data) script to feed the crus data into Kubernetes
PostgreSQL instance:

```bash
    $ ./load-data 
+++ dirname ./load-data
++ cd .
++ pwd
+ here=/home/joana/git/hello-k8
+ bzcat /home/joana/git/hello-k8/crus_obidos.sql.bz2
+ kubectl -n pygeoapi-demo exec -i postgresql-0 -- psql --host localhost --user pygeoapi crus
SET
SET
SET
SET
SET
 set_config 
------------
 
(1 row)

SET
SET
SET
SET
SET
SET
DROP INDEX
ALTER TABLE
ALTER TABLE
DROP SEQUENCE
DROP TABLE
CREATE TABLE
CREATE SEQUENCE
ALTER SEQUENCE
ALTER TABLE
COPY 381
 setval 
-s-------
    381
(1 row)

ALTER TABLE
CREATE INDEX
```

![CRUS Obidos](crus-obidos.png)


## Restart the pygeo pods

Now that the PostgreSQL data contains the expected tables, restart the
pygeoapi pods:

    $ kubectl -n pygeoapi-demo rollout restart deployment pygeoapi
    deployment.apps/pygeoapi restarted

After a short while they should now be up and running:

    $ kubectl -n pygeoapi-demo get pods
    NAME                     READY   STATUS    RESTARTS   AGE
    postgresql-0             1/1     Running   0          8m50s
    pygeoapi-9d996dc-bmwpw   1/1     Running   0          32s
    pygeoapi-9d996dc-t4cm6   1/1     Running   0          32s

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

Reload ingress:

```
kubectl apply -f base/ingress-ssl.yml
```

## Reset

kubectl delete namespace pygeoapi-demo
namespace "pygeoapi-demo" deleted


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

Reload ingress:

```
kubectl apply -f base/ingress-ssl.yml
```

## Generate Diagrams

```
kubectl kustomize base | docker run -v "$(pwd)":/work -i philippemerle/kubediagrams kube-diagrams - -o diagram.png
```




## License

This project is released under a [MIT License](./LICENSE)

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)