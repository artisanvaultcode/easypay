# EasyPay Infrastructure - Detailed Implementation Guide

## Table of Contents
1. [Phase 1: AWS Infrastructure Setup](#phase-1-aws-infrastructure-setup)
2. [Phase 2: Ansible Automation](#phase-2-ansible-automation)
3. [Phase 3: Docker Installation](#phase-3-docker-installation)
4. [Phase 4: Kubernetes Cluster Setup](#phase-4-kubernetes-cluster-setup)
5. [Phase 5: Network Policies](#phase-5-network-policies)
6. [Phase 6: RBAC Configuration](#phase-6-rbac-configuration)
7. [Phase 7: Application Deployment](#phase-7-application-deployment)
8. [Phase 8: ETCD Backup](#phase-8-etcd-backup)
9. [Phase 9: Auto-Scaling Configuration](#phase-9-auto-scaling-configuration)

---

## Phase 1: AWS Infrastructure Setup

### Algorithm: Create EC2 Cluster with Load Balancer

```
ALGORITHM: SetupAWSInfrastructure
INPUT: AWS credentials, region, instance specifications
OUTPUT: Running EC2 cluster with load balancer

1. START
2. Initialize AWS session with credentials
3. Create VPC with CIDR block 10.0.0.0/16
4. Create public subnet (10.0.1.0/24) in AZ-1
5. Create public subnet (10.0.2.0/24) in AZ-2
6. Create private subnet (10.0.3.0/24) in AZ-1
7. Create Internet Gateway and attach to VPC
8. Create NAT Gateway in public subnet
9. Configure route tables:
   - Public route: 0.0.0.0/0 → IGW
   - Private route: 0.0.0.0/0 → NAT Gateway
10. Create Security Groups:
    - SG-Master: Ports 22, 6443, 2379-2380, 10250-10252
    - SG-Worker: Ports 22, 30000-32767, 10250
    - SG-ALB: Ports 80, 443
11. Launch EC2 instances:
    - Master node (t3.medium, Ubuntu 22.04)
    - Worker node 1 (t3.medium, Ubuntu 22.04)
    - Worker node 2 (t3.medium, Ubuntu 22.04)
12. Allocate Elastic IPs to master node
13. Create Application Load Balancer:
    - Type: Application
    - Scheme: Internet-facing
    - Listeners: HTTP (80), HTTPS (443)
14. Create Target Group for worker nodes
15. Register worker nodes with target group
16. Configure health checks:
    - Protocol: HTTP
    - Path: /health
    - Interval: 30 seconds
    - Timeout: 5 seconds
    - Healthy threshold: 2
    - Unhealthy threshold: 3
17. Tag all resources with project metadata
18. OUTPUT instance IDs, EIP, ALB DNS name
19. END
```

### Step-by-Step Implementation

#### Step 1.1: Create VPC and Networking
```bash
# Set variables
export AWS_REGION="us-east-1"
export PROJECT_NAME="easypay-ha"

# Create VPC
VPC_ID=$(aws ec2 create-vpc \
  --cidr-block 10.0.0.0/16 \
  --tag-specifications "ResourceType=vpc,Tags=[{Key=Name,Value=${PROJECT_NAME}-vpc}]" \
  --query 'Vpc.VpcId' \
  --output text)

echo "VPC Created: $VPC_ID"

# Enable DNS hostnames
aws ec2 modify-vpc-attribute \
  --vpc-id $VPC_ID \
  --enable-dns-hostnames

# Create Internet Gateway
IGW_ID=$(aws ec2 create-internet-gateway \
  --tag-specifications "ResourceType=internet-gateway,Tags=[{Key=Name,Value=${PROJECT_NAME}-igw}]" \
  --query 'InternetGateway.InternetGatewayId' \
  --output text)

# Attach IGW to VPC
aws ec2 attach-internet-gateway \
  --internet-gateway-id $IGW_ID \
  --vpc-id $VPC_ID

# Create Public Subnet 1 (AZ-1)
PUBLIC_SUBNET_1=$(aws ec2 create-subnet \
  --vpc-id $VPC_ID \
  --cidr-block 10.0.1.0/24 \
  --availability-zone ${AWS_REGION}a \
  --tag-specifications "ResourceType=subnet,Tags=[{Key=Name,Value=${PROJECT_NAME}-public-1}]" \
  --query 'Subnet.SubnetId' \
  --output text)

# Create Public Subnet 2 (AZ-2)
PUBLIC_SUBNET_2=$(aws ec2 create-subnet \
  --vpc-id $VPC_ID \
  --cidr-block 10.0.2.0/24 \
  --availability-zone ${AWS_REGION}b \
  --tag-specifications "ResourceType=subnet,Tags=[{Key=Name,Value=${PROJECT_NAME}-public-2}]" \
  --query 'Subnet.SubnetId' \
  --output text)

# Create Private Subnet
PRIVATE_SUBNET=$(aws ec2 create-subnet \
  --vpc-id $VPC_ID \
  --cidr-block 10.0.3.0/24 \
  --availability-zone ${AWS_REGION}a \
  --tag-specifications "ResourceType=subnet,Tags=[{Key=Name,Value=${PROJECT_NAME}-private}]" \
  --query 'Subnet.SubnetId' \
  --output text)

# Enable auto-assign public IP for public subnets
aws ec2 modify-subnet-attribute \
  --subnet-id $PUBLIC_SUBNET_1 \
  --map-public-ip-on-launch

aws ec2 modify-subnet-attribute \
  --subnet-id $PUBLIC_SUBNET_2 \
  --map-public-ip-on-launch
```

#### Step 1.2: Create Security Groups
```bash
# Security Group for Master Node
MASTER_SG=$(aws ec2 create-security-group \
  --group-name ${PROJECT_NAME}-master-sg \
  --description "Security group for Kubernetes master node" \
  --vpc-id $VPC_ID \
  --query 'GroupId' \
  --output text)

# Master node ingress rules
aws ec2 authorize-security-group-ingress --group-id $MASTER_SG --protocol tcp --port 22 --cidr 0.0.0.0/0
aws ec2 authorize-security-group-ingress --group-id $MASTER_SG --protocol tcp --port 6443 --cidr 0.0.0.0/0
aws ec2 authorize-security-group-ingress --group-id $MASTER_SG --protocol tcp --port 2379-2380 --cidr 10.0.0.0/16
aws ec2 authorize-security-group-ingress --group-id $MASTER_SG --protocol tcp --port 10250-10252 --cidr 10.0.0.0/16

# Security Group for Worker Nodes
WORKER_SG=$(aws ec2 create-security-group \
  --group-name ${PROJECT_NAME}-worker-sg \
  --description "Security group for Kubernetes worker nodes" \
  --vpc-id $VPC_ID \
  --query 'GroupId' \
  --output text)

# Worker node ingress rules
aws ec2 authorize-security-group-ingress --group-id $WORKER_SG --protocol tcp --port 22 --cidr 0.0.0.0/0
aws ec2 authorize-security-group-ingress --group-id $WORKER_SG --protocol tcp --port 10250 --cidr 10.0.0.0/16
aws ec2 authorize-security-group-ingress --group-id $WORKER_SG --protocol tcp --port 30000-32767 --cidr 0.0.0.0/0

# Allow all traffic between master and workers
aws ec2 authorize-security-group-ingress --group-id $MASTER_SG --source-group $WORKER_SG --protocol all
aws ec2 authorize-security-group-ingress --group-id $WORKER_SG --source-group $MASTER_SG --protocol all
```

#### Step 1.3: Launch EC2 Instances
```bash
# Get latest Ubuntu 22.04 AMI
AMI_ID=$(aws ec2 describe-images \
  --owners 099720109477 \
  --filters "Name=name,Values=ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*" \
  --query 'sort_by(Images, &CreationDate)[-1].ImageId' \
  --output text)

# Launch Master Node
MASTER_INSTANCE=$(aws ec2 run-instances \
  --image-id $AMI_ID \
  --instance-type t3.medium \
  --key-name your-key-pair \
  --security-group-ids $MASTER_SG \
  --subnet-id $PUBLIC_SUBNET_1 \
  --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=${PROJECT_NAME}-master},{Key=Role,Value=master}]" \
  --block-device-mappings '[{"DeviceName":"/dev/sda1","Ebs":{"VolumeSize":30,"VolumeType":"gp3"}}]' \
  --query 'Instances[0].InstanceId' \
  --output text)

# Launch Worker Node 1
WORKER1_INSTANCE=$(aws ec2 run-instances \
  --image-id $AMI_ID \
  --instance-type t3.medium \
  --key-name your-key-pair \
  --security-group-ids $WORKER_SG \
  --subnet-id $PUBLIC_SUBNET_1 \
  --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=${PROJECT_NAME}-worker-1},{Key=Role,Value=worker}]" \
  --block-device-mappings '[{"DeviceName":"/dev/sda1","Ebs":{"VolumeSize":30,"VolumeType":"gp3"}}]' \
  --query 'Instances[0].InstanceId' \
  --output text)

# Launch Worker Node 2
WORKER2_INSTANCE=$(aws ec2 run-instances \
  --image-id $AMI_ID \
  --instance-type t3.medium \
  --key-name your-key-pair \
  --security-group-ids $WORKER_SG \
  --subnet-id $PUBLIC_SUBNET_2 \
  --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=${PROJECT_NAME}-worker-2},{Key=Role,Value=worker}]" \
  --block-device-mappings '[{"DeviceName":"/dev/sda1","Ebs":{"VolumeSize":30,"VolumeType":"gp3"}}]' \
  --query 'Instances[0].InstanceId' \
  --output text)

# Wait for instances to be running
aws ec2 wait instance-running --instance-ids $MASTER_INSTANCE $WORKER1_INSTANCE $WORKER2_INSTANCE

echo "Instances launched successfully!"
echo "Master: $MASTER_INSTANCE"
echo "Worker 1: $WORKER1_INSTANCE"
echo "Worker 2: $WORKER2_INSTANCE"
```

#### Step 1.4: Allocate Elastic IP
```bash
# Allocate Elastic IP for master node
EIP_ALLOC=$(aws ec2 allocate-address \
  --domain vpc \
  --tag-specifications "ResourceType=elastic-ip,Tags=[{Key=Name,Value=${PROJECT_NAME}-master-eip}]" \
  --query 'AllocationId' \
  --output text)

# Associate EIP with master instance
aws ec2 associate-address \
  --instance-id $MASTER_INSTANCE \
  --allocation-id $EIP_ALLOC

# Get the public IP
MASTER_EIP=$(aws ec2 describe-addresses \
  --allocation-ids $EIP_ALLOC \
  --query 'Addresses[0].PublicIp' \
  --output text)

echo "Master Node Elastic IP: $MASTER_EIP"
```

#### Step 1.5: Create Application Load Balancer
```bash
# Create ALB
ALB_ARN=$(aws elbv2 create-load-balancer \
  --name ${PROJECT_NAME}-alb \
  --subnets $PUBLIC_SUBNET_1 $PUBLIC_SUBNET_2 \
  --security-groups $WORKER_SG \
  --scheme internet-facing \
  --type application \
  --ip-address-type ipv4 \
  --tags Key=Name,Value=${PROJECT_NAME}-alb \
  --query 'LoadBalancers[0].LoadBalancerArn' \
  --output text)

# Get ALB DNS name
ALB_DNS=$(aws elbv2 describe-load-balancers \
  --load-balancer-arns $ALB_ARN \
  --query 'LoadBalancers[0].DNSName' \
  --output text)

# Create Target Group
TG_ARN=$(aws elbv2 create-target-group \
  --name ${PROJECT_NAME}-tg \
  --protocol HTTP \
  --port 30080 \
  --vpc-id $VPC_ID \
  --health-check-enabled \
  --health-check-protocol HTTP \
  --health-check-path /health \
  --health-check-interval-seconds 30 \
  --health-check-timeout-seconds 5 \
  --healthy-threshold-count 2 \
  --unhealthy-threshold-count 3 \
  --query 'TargetGroups[0].TargetGroupArn' \
  --output text)

# Register worker instances with target group
aws elbv2 register-targets \
  --target-group-arn $TG_ARN \
  --targets Id=$WORKER1_INSTANCE Id=$WORKER2_INSTANCE

# Create listener
aws elbv2 create-listener \
  --load-balancer-arn $ALB_ARN \
  --protocol HTTP \
  --port 80 \
  --default-actions Type=forward,TargetGroupArn=$TG_ARN

echo "Application Load Balancer DNS: $ALB_DNS"
```

---

## Phase 2: Ansible Automation

### Algorithm: Automate EC2 Provisioning

```
ALGORITHM: ProvisionEC2WithAnsible
INPUT: EC2 instance IPs, SSH keys
OUTPUT: Configured instances ready for Kubernetes

1. START
2. Read inventory file with master and worker IPs
3. FOR each instance in inventory:
   4. Establish SSH connection
   5. Update system packages
   6. Install prerequisites (curl, apt-transport-https, ca-certificates)
   7. Configure system settings:
      - Disable swap
      - Enable kernel modules (overlay, br_netfilter)
      - Configure sysctl parameters
   8. Install Docker:
      - Add Docker GPG key
      - Add Docker repository
      - Install docker-ce
      - Configure Docker daemon
      - Enable and start Docker service
   9. Install Kubernetes components:
      - Add Kubernetes GPG key
      - Add Kubernetes repository
      - Install kubelet, kubeadm, kubectl
      - Hold package versions
10. END FOR
11. Verify installations on all nodes
12. OUTPUT configuration status
13. END
```

### Step-by-Step Implementation

#### Step 2.1: Create Ansible Inventory
```bash
# Create inventory file
cat > /home/claude/easypay-ha-infrastructure/ansible/inventory/hosts.ini << 'EOF'
[masters]
master ansible_host=<MASTER_EIP> ansible_user=ubuntu ansible_ssh_private_key_file=~/.ssh/your-key.pem

[workers]
worker1 ansible_host=<WORKER1_IP> ansible_user=ubuntu ansible_ssh_private_key_file=~/.ssh/your-key.pem
worker2 ansible_host=<WORKER2_IP> ansible_user=ubuntu ansible_ssh_private_key_file=~/.ssh/your-key.pem

[cluster:children]
masters
workers

[cluster:vars]
ansible_python_interpreter=/usr/bin/python3
ansible_ssh_common_args='-o StrictHostKeyChecking=no'
EOF
```

---

## Phase 3: Docker Installation

### Algorithm: Install Docker on All Nodes

```
ALGORITHM: InstallDocker
INPUT: Target node connection
OUTPUT: Running Docker service

1. START
2. Remove old Docker versions
3. Update apt package index
4. Install dependencies:
   - ca-certificates
   - curl
   - gnupg
   - lsb-release
5. Add Docker's official GPG key
6. Set up Docker repository
7. Update apt package index again
8. Install Docker Engine:
   - docker-ce
   - docker-ce-cli
   - containerd.io
   - docker-compose-plugin
9. Configure Docker daemon:
   - Set cgroup driver to systemd
   - Set storage driver to overlay2
10. Create daemon.json configuration file
11. Reload systemd daemon
12. Enable Docker service to start on boot
13. Start Docker service
14. Verify Docker installation:
    - docker --version
    - docker ps
15. Add user to docker group
16. OUTPUT installation status
17. END
```

---

## Phase 4: Kubernetes Cluster Setup

### Algorithm: Initialize Kubernetes Cluster

```
ALGORITHM: SetupKubernetesCluster
INPUT: Master node, worker nodes
OUTPUT: Functional Kubernetes cluster

MASTER NODE INITIALIZATION:
1. START
2. On master node, run kubeadm init:
   - Set pod network CIDR: 10.244.0.0/16
   - Set API server advertise address
   - Set control-plane endpoint
3. Save join command for workers
4. Configure kubectl for ubuntu user:
   - Create .kube directory
   - Copy admin.conf to .kube/config
   - Set proper ownership
5. Install Calico network plugin:
   - Apply Calico manifest
   - Wait for calico-node pods to be ready
6. Verify master node status: kubectl get nodes
7. OUTPUT join command

WORKER NODE JOINING:
8. FOR each worker node:
   9. Execute kubeadm join command from step 3
   10. Wait for node to join cluster
   11. Verify node status
12. END FOR
13. Label worker nodes
14. Verify cluster status
15. END
```

---

## Phase 5: Network Policies

### Algorithm: Implement Database Network Policies

```
ALGORITHM: ConfigureNetworkPolicies
INPUT: Kubernetes cluster, application pods
OUTPUT: Network policies restricting traffic

1. START
2. Identify pod selectors:
   - Database pods: app=database
   - Backend pods: app=backend
   - Frontend pods: app=frontend
3. Create NetworkPolicy resource:
   - Name: database-network-policy
   - Namespace: default
4. Define podSelector for database pods
5. Set policyTypes: [Ingress]
6. Configure Ingress rules:
   - FROM: backend pods only
   - PORTS: 5432 (PostgreSQL) or 3306 (MySQL)
7. Apply network policy: kubectl apply -f
8. Test policy:
   - Attempt connection from backend: SHOULD SUCCEED
   - Attempt connection from frontend: SHOULD FAIL
   - Attempt connection from external: SHOULD FAIL
9. Verify policy: kubectl describe networkpolicy
10. Monitor policy enforcement
11. OUTPUT policy status
12. END
```

---

## Phase 6: RBAC Configuration

### Algorithm: Create User with Pod Permissions

```
ALGORITHM: ConfigureRBAC
INPUT: Username, namespace
OUTPUT: User with specific pod permissions

1. START
2. Generate private key for user:
   - openssl genrsa -out user.key 2048
3. Create certificate signing request:
   - openssl req -new -key user.key -out user.csr
4. Encode CSR in base64
5. Create CertificateSigningRequest resource
6. Approve CSR: kubectl certificate approve
7. Retrieve certificate: kubectl get csr
8. Create Role with permissions:
   - apiGroups: [""]
   - resources: ["pods"]
   - verbs: ["create", "list", "get", "update", "delete"]
9. Create RoleBinding:
   - Bind role to user
   - Specify namespace
10. Create kubeconfig for user:
    - Set cluster
    - Set credentials
    - Set context
11. Test user permissions:
    - kubectl get pods --as=username
    - kubectl create pod --as=username
12. Verify RBAC: kubectl auth can-i
13. OUTPUT user credentials and kubeconfig
14. END
```

---

## Phase 7: Application Deployment

### Algorithm: Deploy Application on Pods

```
ALGORITHM: DeployApplication
INPUT: Container images, deployment specs
OUTPUT: Running application pods

1. START
2. Create Namespace: easypay
3. Deploy Database (StatefulSet):
   - Image: postgres:14
   - Replicas: 1
   - PersistentVolumeClaim: 10Gi
   - Environment variables:
     * POSTGRES_DB
     * POSTGRES_USER
     * POSTGRES_PASSWORD
   - Ports: 5432
   - volumeMounts: /var/lib/postgresql/data
4. Create Database Service:
   - Type: ClusterIP
   - Port: 5432
5. Wait for database to be ready
6. Deploy Backend (Deployment):
   - Image: easypay/backend:latest
   - Replicas: 3
   - Environment variables:
     * DB_HOST
     * DB_PORT
     * DB_NAME
   - Resources:
     * requests: cpu=200m, memory=256Mi
     * limits: cpu=500m, memory=512Mi
   - livenessProbe: /health
   - readinessProbe: /ready
7. Create Backend Service:
   - Type: ClusterIP
   - Port: 8080
8. Deploy Frontend (Deployment):
   - Image: easypay/frontend:latest
   - Replicas: 3
   - Environment variables:
     * BACKEND_URL
   - Resources:
     * requests: cpu=100m, memory=128Mi
     * limits: cpu=300m, memory=256Mi
9. Create Frontend Service:
   - Type: NodePort
   - Port: 80
   - NodePort: 30080
10. Apply all manifests: kubectl apply -f
11. Wait for all pods to be ready
12. Verify deployments: kubectl get all
13. Test application endpoints
14. OUTPUT deployment status and endpoints
15. END
```

---

## Phase 8: ETCD Backup

### Algorithm: Backup ETCD Database

```
ALGORITHM: BackupETCD
INPUT: ETCD endpoint, certificates
OUTPUT: ETCD snapshot file

1. START
2. Set environment variables:
   - ETCDCTL_API=3
   - ETCD_ENDPOINTS
   - ETCD_CACERT
   - ETCD_CERT
   - ETCD_KEY
3. Create backup directory: /backup/etcd
4. Generate snapshot filename: etcd-snapshot-$(date +%Y%m%d-%H%M%S).db
5. Execute etcdctl snapshot save:
   - Specify endpoint
   - Provide certificates
   - Set output file path
6. Verify snapshot:
   - etcdctl snapshot status
   - Check file size and integrity
7. Compress snapshot: gzip snapshot-file
8. Copy to remote storage:
   - AWS S3
   - OR NFS share
9. Rotate old backups:
   - Keep last 7 days
   - Delete older snapshots
10. Log backup completion
11. Schedule cron job for automatic backups:
    - Every 6 hours: 0 */6 * * *
12. OUTPUT backup file path and status
13. END
```

---

## Phase 9: Auto-Scaling Configuration

### Algorithm: Configure Horizontal Pod Autoscaler

```
ALGORITHM: ConfigureAutoScaling
INPUT: Deployment name, resource metrics
OUTPUT: HPA monitoring and scaling pods

1. START
2. Ensure metrics-server is installed:
   - kubectl apply -f metrics-server.yaml
3. Verify metrics availability:
   - kubectl top nodes
   - kubectl top pods
4. Create HorizontalPodAutoscaler resource:
   - Name: easypay-backend-hpa
   - scaleTargetRef: backend-deployment
   - minReplicas: 3
   - maxReplicas: 10
   - metrics:
     * CPU: 50% utilization
     * Memory: 50% utilization
5. Apply HPA: kubectl apply -f hpa.yaml
6. Verify HPA creation: kubectl get hpa
7. Monitor HPA behavior:
   - kubectl describe hpa
   - Watch scaling events
8. Test auto-scaling:
   - Generate load on application
   - Monitor CPU/Memory metrics
   - Observe pod scaling up
   - Reduce load
   - Observe pod scaling down
9. Configure cluster autoscaler (optional):
   - Set min/max nodes
   - Deploy cluster-autoscaler
10. Set up alerts:
    - High CPU/Memory utilization
    - Scaling events
    - Failed scaling attempts
11. OUTPUT HPA configuration and status
12. END
```

---

## Verification Steps

### System Verification Checklist

1. **Infrastructure Verification**
   ```bash
   # Check EC2 instances
   aws ec2 describe-instances --filters "Name=tag:Name,Values=easypay-ha-*"
   
   # Check ALB health
   aws elbv2 describe-target-health --target-group-arn $TG_ARN
   ```

2. **Kubernetes Cluster Verification**
   ```bash
   # Check cluster status
   kubectl cluster-info
   kubectl get nodes -o wide
   kubectl get cs
   ```

3. **Application Verification**
   ```bash
   # Check deployments
   kubectl get deployments -n easypay
   kubectl get pods -n easypay
   kubectl get svc -n easypay
   ```

4. **Network Policy Verification**
   ```bash
   # Test database connectivity
   kubectl exec -it <backend-pod> -n easypay -- nc -zv database-service 5432
   kubectl exec -it <frontend-pod> -n easypay -- nc -zv database-service 5432
   ```

5. **Auto-Scaling Verification**
   ```bash
   # Check HPA status
   kubectl get hpa -n easypay
   kubectl describe hpa easypay-backend-hpa -n easypay
   ```

6. **ETCD Backup Verification**
   ```bash
   # List backups
   ls -lh /backup/etcd/
   
   # Verify backup integrity
   ETCDCTL_API=3 etcdctl snapshot status /backup/etcd/latest.db
   ```

---

## Troubleshooting Guide

### Common Issues and Solutions

1. **Pods Not Starting**
   - Check pod logs: `kubectl logs <pod-name>`
   - Check events: `kubectl describe pod <pod-name>`
   - Verify image pull: Check imagePullPolicy

2. **Node Not Ready**
   - Check kubelet: `systemctl status kubelet`
   - Check container runtime: `systemctl status docker`
   - Check network plugin: `kubectl get pods -n kube-system`

3. **HPA Not Scaling**
   - Verify metrics-server: `kubectl get deployment metrics-server -n kube-system`
   - Check metrics: `kubectl top pods`
   - Review HPA events: `kubectl describe hpa`

4. **Network Policy Blocking Traffic**
   - Review policy: `kubectl describe networkpolicy`
   - Check pod labels: `kubectl get pods --show-labels`
   - Test connectivity: Use debug pod

---

## Next Steps

1. Implement monitoring with Prometheus and Grafana
2. Set up centralized logging with ELK stack
3. Implement CI/CD pipeline with Jenkins or GitLab CI
4. Configure SSL/TLS for ALB
5. Implement backup and disaster recovery procedures
6. Set up alerting with PagerDuty or Opsgenie

---

## References

- Kubernetes Documentation: https://kubernetes.io/docs/
- Docker Documentation: https://docs.docker.com/
- Ansible Documentation: https://docs.ansible.com/
- AWS Documentation: https://docs.aws.amazon.com/
