#!/bin/bash

port_forward() {
    echo "Starting port-forward for $1..."
    kubectl port-forward $2 -n $3 $4 &
    sleep 2
}

port_forward "Grafana" "svc/grafana" "grafana" "8081:80"
port_forward "ArgoCD" "svc/argocd-server" "argocd" "30443:443"
port_forward "AlertManager" "svc/prometheus-alertmanager" "prometheus" "9093:9093"
port_forward "Prometheus Server" "svc/prometheus-server" "prometheus" "8082:80"
port_forward "Harbor UI" "svc/harbor-portal" "harbor" "8083:80"
port_forward "Vault" "svc/vault" "vault" "8200:8200"

echo "All port-forwards started. Press Ctrl+C to stop all."
wait