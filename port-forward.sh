#!/bin/bash
trap killgroup SIGINT

killgroup(){
  echo "Killing $PID_ARGO !"
  kill -INT $PID_ARGO
  echo "Killing $PID_FLOWER !"
  kill -INT $PID_FLOWER
  exit
}

kubectl port-forward svc/argo-cd-argocd-server 8001:443 -n argocd &
PID_ARGO=$!
kubectl port-forward svc/airflow-flower 8003:5555 -n airflow &
PID_FLOWER=$!
kubectl port-forward svc/airflow-web 8002:8080 -n airflow
# wait