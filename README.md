# k8s-cluster
## Introduction
This repository is an example how to deploy a managed kubernetes cluster with the Linode API and how to install an *app of apps* with Argo CD. All of this happens in an automated way, so development is easy and it is possible to repeat the process easily. All scripts are idempotent.

The initial goal was to have a working cluster with Argo CD as deployment tool and the following apps:

- Prometheus
- Grafana
- Airflow

The airflow chart is included in ./airflow.

## Prerequisits
You need a Linode account to spin up the cluster and have the linode-cli installed. If you have a running cluster, you can easily modify the setup to only look at the Argo CD part of the installation.

## Workflow
A typical workflow contains the following three steps:

1) Spin up a cluster and install all apps with Argo CD using 
```bash
    ./start.sh k8s-dev.yaml
```
2) Do some stuff with the running cluster.
3) Tear down the cluster and delete remaining volumes using
```bash
    ./stop.sh k8s-dev.yaml
```

If you are not sure if all (unattached) volumes have been deleted correctly, use `linode-cli volumes ls` to get an overwiev or run 
```bash
    ./cleanup_volumes.sh
```