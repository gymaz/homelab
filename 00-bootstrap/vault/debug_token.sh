#!/bin/bash

echo "🔍 Debug du token Vault"

# Méthode 1: awk (ancienne)
echo "=== Méthode 1: awk ==="
TOKEN_AWK=$(grep "Root Token:" ../../vault-credentials.txt | awk '{print $3}')
echo "Token avec awk: '$TOKEN_AWK'"
echo "Longueur: ${#TOKEN_AWK}"

# Méthode 2: sed (nouvelle)
echo "\n=== Méthode 2: sed ==="
TOKEN_SED=$(grep "Root Token:" ../../vault-credentials.txt | sed 's/.*Root Token: *//' | tr -d '\r\n\t ')
echo "Token avec sed: '$TOKEN_SED'"
echo "Longueur: ${#TOKEN_SED}"

echo "\n=== Validation ==="
if [[ "$TOKEN_SED" =~ ^hvs\. ]]; then
    echo "✅ Token sed valide (commence par hvs.)"
else
    echo "❌ Token sed invalide"
fi

if [[ "$TOKEN_AWK" =~ ^hvs\. ]]; then
    echo "✅ Token awk valide (commence par hvs.)"
else
    echo "❌ Token awk invalide"
fi

echo "\n=== Contenu du fichier ==="
echo "Ligne avec Root Token:"
grep "Root Token:" ../../vault-credentials.txt | cat -A
