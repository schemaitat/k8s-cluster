#!/bin/bash
kubectl port-forward svc/argo-cd-argocd-server 8080:443 -n argocd &
echo "PID: $!"