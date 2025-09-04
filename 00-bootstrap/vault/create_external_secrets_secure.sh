#!/bin/bash
set -euo pipefail

VAULT_NAMESPACE="vault"
VAULT_POD="vault-0"

# Méthodes pour récupérer le token root (par ordre de priorité)
get_root_token() {
    # 1. Variable d'environnement (pour CI/CD)
    if [ ! -z "${VAULT_ROOT_TOKEN:-}" ]; then
        echo "✅ Token root récupéré depuis la variable d'environnement"
        echo "$VAULT_ROOT_TOKEN"
        return 0
    fi
    
    # 2. Secret Kubernetes (si créé par le bootstrap)
    if kubectl get secret vault-root-credentials -n vault >/dev/null 2>&1; then
        echo "✅ Token root récupéré depuis le secret Kubernetes"
        kubectl get secret vault-root-credentials -n vault -o jsonpath='{.data.root-token}' | base64 -d
        return 0
    fi
    
    # 3. Fichier de credentials local
    local credentials_file="../../vault-credentials.txt"
    if [ -f "$credentials_file" ]; then
        local token=$(grep "Root Token:" "$credentials_file" | awk '{print $3}')
        if [ ! -z "$token" ]; then
            echo "✅ Token root récupéré depuis $credentials_file"
            echo "$token"
            return 0
        fi
    fi
    
    # 4. Demander à l'utilisateur en interactif
    echo "❌ Aucun token root trouvé automatiquement"
    echo "💡 Sources vérifiées:"
    echo "   - Variable d'environnement VAULT_ROOT_TOKEN"
    echo "   - Secret Kubernetes vault-root-credentials"
    echo "   - Fichier ../../vault-credentials.txt"
    echo ""
    read -p "🔑 Veuillez saisir le token root Vault: " token
    echo "$token"
}

# Récupérer le token root
ROOT_TOKEN=$(get_root_token)

if [ -z "$ROOT_TOKEN" ]; then
    echo "❌ Impossible de récupérer le token root"
    exit 1
fi

echo "🔐 Création des secrets Kubernetes pour External Secrets..."

echo "📝 Création de la policy external-secrets..."
kubectl exec "$VAULT_POD" -n "$VAULT_NAMESPACE" -- sh -c "
    export VAULT_ADDR=\"http://vault:8200\"
    export VAULT_SKIP_VERIFY=true
    export VAULT_TOKEN=\"$ROOT_TOKEN\"
    
    vault policy write external-secrets - <<EOF
path \"secret/data/*\" {
  capabilities = [\"read\"]
}
path \"secret/metadata/*\" {
  capabilities = [\"list\", \"read\"]
}
EOF
"

echo "🔑 Création du token pour External Secrets..."

# Créer le token et capturer la sortie
TOKEN_CREATION_OUTPUT=$(kubectl exec "$VAULT_POD" -n "$VAULT_NAMESPACE" -- sh -c "
    export VAULT_ADDR=\"http://vault:8200\"
    export VAULT_SKIP_VERIFY=true  
    export VAULT_TOKEN=\"$ROOT_TOKEN\"
    
    vault token create -policy=external-secrets -ttl=8760h
" 2>&1)

echo "Sortie de la création de token:"
echo "$TOKEN_CREATION_OUTPUT"

# Extraire le token de la sortie texte
EXTERNAL_SECRETS_TOKEN=$(echo "$TOKEN_CREATION_OUTPUT" | grep "token " | head -1 | awk '{print $2}')

if [ ! -z "$EXTERNAL_SECRETS_TOKEN" ] && [ "$EXTERNAL_SECRETS_TOKEN" != "" ]; then
    echo "✅ Token extrait: ${EXTERNAL_SECRETS_TOKEN:0:20}..."
    
    echo "📦 Création du secret vault-token dans le namespace default..."
    kubectl create secret generic vault-token \
      --from-literal=token="$EXTERNAL_SECRETS_TOKEN" \
      -n default \
      --dry-run=client -o yaml | kubectl apply -f -
    
    echo "✅ Secret vault-token créé avec succès"
    
    # Créer aussi un secret avec le root token pour l'automatisation
    echo "📦 Création du secret vault-root-credentials pour l'automatisation..."
    kubectl create secret generic vault-root-credentials \
      --from-literal=root-token="$ROOT_TOKEN" \
      -n vault \
      --dry-run=client -o yaml | kubectl apply -f -
    
    echo "✅ Secret vault-root-credentials créé"
    
    echo ""
    echo "🎯 Configuration External Secrets terminée !"
    echo ""
    echo "🔍 Vérification:"
    echo "kubectl get secret vault-token -n default"
    echo "kubectl describe clustersecretstore vault-backend"
    
else
    echo "❌ Impossible d'extraire le token"
    echo "🔄 Utilisation du root token comme fallback..."
    
    kubectl create secret generic vault-token \
      --from-literal=token="$ROOT_TOKEN" \
      -n default \
      --dry-run=client -o yaml | kubectl apply -f -
    
    echo "⚠️  Secret vault-token créé avec le root token (changez cela en production!)"
fi
