#!/bin/bash
set -euo pipefail

VAULT_NAMESPACE="vault"
VAULT_POD="vault-0"

# Méthodes pour récupérer le token root (par ordre de priorité)
get_root_token() {
    # 1. Variable d'environnement (pour CI/CD)
    if [ ! -z "${VAULT_ROOT_TOKEN:-}" ]; then
        echo "✅ Token root récupéré depuis la variable d'environnement" >&2
        echo "$VAULT_ROOT_TOKEN"
        return 0
    fi
    
    # 2. Secret Kubernetes (si créé par le bootstrap)
    if kubectl get secret vault-root-credentials -n vault >/dev/null 2>&1; then
        echo "✅ Token root récupéré depuis le secret Kubernetes" >&2
        kubectl get secret vault-root-credentials -n vault -o jsonpath='{.data.root-token}' | base64 -d
        return 0
    fi
    
    # 3. Fichier de credentials local
    local credentials_file="../../vault-credentials.txt"
    if [ -f "$credentials_file" ]; then
        # Méthode plus robuste pour extraire le token
        local token=$(grep "Root Token:" "$credentials_file" | sed 's/.*Root Token: *//' | tr -d '\r\n\t ')
        if [ ! -z "$token" ] && [[ "$token" =~ ^hvs\. ]]; then
            echo "✅ Token root récupéré depuis $credentials_file" >&2
            echo "$token"
            return 0
        else
            echo "⚠️  Token invalide dans $credentials_file (ne commence pas par hvs.)" >&2
        fi
    fi
    
    # 4. Demander à l'utilisateur en interactif
    echo "❌ Aucun token root trouvé automatiquement" >&2
    echo "💡 Sources vérifiées:" >&2
    echo "   - Variable d'environnement VAULT_ROOT_TOKEN" >&2
    echo "   - Secret Kubernetes vault-root-credentials" >&2
    echo "   - Fichier ../../vault-credentials.txt" >&2
    echo "" >&2
    read -p "🔑 Veuillez saisir le token root Vault: " token
    echo "$token"
}

# Récupérer le token root
ROOT_TOKEN=$(get_root_token)

# Vérifier que le token est valide
if [ -z "$ROOT_TOKEN" ] || [[ ! "$ROOT_TOKEN" =~ ^hvs\. ]]; then
    echo "❌ Token root invalide ou manquant"
    echo "🔍 Token reçu: '$ROOT_TOKEN'"
    exit 1
fi

echo "🔍 Debug: Token length = ${#ROOT_TOKEN}"
echo "🔍 Debug: Token preview = ${ROOT_TOKEN:0:10}..."

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
