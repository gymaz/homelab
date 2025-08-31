#!/bin/bash

echo "Bootstrap ArgoCD Homelab"

#echo "Uninstall ArgoCD"
#helm uninstall argocd -n argocd || echo "Release Not Found"
#echo "10 seconds ⏳"
#sleep 10
#
#kubectl delete namespace argocd
#
#echo "🗑️ Suppression des CRD ArgoCD existantes..."
#kubectl delete crd -l app.kubernetes.io/part-of=argocd
#echo "10 seconds ⏳"
#sleep 10


k3d cluster delete my-cluster

echo "10 seconds ⏳"
sleep 10

k3d cluster create my-cluster --k3s-arg "--tls-san=192.168.1.98@server:*" -p "80:80@loadbalancer" -p "443:443@loadbalancer" --agents 1

echo "📦 Mise à jour des dépendances Helm ArgoCD & Installing ArgoCD (étape 1/2)..."
helm dependency update . && \
helm install argocd . --namespace argocd --create-namespace \
  -f values.yaml \
  -f ../../my-secrets-values.yaml


echo "⏳ Waiting for ArgoCD components to be ready..."
kubectl wait --for=condition=available deployment/argocd-server -n argocd --timeout=300s
kubectl wait --for=condition=available deployment/argocd-repo-server -n argocd --timeout=300s
kubectl wait --for=condition=available deployment/argocd-applicationset-controller -n argocd --timeout=300s

echo "⏳ Waiting for ArgoCD initialization..."
echo "30 seconds ⏳"
sleep 30

echo "🚀 Deploying App-of-Apps (étape 2/2)..."

# Appliquer les Applications après que les CRDs soient prêtes
kubectl apply -f app-of-apps-manual.yaml

echo "🔍 Checking configuration..."
echo "=== Checking Repository Secrets ==="
kubectl get secrets -n argocd -l argocd.argoproj.io/secret-type=repository

echo "✅ Bootstrap complete!"
echo "👤 ArgoCD Admin password: $(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d 2>/dev/null || echo 'Secret not found')"

echo " Waiting for ArgoCD to synchronize and then bootstrap Vault and Secrets creation"
echo "300 seconds ⏳"
sleep 300

bash ../vault/vault_bootstrap.sh

# Démarrer le port-forward
bash ../../port-forward.sh