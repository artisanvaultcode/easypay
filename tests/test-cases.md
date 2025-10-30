# EasyPay High-Availability Infrastructure - Test Cases

## Test Plan Overview

**Project:** EasyPay HA Infrastructure  
**Test Date:** October 29, 2025  
**Tester:** QA Team  
**Environment:** Production-like  

---

## Test Categories

1. Infrastructure Tests
2. Kubernetes Cluster Tests
3. Application Deployment Tests
4. Network Policy Tests
5. RBAC Tests
6. High Availability Tests
7. Auto-Scaling Tests
8. Backup and Recovery Tests
9. Performance Tests
10. Security Tests

---

## 1. Infrastructure Tests

### Test Case 1.1: EC2 Instance Creation
**Test ID:** INF-001  
**Priority:** High  
**Objective:** Verify all EC2 instances are created successfully

**Preconditions:**
- AWS credentials configured
- Valid VPC and subnets exist

**Test Steps:**
1. Run Terraform/Ansible provisioning script
2. Verify 1 master node is created
3. Verify 2 worker nodes are created
4. Check instance types are t3.medium
5. Verify instances are in running state

**Expected Results:**
- 3 EC2 instances created
- All instances running
- Correct tags applied
- Instances in correct subnets

**Actual Results:** [To be filled during testing]

**Status:** [ ] Pass [ ] Fail [ ] Blocked

---

### Test Case 1.2: Load Balancer Configuration
**Test ID:** INF-002  
**Priority:** High  
**Objective:** Verify Application Load Balancer is configured correctly

**Test Steps:**
1. Check ALB is created
2. Verify target group exists
3. Confirm worker nodes registered as targets
4. Test health checks
5. Verify listener on port 80/443

**Expected Results:**
- ALB accessible via DNS
- Both workers registered
- Health checks passing
- Traffic distributed evenly

**Actual Results:** [To be filled during testing]

**Status:** [ ] Pass [ ] Fail [ ] Blocked

---

### Test Case 1.3: Elastic IP Assignment
**Test ID:** INF-003  
**Priority:** Medium  
**Objective:** Verify Elastic IP is assigned to master node

**Test Steps:**
1. Check EIP allocation
2. Verify association with master node
3. Test SSH connectivity using EIP
4. Verify EIP persists after reboot

**Expected Results:**
- EIP allocated successfully
- EIP associated with master
- SSH works via EIP
- EIP remains after reboot

**Actual Results:** [To be filled during testing]

**Status:** [ ] Pass [ ] Fail [ ] Blocked

---

### Test Case 1.4: Security Groups
**Test ID:** INF-004  
**Priority:** High  
**Objective:** Verify security group rules are correctly configured

**Test Steps:**
1. Check master security group rules
2. Check worker security group rules
3. Test SSH access (port 22)
4. Test Kubernetes API access (port 6443)
5. Test NodePort range (30000-32767)
6. Verify inter-node communication

**Expected Results:**
- Required ports are open
- Unnecessary ports are closed
- Inter-node communication works
- External access limited to required ports

**Actual Results:** [To be filled during testing]

**Status:** [ ] Pass [ ] Fail [ ] Blocked

---

## 2. Kubernetes Cluster Tests

### Test Case 2.1: Cluster Initialization
**Test ID:** K8S-001  
**Priority:** Critical  
**Objective:** Verify Kubernetes cluster is initialized correctly

**Test Steps:**
1. Run `kubectl cluster-info`
2. Check master node status: `kubectl get nodes`
3. Verify all control plane components running
4. Check `kubectl get cs` output
5. Verify API server is accessible

**Expected Results:**
- Cluster info displays correctly
- Master node in Ready state
- All control plane pods running
- Component statuses healthy

**Actual Results:** [To be filled during testing]

**Status:** [ ] Pass [ ] Fail [ ] Blocked

---

### Test Case 2.2: Worker Node Join
**Test ID:** K8S-002  
**Priority:** Critical  
**Objective:** Verify worker nodes join cluster successfully

**Test Steps:**
1. Execute join command on worker nodes
2. Run `kubectl get nodes` on master
3. Verify both workers show Ready status
4. Check node labels and roles
5. Verify kubelet is running on workers

**Expected Results:**
- Both workers successfully joined
- All nodes show Ready status
- Worker role labels applied
- Kubelet active on all nodes

**Actual Results:** [To be filled during testing]

**Status:** [ ] Pass [ ] Fail [ ] Blocked

---

### Test Case 2.3: Network Plugin Installation
**Test ID:** K8S-003  
**Priority:** High  
**Objective:** Verify Calico network plugin is installed correctly

**Test Steps:**
1. Apply Calico manifest
2. Check calico-node pods: `kubectl get pods -n kube-system`
3. Verify calico-kube-controllers running
4. Test pod-to-pod communication
5. Check node networking status

**Expected Results:**
- All Calico pods running
- Pod network CIDR configured (10.244.0.0/16)
- Inter-pod communication works
- No CNI errors in logs

**Actual Results:** [To be filled during testing]

**Status:** [ ] Pass [ ] Fail [ ] Blocked

---

### Test Case 2.4: DNS Resolution
**Test ID:** K8S-004  
**Priority:** High  
**Objective:** Verify CoreDNS is functioning correctly

**Test Steps:**
1. Check CoreDNS pods: `kubectl get pods -n kube-system`
2. Create test pod
3. Test DNS resolution inside pod
4. Verify service discovery works
5. Check DNS query logs

**Expected Results:**
- CoreDNS pods running
- DNS queries resolve correctly
- Service names resolve to ClusterIPs
- No DNS errors in logs

**Actual Results:** [To be filled during testing]

**Status:** [ ] Pass [ ] Fail [ ] Blocked

---

## 3. Application Deployment Tests

### Test Case 3.1: Namespace Creation
**Test ID:** APP-001  
**Priority:** Medium  
**Objective:** Verify easypay namespace is created

**Test Steps:**
1. Create namespace: `kubectl create namespace easypay`
2. Verify namespace exists: `kubectl get namespaces`
3. Check namespace labels
4. Set namespace as default context

**Expected Results:**
- Namespace created successfully
- Namespace visible in listing
- Correct labels applied

**Actual Results:** [To be filled during testing]

**Status:** [ ] Pass [ ] Fail [ ] Blocked

---

### Test Case 3.2: Database Deployment
**Test ID:** APP-002  
**Priority:** Critical  
**Objective:** Verify PostgreSQL database is deployed correctly

**Test Steps:**
1. Apply database StatefulSet
2. Check pod status: `kubectl get pods -n easypay`
3. Verify PVC is bound
4. Check database initialization
5. Test database connectivity
6. Verify data persistence

**Expected Results:**
- Database pod running
- PVC created and bound (10Gi)
- Database initialized with schema
- Connection successful from test pod
- Data persists after pod restart

**Actual Results:** [To be filled during testing]

**Status:** [ ] Pass [ ] Fail [ ] Blocked

---

### Test Case 3.3: Backend Deployment
**Test ID:** APP-003  
**Priority:** Critical  
**Objective:** Verify backend application is deployed correctly

**Test Steps:**
1. Apply backend deployment
2. Check pod status (should be 3 replicas)
3. Verify environment variables
4. Test database connectivity from backend
5. Check /health endpoint
6. Check /ready endpoint
7. Verify resource limits applied

**Expected Results:**
- 3 backend pods running
- All pods in Ready state
- Environment variables set correctly
- Database connection successful
- Health checks passing
- Resource limits enforced

**Actual Results:** [To be filled during testing]

**Status:** [ ] Pass [ ] Fail [ ] Blocked

---

### Test Case 3.4: Frontend Deployment
**Test ID:** APP-004  
**Priority:** Critical  
**Objective:** Verify frontend application is deployed correctly

**Test Steps:**
1. Apply frontend deployment
2. Check pod status (should be 3 replicas)
3. Verify NodePort service created
4. Test access via NodePort
5. Check backend connectivity
6. Verify static content loads
7. Test load balancer integration

**Expected Results:**
- 3 frontend pods running
- NodePort service accessible (30080)
- Backend API calls work
- Static content serves correctly
- ALB routes traffic to frontend

**Actual Results:** [To be filled during testing]

**Status:** [ ] Pass [ ] Fail [ ] Blocked

---

### Test Case 3.5: End-to-End Application Test
**Test ID:** APP-005  
**Priority:** Critical  
**Objective:** Verify complete application flow works

**Test Steps:**
1. Access application via ALB DNS
2. Test user registration
3. Test add money to wallet
4. Process a payment transaction
5. Check balance update
6. Verify transaction in database
7. Test with multiple concurrent users

**Expected Results:**
- Application accessible via ALB
- User can register successfully
- Wallet operations work
- Payment processing succeeds
- Balance reflects correctly
- Data consistent in database
- No errors under concurrent load

**Actual Results:** [To be filled during testing]

**Status:** [ ] Pass [ ] Fail [ ] Blocked

---

## 4. Network Policy Tests

### Test Case 4.1: Database Network Isolation
**Test ID:** NET-001  
**Priority:** Critical  
**Objective:** Verify database is accessible only from backend

**Test Steps:**
1. Apply database network policy
2. Test connection from backend pod (should succeed)
3. Test connection from frontend pod (should fail)
4. Test connection from external pod (should fail)
5. Use netshoot pod for testing
6. Check network policy status

**Expected Results:**
- Backend can connect to database
- Frontend cannot connect to database
- External pods cannot connect
- Network policy applied correctly
- No policy errors in logs

**Actual Results:** [To be filled during testing]

**Commands:**
```bash
# Test from backend (should work)
kubectl exec -it <backend-pod> -n easypay -- nc -zv easypay-database 5432

# Test from frontend (should fail)
kubectl exec -it <frontend-pod> -n easypay -- nc -zv easypay-database 5432

# Test from test pod (should fail)
kubectl exec -it network-policy-test -n easypay -- nc -zv easypay-database 5432
```

**Status:** [ ] Pass [ ] Fail [ ] Blocked

---

### Test Case 4.2: Backend Network Policy
**Test ID:** NET-002  
**Priority:** High  
**Objective:** Verify backend accepts connections only from frontend

**Test Steps:**
1. Apply backend network policy
2. Test connection from frontend (should succeed)
3. Test direct connection from outside (check restrictions)
4. Verify backend can connect to database
5. Check egress rules

**Expected Results:**
- Frontend can connect to backend
- Backend can connect to database
- Egress rules allow DNS and HTTPS
- All connections logged correctly

**Actual Results:** [To be filled during testing]

**Status:** [ ] Pass [ ] Fail [ ] Blocked

---

## 5. RBAC Tests

### Test Case 5.1: User Creation and Permissions
**Test ID:** RBAC-001  
**Priority:** High  
**Objective:** Verify user can perform only permitted operations

**Test Steps:**
1. Create ServiceAccount: easypay-developer
2. Apply Role and RoleBinding
3. Generate kubeconfig for user
4. Test permitted operations (create, list, get, update, delete pods)
5. Test restricted operations (deployments, services)
6. Verify in other namespaces (should fail)

**Expected Results:**
- User can create pods in easypay namespace
- User can list pods
- User can get pod details
- User can update pods
- User can delete pods
- User cannot modify deployments
- User cannot access other namespaces

**Actual Results:** [To be filled during testing]

**Commands:**
```bash
# Test as user
kubectl auth can-i create pods --as=system:serviceaccount:easypay:easypay-developer -n easypay
kubectl auth can-i delete deployments --as=system:serviceaccount:easypay:easypay-developer -n easypay
kubectl auth can-i get pods --as=system:serviceaccount:easypay:easypay-developer -n default
```

**Status:** [ ] Pass [ ] Fail [ ] Blocked

---

### Test Case 5.2: Service Account Token
**Test ID:** RBAC-002  
**Priority:** Medium  
**Objective:** Verify service account token works correctly

**Test Steps:**
1. Extract token from secret
2. Use token to authenticate
3. Test API access with token
4. Verify token expiration
5. Test token renewal

**Expected Results:**
- Token extracted successfully
- Authentication works with token
- API calls succeed with valid token
- Token expires as configured
- Token can be renewed

**Actual Results:** [To be filled during testing]

**Status:** [ ] Pass [ ] Fail [ ] Blocked

---

## 6. High Availability Tests

### Test Case 6.1: Node Failure Simulation
**Test ID:** HA-001  
**Priority:** Critical  
**Objective:** Verify system continues working when a worker node fails

**Test Steps:**
1. Check current pod distribution
2. Simulate worker node failure (stop instance)
3. Monitor pod rescheduling
4. Verify application remains accessible
5. Check load balancer health checks
6. Bring node back online
7. Verify pods rebalance

**Expected Results:**
- Pods automatically rescheduled to healthy node
- Application remains accessible during failure
- Load balancer marks failed node unhealthy
- No data loss
- Recovery happens within 5 minutes
- Pods rebalance when node returns

**Actual Results:** [To be filled during testing]

**Status:** [ ] Pass [ ] Fail [ ] Blocked

---

### Test Case 6.2: Pod Failure Recovery
**Test ID:** HA-002  
**Priority:** High  
**Objective:** Verify pods are automatically recreated on failure

**Test Steps:**
1. Check deployment replicas
2. Delete a backend pod
3. Monitor Kubernetes recreation
4. Delete a frontend pod
5. Verify application functionality
6. Check all pods back to desired state

**Expected Results:**
- Deleted pods recreated automatically
- Replica count maintained
- Application functionality unaffected
- New pods pass health checks
- Recovery within 30 seconds

**Actual Results:** [To be filled during testing]

**Status:** [ ] Pass [ ] Fail [ ] Blocked

---

### Test Case 6.3: Database Failover
**Test ID:** HA-003  
**Priority:** Critical  
**Objective:** Verify database data persists after pod restart

**Test Steps:**
1. Insert test data into database
2. Delete database pod
3. Wait for StatefulSet to recreate pod
4. Verify data still exists
5. Test application can read data
6. Verify PVC remains intact

**Expected Results:**
- Database pod recreates automatically
- PVC reattaches to new pod
- Data persists across restart
- Application can access data
- No data corruption

**Actual Results:** [To be filled during testing]

**Status:** [ ] Pass [ ] Fail [ ] Blocked

---

## 7. Auto-Scaling Tests

### Test Case 7.1: CPU-Based Scaling
**Test ID:** SCALE-001  
**Priority:** Critical  
**Objective:** Verify HPA scales pods based on CPU utilization

**Test Steps:**
1. Check current HPA status
2. Generate CPU load on backend pods
3. Monitor CPU metrics
4. Wait for scaling trigger (>50% CPU)
5. Verify new pods created
6. Reduce load
7. Verify scale down after stabilization

**Expected Results:**
- HPA detects high CPU usage
- New pods created when CPU >50%
- Scales up to max 10 replicas
- Pods become ready and join load balancer
- Scales down when CPU <50%
- Maintains min 3 replicas

**Actual Results:** [To be filled during testing]

**Commands:**
```bash
# Generate load
kubectl run -it --rm load-generator --image=busybox -n easypay --restart=Never -- /bin/sh -c "while true; do wget -q -O- http://easypay-backend:8080; done"

# Monitor HPA
kubectl get hpa -n easypay -w

# Check metrics
kubectl top pods -n easypay
```

**Status:** [ ] Pass [ ] Fail [ ] Blocked

---

### Test Case 7.2: Memory-Based Scaling
**Test ID:** SCALE-002  
**Priority:** High  
**Objective:** Verify HPA scales pods based on memory utilization

**Test Steps:**
1. Check current memory usage
2. Generate memory load
3. Monitor memory metrics
4. Wait for scaling trigger (>50% memory)
5. Verify new pods created
6. Reduce memory load
7. Verify scale down

**Expected Results:**
- HPA detects high memory usage
- Scales when memory >50%
- Memory distributed across pods
- Scales down when memory <50%

**Actual Results:** [To be filled during testing]

**Status:** [ ] Pass [ ] Fail [ ] Blocked

---

### Test Case 7.3: Metrics Server Verification
**Test ID:** SCALE-003  
**Priority:** High  
**Objective:** Verify metrics server is collecting metrics correctly

**Test Steps:**
1. Check metrics-server deployment
2. Verify metrics-server pods running
3. Test `kubectl top nodes`
4. Test `kubectl top pods`
5. Verify metrics API available
6. Check metric accuracy

**Expected Results:**
- Metrics-server running
- Node metrics available
- Pod metrics available
- Metrics update every 15 seconds
- Metrics reasonably accurate

**Actual Results:** [To be filled during testing]

**Status:** [ ] Pass [ ] Fail [ ] Blocked

---

## 8. Backup and Recovery Tests

### Test Case 8.1: ETCD Backup Creation
**Test ID:** BACKUP-001  
**Priority:** Critical  
**Objective:** Verify ETCD backup is created successfully

**Test Steps:**
1. Run etcd-backup.sh script
2. Verify snapshot file created
3. Check snapshot integrity
4. Verify compression
5. Check S3 upload (if configured)
6. Verify backup logs

**Expected Results:**
- Snapshot created successfully
- Snapshot passes integrity check
- File compressed with gzip
- Upload to S3 succeeds
- Backup logged correctly
- Old backups cleaned up

**Actual Results:** [To be filled during testing]

**Commands:**
```bash
# Run backup
sudo /home/claude/easypay-ha-infrastructure/scripts/etcd-backup.sh

# Verify
ls -lh /backup/etcd/
ETCDCTL_API=3 etcdctl snapshot status /backup/etcd/latest.db
```

**Status:** [ ] Pass [ ] Fail [ ] Blocked

---

### Test Case 8.2: ETCD Restore Test
**Test ID:** BACKUP-002  
**Priority:** Critical  
**Objective:** Verify ETCD can be restored from backup

**Test Steps:**
1. Note current cluster state
2. Create test resources
3. Take ETCD backup
4. Simulate disaster (delete resources)
5. Restore from backup
6. Verify cluster state restored
7. Verify test resources exist

**Expected Results:**
- Backup restores successfully
- Cluster returns to backed-up state
- All resources restored correctly
- No data corruption
- Applications work after restore

**Actual Results:** [To be filled during testing]

**Status:** [ ] Pass [ ] Fail [ ] Blocked

---

### Test Case 8.3: Automated Backup Schedule
**Test ID:** BACKUP-003  
**Priority:** Medium  
**Objective:** Verify automated backups run on schedule

**Test Steps:**
1. Configure cron job for backups
2. Verify cron schedule (every 6 hours)
3. Wait for scheduled backup
4. Verify backup created automatically
5. Check notification sent (if configured)
6. Verify backup rotation

**Expected Results:**
- Cron job configured correctly
- Backups run every 6 hours
- No manual intervention needed
- Notifications sent on completion
- Old backups deleted after 7 days

**Actual Results:** [To be filled during testing]

**Status:** [ ] Pass [ ] Fail [ ] Blocked

---

## 9. Performance Tests

### Test Case 9.1: Load Testing
**Test ID:** PERF-001  
**Priority:** High  
**Objective:** Verify system handles expected load

**Test Steps:**
1. Define load test parameters (1000 users)
2. Run load test using Apache Bench or k6
3. Monitor response times
4. Monitor error rates
5. Check resource utilization
6. Verify auto-scaling triggers
7. Analyze results

**Expected Results:**
- 99% requests succeed
- Average response time <1s
- 95th percentile <2s
- Error rate <1%
- System scales automatically
- No out-of-memory errors

**Actual Results:** [To be filled during testing]

**Commands:**
```bash
# Using Apache Bench
ab -n 10000 -c 100 http://<ALB-DNS>/api/health

# Using k6
k6 run load-test.js
```

**Status:** [ ] Pass [ ] Fail [ ] Blocked

---

### Test Case 9.2: Database Connection Pool
**Test ID:** PERF-002  
**Priority:** Medium  
**Objective:** Verify database connection pooling works efficiently

**Test Steps:**
1. Configure connection pool settings
2. Monitor database connections
3. Run concurrent requests
4. Check connection reuse
5. Verify timeout handling
6. Test connection recovery

**Expected Results:**
- Connection pool configured correctly
- Connections reused efficiently
- No connection leaks
- Timeouts handled gracefully
- Connections recover from failures

**Actual Results:** [To be filled during testing]

**Status:** [ ] Pass [ ] Fail [ ] Blocked

---

## 10. Security Tests

### Test Case 10.1: Pod Security
**Test ID:** SEC-001  
**Priority:** High  
**Objective:** Verify pods follow security best practices

**Test Steps:**
1. Check pod security contexts
2. Verify non-root users
3. Check read-only root filesystem
4. Verify no privileged containers
5. Check capability drops
6. Verify resource limits

**Expected Results:**
- Pods run as non-root
- Root filesystem read-only where possible
- No privileged containers
- Unnecessary capabilities dropped
- Resource limits enforced

**Actual Results:** [To be filled during testing]

**Status:** [ ] Pass [ ] Fail [ ] Blocked

---

### Test Case 10.2: Secrets Management
**Test ID:** SEC-002  
**Priority:** Critical  
**Objective:** Verify secrets are handled securely

**Test Steps:**
1. Verify database credentials in Secret
2. Check secret encryption at rest
3. Verify secrets not in environment variables listing
4. Test secret rotation
5. Verify RBAC for secret access

**Expected Results:**
- Credentials stored in Secrets
- Secrets encrypted
- Secrets not exposed in logs
- Secret rotation works
- Only authorized pods access secrets

**Actual Results:** [To be filled during testing]

**Status:** [ ] Pass [ ] Fail [ ] Blocked

---

## Test Execution Summary

**Total Test Cases:** 32  
**Executed:** [To be filled]  
**Passed:** [To be filled]  
**Failed:** [To be filled]  
**Blocked:** [To be filled]  
**Pass Rate:** [To be calculated]  

## Critical Issues Found

[To be documented during testing]

## Recommendations

[To be provided after testing]

## Sign-off

**Tester Name:** _______________  
**Date:** _______________  
**Signature:** _______________
