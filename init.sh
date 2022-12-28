#!/bin/bash


helm dep update charts/argo-cd
helm dep update airflow

namespaces="argocd monitoring airflow"
for ns in $namespaces; do
    kubectl create ns $ns
done

helm install argo-cd charts/argo-cd/ -n argocd
kubectl apply -f apps/templats/root.yaml