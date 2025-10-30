#!/bin/bash
################################################################################
# EasyPay Application Deployment Script
# Description: Deploys the complete EasyPay application to Kubernetes
# Version: 1.0
################################################################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
NAMESPACE="easypay"
KUBECTL="kubectl"

# Functions
print_header() {
    echo -e "${BLUE}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║${NC}  $1"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════════╝${NC}"
}

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_prerequisites() {
    print_header "Checking Prerequisites"
    
    # Check kubectl
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl is not installed"
        exit 1
    fi
    log_info "kubectl: $(kubectl version --client --short)"
    
    # Check cluster connectivity
    if ! kubectl cluster-info &> /dev/null; then
        log_error "Cannot connect to Kubernetes cluster"
        exit 1
    fi
    log_info "Kubernetes cluster: Connected"
    
    # Check if running as correct user
    log_info "Current context: $(kubectl config current-context)"
}

create_namespace() {
    print_header "Creating Namespace"
    
    if kubectl get namespace $NAMESPACE &> /dev/null; then
        log_warn "Namespace $NAMESPACE already exists"
    else
        kubectl create namespace $NAMESPACE
        log_info "Namespace $NAMESPACE created"
    fi
    
    kubectl label namespace $NAMESPACE name=$NAMESPACE --overwrite
}

deploy_database() {
    print_header "Deploying Database"
    
    log_info "Applying database StatefulSet..."
    kubectl apply -f kubernetes/database-statefulset.yaml
    
    log_info "Waiting for database pod to be ready..."
    kubectl wait --for=condition=ready pod -l app=database -n $NAMESPACE --timeout=300s
    
    log_info "Database deployed successfully"
    
    # Display database pod
    kubectl get pods -n $NAMESPACE -l app=database
}

deploy_backend() {
    print_header "Deploying Backend Application"
    
    log_info "Applying backend deployment..."
    kubectl apply -f kubernetes/backend-deployment.yaml
    
    log_info "Waiting for backend pods to be ready..."
    kubectl wait --for=condition=ready pod -l app=backend -n $NAMESPACE --timeout=300s
    
    log_info "Backend deployed successfully"
    
    # Display backend pods
    kubectl get pods -n $NAMESPACE -l app=backend
}

deploy_frontend() {
    print_header "Deploying Frontend Application"
    
    log_info "Applying frontend deployment..."
    kubectl apply -f kubernetes/frontend-deployment.yaml
    
    log_info "Waiting for frontend pods to be ready..."
    kubectl wait --for=condition=ready pod -l app=frontend -n $NAMESPACE --timeout=300s
    
    log_info "Frontend deployed successfully"
    
    # Display frontend pods
    kubectl get pods -n $NAMESPACE -l app=frontend
}

deploy_network_policies() {
    print_header "Deploying Network Policies"
    
    log_info "Applying network policies..."
    kubectl apply -f kubernetes/network-policy.yaml
    
    log_info "Network policies deployed successfully"
    
    # Display network policies
    kubectl get networkpolicies -n $NAMESPACE
}

deploy_rbac() {
    print_header "Deploying RBAC Configuration"
    
    log_info "Applying RBAC resources..."
    kubectl apply -f kubernetes/rbac-user.yaml
    
    log_info "RBAC configured successfully"
    
    # Display RBAC resources
    kubectl get serviceaccounts,roles,rolebindings -n $NAMESPACE
}

deploy_autoscaling() {
    print_header "Deploying Auto-scaling Configuration"
    
    log_info "Applying HPA resources..."
    kubectl apply -f kubernetes/hpa-autoscaling.yaml
    
    log_info "Waiting for metrics-server to be ready..."
    kubectl wait --for=condition=ready pod -l k8s-app=metrics-server -n kube-system --timeout=180s || log_warn "Metrics server may not be ready yet"
    
    log_info "Auto-scaling configured successfully"
    
    # Display HPA status
    kubectl get hpa -n $NAMESPACE
}

verify_deployment() {
    print_header "Verifying Deployment"
    
    log_info "Checking all pods..."
    kubectl get pods -n $NAMESPACE -o wide
    
    log_info "Checking all services..."
    kubectl get services -n $NAMESPACE
    
    log_info "Checking deployments..."
    kubectl get deployments -n $NAMESPACE
    
    log_info "Checking StatefulSets..."
    kubectl get statefulsets -n $NAMESPACE
    
    # Check pod status
    log_info "Checking pod readiness..."
    NOT_READY=$(kubectl get pods -n $NAMESPACE --no-headers | grep -v "Running\|Completed" | wc -l)
    
    if [ $NOT_READY -eq 0 ]; then
        log_info "✓ All pods are running"
    else
        log_warn "⚠ Some pods are not ready yet"
    fi
}

test_connectivity() {
    print_header "Testing Application Connectivity"
    
    log_info "Testing database connectivity from backend..."
    BACKEND_POD=$(kubectl get pod -n $NAMESPACE -l app=backend -o jsonpath="{.items[0].metadata.name}")
    
    if kubectl exec $BACKEND_POD -n $NAMESPACE -- nc -zv easypay-database 5432 &> /dev/null; then
        log_info "✓ Backend can connect to database"
    else
        log_warn "⚠ Backend cannot connect to database"
    fi
    
    log_info "Testing backend health endpoint..."
    if kubectl exec $BACKEND_POD -n $NAMESPACE -- curl -s http://localhost:8080/health | grep -q "healthy"; then
        log_info "✓ Backend health check passed"
    else
        log_warn "⚠ Backend health check failed"
    fi
    
    log_info "Getting frontend service details..."
    kubectl get service easypay-frontend -n $NAMESPACE
}

display_access_info() {
    print_header "Application Access Information"
    
    # Get NodePort
    NODEPORT=$(kubectl get service easypay-frontend -n $NAMESPACE -o jsonpath='{.spec.ports[0].nodePort}')
    
    # Get worker node IPs
    WORKER_IPS=$(kubectl get nodes -l node-role.kubernetes.io/worker=worker -o jsonpath='{.items[*].status.addresses[?(@.type=="ExternalIP")].address}')
    
    echo -e "${GREEN}Application Endpoints:${NC}"
    for IP in $WORKER_IPS; do
        echo "  → http://$IP:$NODEPORT"
    done
    
    echo ""
    echo -e "${GREEN}Load Balancer:${NC}"
    echo "  Check your AWS console for ALB DNS name"
    
    echo ""
    echo -e "${GREEN}Useful Commands:${NC}"
    echo "  View all resources:  kubectl get all -n $NAMESPACE"
    echo "  View pod logs:       kubectl logs <pod-name> -n $NAMESPACE"
    echo "  Describe pod:        kubectl describe pod <pod-name> -n $NAMESPACE"
    echo "  Get HPA status:      kubectl get hpa -n $NAMESPACE"
    echo "  View metrics:        kubectl top pods -n $NAMESPACE"
}

cleanup() {
    print_header "Cleanup (Optional)"
    
    read -p "Do you want to delete the deployment? (yes/no): " -r
    if [[ $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        log_info "Deleting all resources in namespace $NAMESPACE..."
        kubectl delete namespace $NAMESPACE
        log_info "Cleanup completed"
    else
        log_info "Skipping cleanup"
    fi
}

main() {
    echo ""
    print_header "EasyPay Application Deployment"
    echo ""
    
    check_prerequisites
    create_namespace
    deploy_database
    sleep 10  # Wait for database to fully initialize
    deploy_backend
    deploy_frontend
    deploy_network_policies
    deploy_rbac
    deploy_autoscaling
    
    echo ""
    verify_deployment
    
    echo ""
    test_connectivity
    
    echo ""
    display_access_info
    
    echo ""
    print_header "Deployment Complete!"
    log_info "EasyPay application has been successfully deployed"
    
    echo ""
}

# Handle script interruption
trap 'echo -e "\n${RED}Deployment interrupted${NC}"; exit 1' INT TERM

# Run main function
main "$@"
