# Vault Bootstrap Scripts

Ce dossier contient les scripts pour initialiser et configurer Vault dans votre homelab.

## Scripts disponibles

### `vault_bootstrap.sh`
Script principal pour initialiser Vault complet :
- Initialisation de Vault
- Unsealing automatique  
- Configuration des secrets engines
- Création des secrets Kubernetes pour External Secrets

### `create_external_secrets_secure.sh`
Script standalone pour créer les secrets External Secrets uniquement.

**⚠️ Sécurité** : Ce script récupère automatiquement le token root sans le stocker en dur dans le code.

## Utilisation

### Première installation
```bash
# 1. Déployer Vault via ArgoCD d'abord
# 2. Exécuter le bootstrap complet
./vault_bootstrap.sh
```

### Recréer les secrets External Secrets uniquement
```bash
# Méthode 1: Automatique (si vault-credentials.txt existe)
./create_external_secrets_secure.sh

# Méthode 2: Avec variable d'environnement  
export VAULT_ROOT_TOKEN="hvs.xxxxxxxxxxxxx"
./create_external_secrets_secure.sh

# Méthode 3: Interactif (le script demande le token)
./create_external_secrets_secure.sh
```

## Fichiers générés

- `vault-credentials.txt` : Contient les tokens et clés (gitignored)
- Secrets Kubernetes :
  - `vault-token` (namespace: default) : Token pour External Secrets
  - `vault-root-credentials` (namespace: vault) : Token root pour automatisation

## Vérification

```bash
# Vérifier que Vault fonctionne
kubectl get clustersecretstore vault-backend

# Tester External Secrets
kubectl get externalsecrets -A
```

## Sécurité

🔒 **Bonnes pratiques appliquées** :
- Aucun secret en dur dans le code
- Tokens automatiquement récupérés
- Policies avec permissions minimales
- Rotation des tokens configurée

⚠️ **À faire en production** :
- Utiliser l'authentification Kubernetes au lieu de tokens
- Configurer l'auto-unseal avec un KMS
- Activer l'audit logging
- Utiliser des certificats TLS
