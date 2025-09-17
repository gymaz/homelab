#!/bin/bash
set -euo pipefail

VAULT_NAMESPACE="vault"
VAULT_POD="vault-0"
VAULT_KEYS_FILE="/tmp/vault-keys.json"

echo "🚀 Bootstrap Vault complet - Init, Unseal, Auth & Secrets"

# Fonction pour attendre que le pod soit ready
#wait_for_pod() {
#    echo "⏳ Attente que le pod vault-0 soit prêt..."
#    kubectl wait --for=condition=ready pod/$VAULT_POD -n $VAULT_NAMESPACE --timeout=300s
#}

# Fonction pour vérifier si Vault est initialisé
is_vault_initialized() {
    kubectl exec "$VAULT_POD" -n "$VAULT_NAMESPACE" -- sh -c '
        export VAULT_ADDR="http://vault:8200"
        export VAULT_SKIP_VERIFY=true
        vault status -format=json 2>/dev/null | jq -r ".initialized // false"
    ' 2>/dev/null || echo "false"
}

# Fonction pour vérifier si Vault est unsealed
is_vault_unsealed() {
    kubectl exec "$VAULT_POD" -n "$VAULT_NAMESPACE" -- sh -c '
        export VAULT_ADDR="http://vault:8200"
        export VAULT_SKIP_VERIFY=true
        vault status -format=json 2>/dev/null | jq -r ".sealed // true"
    ' 2>/dev/null || echo "true"
}

## Attendre que le pod soit prêt
#wait_for_pod

# Étape 1: Vérifier l'état de Vault
echo "🔍 Vérification de l'état de Vault..."
INITIALIZED=$(is_vault_initialized)
SEALED=$(is_vault_unsealed)

echo "   - Initialisé: $INITIALIZED"
echo "   - Scellé: $SEALED"

# Étape 2: Initialiser Vault si nécessaire
if [ "$INITIALIZED" = "false" ]; then
    echo "🔧 Initialisation de Vault..."
    kubectl exec "$VAULT_POD" -n "$VAULT_NAMESPACE" -- sh -c '
        export VAULT_ADDR="http://vault:8200"
        export VAULT_SKIP_VERIFY=true
        vault operator init -format=json
    ' > "$VAULT_KEYS_FILE"
    
    echo "✅ Vault initialisé - Clés sauvegardées dans $VAULT_KEYS_FILE"
    
    # Extraire les informations importantes
    ROOT_TOKEN=$(jq -r '.root_token' "$VAULT_KEYS_FILE")
    UNSEAL_KEY_1=$(jq -r '.unseal_keys_b64[0]' "$VAULT_KEYS_FILE")
    UNSEAL_KEY_2=$(jq -r '.unseal_keys_b64[1]' "$VAULT_KEYS_FILE")
    UNSEAL_KEY_3=$(jq -r '.unseal_keys_b64[2]' "$VAULT_KEYS_FILE")
    UNSEAL_KEY_4=$(jq -r '.unseal_keys_b64[3]' "$VAULT_KEYS_FILE")
    UNSEAL_KEY_5=$(jq -r '.unseal_keys_b64[4]' "$VAULT_KEYS_FILE")

    echo "🔑 Token root: $ROOT_TOKEN"
    echo "🗝️  Clés d'unsealing sauvegardées"
    
else
    echo "ℹ️  Vault déjà initialisé"
    
    # Demander les clés si le fichier n'existe pas
    if [ ! -f "$VAULT_KEYS_FILE" ]; then
        echo "❌ Fichier de clés non trouvé. Vous devez fournir les clés manuellement:"
        read -p "Token root: " ROOT_TOKEN
        read -p "Clé unseal 1: " UNSEAL_KEY_1  
        read -p "Clé unseal 2: " UNSEAL_KEY_2
        read -p "Clé unseal 3: " UNSEAL_KEY_3
        read -p "Clé unseal 4: " UNSEAL_KEY_4
        read -p "Clé unseal 5: " UNSEAL_KEY_5
    else
        ROOT_TOKEN=$(jq -r '.root_token' "$VAULT_KEYS_FILE")
        UNSEAL_KEY_1=$(jq -r '.unseal_keys_b64[0]' "$VAULT_KEYS_FILE")
        UNSEAL_KEY_2=$(jq -r '.unseal_keys_b64[1]' "$VAULT_KEYS_FILE")
        UNSEAL_KEY_3=$(jq -r '.unseal_keys_b64[2]' "$VAULT_KEYS_FILE")
        UNSEAL_KEY_4=$(jq -r '.unseal_keys_b64[3]' "$VAULT_KEYS_FILE")
        UNSEAL_KEY_5=$(jq -r '.unseal_keys_b64[4]' "$VAULT_KEYS_FILE")
    fi
fi

# Étape 3: Unsealer Vault si nécessaire
if [ "$SEALED" = "true" ]; then
    echo "🔓 Unsealing de Vault..."
    
    kubectl exec "$VAULT_POD" -n "$VAULT_NAMESPACE" -- sh -c "
        export VAULT_ADDR=\"http://vault:8200\"
        export VAULT_SKIP_VERIFY=true
        vault operator unseal $UNSEAL_KEY_1
        vault operator unseal $UNSEAL_KEY_2  
        vault operator unseal $UNSEAL_KEY_3
    "
    
    echo "✅ Vault unsealed"
else
    echo "ℹ️  Vault déjà unsealed"
fi

# Étape 4: Authentification et activation des secrets engines
echo "🔐 Authentification et configuration..."
kubectl exec "$VAULT_POD" -n "$VAULT_NAMESPACE" -- sh -c "
    export VAULT_ADDR=\"http://vault:8200\"
    export VAULT_SKIP_VERIFY=true
    export VAULT_TOKEN=\"$ROOT_TOKEN\"
    
    echo \"✅ Authentifié avec le token root\"
    
    # Vérifier si le KV engine existe déjà
    if ! vault secrets list | grep -q 'secret/'; then
        echo \"🔧 Activation du secrets engine KV...\"
        vault secrets enable -path=secret kv-v2
        echo \"✅ KV secrets engine activé\"
    else
        echo \"ℹ️  KV secrets engine déjà activé\"
    fi
    
    # Vérifier l'état
    vault status
"

# Étape 5: Créer les secrets
echo "🗝️  Création des secrets..."

kubectl exec "$VAULT_POD" -n "$VAULT_NAMESPACE" -- sh -c "
    export VAULT_ADDR=\"http://vault:8200\"
    export VAULT_SKIP_VERIFY=true
    export VAULT_TOKEN=\"$ROOT_TOKEN\"

    generate_password() {
        local length=\${1:-32}
        head -c 48 /dev/urandom | base64 | tr -d \"=+/\" | cut -c1-\$length 2>/dev/null || {
            echo \"\$(date +%s)\$(hostname)\" | sha256sum | head -c \$length
        }
    }

    echo \"📝 Création du secret Grafana...\"
    GRAFANA_ADMIN_PASSWORD=\$(generate_password 32)

    if vault kv put secret/grafana admin-password=\"\$GRAFANA_ADMIN_PASSWORD\"; then
        echo \"✅ Secret Grafana créé avec succès\"
        echo \"🔑 Mot de passe Grafana: \$GRAFANA_ADMIN_PASSWORD\"
    else
        echo \"❌ Échec de création du secret Grafana\"
        exit 1
    fi

    echo \"🔍 Vérification des secrets:\"
    vault kv list secret/
"

# Étape 6: Sauvegarder les informations importantes
echo "💾 Sauvegarde des informations de connexion..."
cat > ../../vault-credentials.txt << EOF
=== INFORMATIONS DE CONNEXION VAULT ===
Date: $(date)

Root Token: $ROOT_TOKEN

Clés d'unsealing:
- Clé 1: $UNSEAL_KEY_1  
- Clé 2: $UNSEAL_KEY_2
- Clé 3: $UNSEAL_KEY_3
- Clé 4: $UNSEAL_KEY_4
- Clé 5: $UNSEAL_KEY_5

=== COMMANDES UTILES ===
# Port-forward pour accès local:
kubectl port-forward svc/vault 8200:8200 -n vault

# Accès UI:
https://localhost:8200

# Login avec token root dans l'UI
EOF
# Étape 7: Créer les secrets Kubernetes pour External Secrets
echo "🔐 Création des secrets Kubernetes pour External Secrets..."

# Créer une policy dédiée pour External Secrets
kubectl exec "$VAULT_POD" -n "$VAULT_NAMESPACE" -- sh -c "
    export VAULT_ADDR=\"http://vault:8200\"
    export VAULT_SKIP_VERIFY=true
    export VAULT_TOKEN=\"$ROOT_TOKEN\"

    echo \"📝 Création de la policy external-secrets...\"
    vault policy write external-secrets - <<EOF
path \"secret/data/*\" {
  capabilities = [\"read\"]
}
path \"secret/metadata/*\" {
  capabilities = [\"list\", \"read\"]
}
EOF

    echo \"🔑 Création du token pour External Secrets...\"
    vault token create -policy=external-secrets -ttl=8760h -format=json
" > /tmp/external-secrets-token.json

# Extraire le token
EXTERNAL_SECRETS_TOKEN=$(jq -r '.auth.client_token' /tmp/external-secrets-token.json)

# Créer le secret Kubernetes dans le namespace default
echo "📦 Création du secret vault-token dans le namespace default..."
kubectl create secret generic vault-token \
  --from-literal=token="$EXTERNAL_SECRETS_TOKEN" \
  -n default \
  --dry-run=client -o yaml | kubectl apply -f -

echo "✅ Secret vault-token créé avec succès"

# Nettoyer
rm -f /tmp/external-secrets-token.json

echo ""
echo "🎯 Configuration External Secrets terminée !"
echo "✅ Informations sauvegardées dans vault-credentials.txt"

# Étape 7: Créer les secrets Kubernetes pour External Secrets
echo "🔐 Création des secrets Kubernetes pour External Secrets..."

# S'assurer d'utiliser le bon token root (le plus récent)
if [ -f "../../vault-credentials.txt" ]; then
    CURRENT_ROOT_TOKEN=$(grep "Root Token:" ../../vault-credentials.txt | awk '{print $3}')
    if [ ! -z "$CURRENT_ROOT_TOKEN" ]; then
        ROOT_TOKEN="$CURRENT_ROOT_TOKEN"
        echo "✅ Token root mis à jour depuis vault-credentials.txt"
    fi
fi

# Attendre un peu pour s'assurer que Vault est complètement prêt
sleep 5

# Créer une policy dédiée pour External Secrets
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
# Méthode alternative : capturer la sortie complète et parser manuellement
TOKEN_CREATION_OUTPUT=$(kubectl exec "$VAULT_POD" -n "$VAULT_NAMESPACE" -- sh -c "
    export VAULT_ADDR=\"http://vault:8200\"
    export VAULT_SKIP_VERIFY=true  
    export VAULT_TOKEN=\"$ROOT_TOKEN\"
    
    # Créer le token sans format JSON pour éviter les problèmes de parsing
    vault token create -policy=external-secrets -ttl=8760h
" 2>&1)

echo "Sortie de la création de token:"
echo "$TOKEN_CREATION_OUTPUT"

# Extraire le token de la sortie texte (format standard de Vault)
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
    
else
    echo "❌ Impossible d'extraire le token"
    echo "🔄 Utilisation du root token comme fallback..."
    
    kubectl create secret generic vault-token \
      --from-literal=token="$ROOT_TOKEN" \
      -n default \
      --dry-run=client -o yaml | kubectl apply -f -
    
    echo "⚠️  Secret vault-token créé avec le root token (changez cela en production!)"
fi
echo "🎉 Bootstrap Vault terminé avec succès!"
echo ""
echo "📋 Prochaines étapes:"
echo "   1. Consultez vault-credentials.txt pour les informations de connexion"
echo "   2. Vérifiez que le ClusterSecretStore fonctionne: kubectl describe clustersecretstore vault-backend"
echo "   3. Accédez à https://localhost:8200"
echo "   4. Connectez-vous avec le token root"
echo ""
echo "🔄 Pour recréer complètement:"
echo "   - Supprimez le namespace: kubectl delete namespace vault"
echo "   - Supprimez les fichiers temporaires: rm -f $VAULT_KEYS_FILE vault-credentials.txt"
echo "   - Relancez ce script"