# Applications

Répertoire contenant les applications métier déployées sur le cluster Kubernetes.

## Applications disponibles

### sre-challenge-src/
Application microservices basée sur Spring Boot avec:
- Architecture event-driven (Kafka)
- Base de données PostgreSQL
- 3 services : Front, Back, Reader

## Déploiement

Les applications sont déployées via ArgoCD. Pour ajouter une nouvelle application:

1. Créer un nouveau dossier avec les manifests Kubernetes ou charts Helm
2. Ajouter une référence dans `/01-argocd-apps/`
3. Commit et push - ArgoCD synchronisera automatiquement

## Structure recommandée

```
app-name/
├── charts/           # Charts Helm
├── manifests/        # Manifests Kubernetes
├── config/           # Configurations
└── README.md         # Documentation
```

## Configuration

Chaque application doit inclure:
- ConfigMaps pour la configuration
- Secrets pour les données sensibles
- Service et Ingress pour l'exposition
- Health checks et readiness probes

## Monitoring

Les applications doivent exposer:
- Métriques Prometheus sur `/metrics`
- Endpoints de santé sur `/health`

## Standards

- Utiliser des labels Kubernetes cohérents
- Implémenter la gestion gracieuse des arrêts
- Définir des limites de ressources appropriées
- Documenter les dépendances externes
