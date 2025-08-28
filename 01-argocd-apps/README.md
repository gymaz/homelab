# ArgoCD Applications

Ce répertoire contient les définitions des applications ArgoCD suivant le pattern "App of Apps".

## Structure

- **infrastructure-apps.yaml** : Applications d'infrastructure (secrets, vault)
- **platform-apps.yaml** : Applications de plateforme (monitoring, CI/CD)
- **values.yaml** : Configuration partagée

## Pattern App of Apps

Le pattern App of Apps permet de gérer plusieurs applications ArgoCD depuis une application parent. Cela facilite:
- Le déploiement groupé d'applications
- La gestion des dépendances
- La synchronisation coordonnée

## Utilisation

### Déployer toutes les applications

```bash
# Applications d'infrastructure
kubectl apply -f infrastructure-apps.yaml

# Applications de plateforme
kubectl apply -f platform-apps.yaml
```

### Vérifier le statut

```bash
kubectl get applications -n argocd
```

## Configuration

Modifier `values.yaml` pour personnaliser:
- Les namespaces cibles
- Les chemins Git
- Les paramètres de synchronisation

## Synchronisation

Les applications sont configurées pour:
- Auto-sync : Synchronisation automatique avec Git
- Self-heal : Correction automatique des dérives
- Prune : Suppression des ressources orphelines
