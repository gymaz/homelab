#!/bin/bash
set -euo pipefail

VAULT_NAMESPACE="vault"
VAULT_POD="vault-0"

echo "🔐 Bootstrap Vault avec corrections..."

kubectl exec -it "$VAULT_POD" -n "$VAULT_NAMESPACE" -- sh -c '
set -e

# Configuration correcte pour l'\''adresse Vault
export VAULT_ADDR="http://vault-backend:8200"
export VAULT_SKIP_VERIFY=true

#echo "📡 Test de connectivité Vault..."
#if ! vault status >/dev/null 2>&1; then
#    echo "❌ Vault non accessible"
#    exit 1
#fi

# Alternative à openssl pour générer des mots de passe
generate_password() {
    local length=${1:-32}
    # Utiliser /dev/urandom avec tr (plus portable)
    head -c 48 /dev/urandom | base64 | tr -d "=+/" | cut -c1-$length 2>/dev/null || {
        # Fallback: utiliser date et hostname
        echo "$(date +%s)$(hostname)" | sha256sum | head -c $length
    }
}

echo "🧪 Test de génération de mot de passe..."
TEST_PASSWORD=$(generate_password 16)
echo "✅ Mot de passe test généré: $TEST_PASSWORD"

# Vérifier l'\''authentification
if ! vault token lookup >/dev/null 2>&1; then
    echo "❌ Pas de token Vault valide"
    echo "💡 Vous devez d'\''abord vous authentifier"
    exit 1
fi

echo "🎯 Création du secret Grafana..."
GRAFANA_ADMIN_PASSWORD=$(generate_password 32)

# Créer le secret avec vérification
if vault kv put secret/grafana admin-password="$GRAFANA_ADMIN_PASSWORD"; then
    echo "✅ Secret Grafana créé avec succès"
    echo "🔑 Mot de passe généré: $GRAFANA_ADMIN_PASSWORD"
else
    echo "❌ Échec de création du secret"
    exit 1
fi

echo "🔍 Vérification des secrets:"
vault kv list secret/
'

echo "✅ Bootstrap terminé!"