# k8s-cluster
## Steps to rebuild

1) Install argo-cd with helm.
```
helm install argo-cd charts/argo-cd/ -n argocd
```
2) Create root application (app of apps) with only root.yaml.
```
kubectl apply -f apps/templates/root.yaml
```
3) Now argo-cd is configured and synchronizes apps (app of apps). With argo-cd.yaml in apps/templates argo-cd also updates itself on change.