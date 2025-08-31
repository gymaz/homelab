# Homelab - Infrastructure Kubernetes GitOps

Infrastructure complète pour un cluster Kubernetes géré avec ArgoCD suivant les principes GitOps.

## Architecture

Le projet suit une structure en couches pour organiser les déploiements:

```
00-bootstrap/     # Bootstrap ArgoCD et configuration initiale
01-argocd-apps/   # Définitions des applications ArgoCD
02-infrastructure/ # Services d'infrastructure (secrets, vault, etc.)
03-platform/      # Services de plateforme (monitoring, CI/CD)
04-applications/  # Applications métier
```

## Prérequis

- k3d
- kubectl
- helm 3.x
- argoCD CLI

## Installation

### 0. Configurer ses secrets Github

```bash
cp my-secret-values-templates.yaml my-secrets-values.yaml
```
Et modifier les valeurs username & token par ses credentials Github

### 1. Bootstrap Cluster K3s + ArgoCD + ArgoCD Apps

```bash
cd 00-bootstrap/argocd
bash install.sh
```

### 2. Editer le fichier host

```bash
127.0.0.1 grafana.homelab.local
127.0.0.1 prometheus.homelab.local
127.0.0.1 alertmanager.homelab.local
127.0.0.1 core.harbor.homelab.local
127.0.0.1 argocd.homelab.local
127.0.0.1 vault.homelab.local

```

### 2.1 Lancer le script Port-Forward ou accès direct via les Ingress

```bash
cd homelab
bash port-forward.sh

```

### 3. Accès à ArgoCD

```bash
# Récupérer le mot de passe admin
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

```

## Structure des dossiers

### 00-bootstrap
Configuration initiale d'ArgoCD et des familles d'applications ArgoCD.

### 01-argocd-apps
Définitions des applications ArgoCD (App of Apps pattern).

### 02-infrastructure
- Secrets, vault

### 03-platform
- **cicd/** : Harbor pour le registry Docker
- **monitoring/** : Prometheus et Grafana

### 04-applications
Applications métier provenant du repository Github SRE-Challenge.

## Configuration

Les configurations sont centralisées dans les fichiers `values.yaml` de chaque composant.

## Monitoring

- **Prometheus** : Métriques et alertes
- **Grafana** : Tableaux de bord et visualisation

## CI/CD

- **Harbor** : Registry Docker privé

## Maintenance

Pour mettre à jour les applications:
1. Modifier le code/values
2. Commit/Push sur develop
2. ArgoCD synchronise automatiquement les changements

## Troubleshooting

```bash
# Vérifier le statut des applications
kubectl get applications -n argocd

# Logs ArgoCD
kubectl logs -n argocd deployment/argocd-server

# Forcer la synchronisation
argocd app sync <app-name>
```

## Sécurité

- Les secrets Github sont stockés dans `my-secrets-values.yaml` (non commité)
- Utiliser External Secrets

## Contribution

1. Créer une branche feature
2. Tester les changements localement
3. Soumettre une PR avec description détaillée

## TODO

- Finaliser l'intégration de Vault/External Secrets
- Gérer le secret argocd/github (base64 encoded!)
- Intégrer un Runner Github
- Builder les images du projet SRE-Challenge
- Faire le lien Github Action/ArgoCD
- Intégrer des tests de charge Grafana K6
- Intégrer Loki
- Créer des alertes AlertManager