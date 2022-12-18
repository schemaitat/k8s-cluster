#!/bin/bash
kubectl port-forward svc/argo-cd-argocd-server 8001:443 -n argocd