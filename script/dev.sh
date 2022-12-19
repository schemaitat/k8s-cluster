#!/bin/bash
trap killgroup SIGINT

killgroup(){
  echo "Killing $PID_ARGO !"
  kill -INT $PID_ARGO
  exit
}

kubectl port-forward svc/argo-cd-argocd-server 8001:443 -n argocd &
PID_ARGO=$!
kubectl port-forward svc/airflow-web 8002:8080 -n airflow
# wait