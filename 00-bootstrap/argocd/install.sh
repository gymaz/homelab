#!/bin/bash

echo "🚀 Bootstrap ArgoCD Homelab"

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

sleep 10

k3d cluster create my-cluster --k3s-arg "--tls-san=192.168.1.98@server:*" -p "80:80@loadbalancer" -p "443:443@loadbalancer" --agents 1

echo "📦 Mise à jour des dépendances Helm ArgoCD..."
helm dependency update .
echo "5 seconds ⏳"
sleep 5

echo "🚀 Installing ArgoCD (étape 1/2)..."

# Installation ArgoCD uniquement
helm install argocd . --namespace argocd --create-namespace \
  -f values.yaml \
  -f ../../argocd-secret.yaml

echo "⏳ Waiting for ArgoCD components to be ready..."
kubectl wait --for=condition=available deployment/argocd-server -n argocd --timeout=600s
kubectl wait --for=condition=available deployment/argocd-repo-server -n argocd --timeout=600s
kubectl wait --for=condition=available deployment/argocd-applicationset-controller -n argocd --timeout=600s

echo "⏳ Waiting for ArgoCD initialization..."
sleep 45

echo "🚀 Deploying App-of-Apps (étape 2/2)..."

# Appliquer les Applications après que les CRDs soient prêtes
kubectl apply -f app-of-apps-manual.yaml

echo "🔍 Checking configuration..."
echo "=== Applications ArgoCD ==="
kubectl get applications -n argocd

echo "=== Repository Secrets ==="
kubectl get secrets -n argocd -l argocd.argoproj.io/secret-type=repository

echo "✅ Bootstrap complete!"
echo "👤 Admin password: $(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d 2>/dev/null || echo 'Secret not found')"

# Démarrer le port-forward
bash ../../port-forward.sh