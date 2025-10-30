#!/bin/bash
################################################################################
# ETCD Backup Script for Kubernetes Cluster
# Description: Creates snapshot of ETCD database for disaster recovery
# Author: DevOps Team
# Version: 1.0
################################################################################

set -e

# Configuration
BACKUP_DIR="/backup/etcd"
RETENTION_DAYS=7
ETCD_ENDPOINTS="https://127.0.0.1:2379"
ETCD_CACERT="/etc/kubernetes/pki/etcd/ca.crt"
ETCD_CERT="/etc/kubernetes/pki/etcd/server.crt"
ETCD_KEY="/etc/kubernetes/pki/etcd/server.key"
S3_BUCKET="easypay-etcd-backups"
AWS_REGION="us-east-1"
LOG_FILE="/var/log/etcd-backup.log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"
    exit 1
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$LOG_FILE"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$LOG_FILE"
}

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   error "This script must be run as root"
fi

# Create backup directory if it doesn't exist
mkdir -p "$BACKUP_DIR"

# Set ETCDCTL API version
export ETCDCTL_API=3

# Generate timestamp
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
BACKUP_FILE="$BACKUP_DIR/etcd-snapshot-$TIMESTAMP.db"

log "=========================================="
log "Starting ETCD Backup Process"
log "=========================================="

# Check if etcdctl is installed
if ! command -v etcdctl &> /dev/null; then
    error "etcdctl is not installed. Please install it first."
fi

# Verify ETCD certificates exist
if [[ ! -f "$ETCD_CACERT" ]] || [[ ! -f "$ETCD_CERT" ]] || [[ ! -f "$ETCD_KEY" ]]; then
    error "ETCD certificates not found. Please check the certificate paths."
fi

# Check ETCD health
log "Checking ETCD cluster health..."
HEALTH_CHECK=$(etcdctl \
    --endpoints=$ETCD_ENDPOINTS \
    --cacert=$ETCD_CACERT \
    --cert=$ETCD_CERT \
    --key=$ETCD_KEY \
    endpoint health 2>&1)

if [[ $? -ne 0 ]]; then
    error "ETCD cluster is not healthy: $HEALTH_CHECK"
fi

success "ETCD cluster is healthy"

# Create snapshot
log "Creating ETCD snapshot: $BACKUP_FILE"
etcdctl snapshot save "$BACKUP_FILE" \
    --endpoints=$ETCD_ENDPOINTS \
    --cacert=$ETCD_CACERT \
    --cert=$ETCD_CERT \
    --key=$ETCD_KEY

if [[ $? -ne 0 ]]; then
    error "Failed to create ETCD snapshot"
fi

success "ETCD snapshot created successfully"

# Verify snapshot
log "Verifying snapshot integrity..."
SNAPSHOT_STATUS=$(etcdctl snapshot status "$BACKUP_FILE" -w json 2>&1)

if [[ $? -ne 0 ]]; then
    error "Snapshot verification failed: $SNAPSHOT_STATUS"
fi

# Extract snapshot info
TOTAL_KEYS=$(echo "$SNAPSHOT_STATUS" | jq -r '.totalKey')
TOTAL_SIZE=$(echo "$SNAPSHOT_STATUS" | jq -r '.totalSize')

success "Snapshot verified - Keys: $TOTAL_KEYS, Size: $TOTAL_SIZE bytes"

# Compress snapshot
log "Compressing snapshot..."
gzip -f "$BACKUP_FILE"
COMPRESSED_FILE="${BACKUP_FILE}.gz"

if [[ ! -f "$COMPRESSED_FILE" ]]; then
    error "Failed to compress snapshot"
fi

COMPRESSED_SIZE=$(du -h "$COMPRESSED_FILE" | cut -f1)
success "Snapshot compressed - Size: $COMPRESSED_SIZE"

# Upload to S3 (optional)
if command -v aws &> /dev/null; then
    log "Uploading snapshot to S3..."
    aws s3 cp "$COMPRESSED_FILE" "s3://$S3_BUCKET/$(basename $COMPRESSED_FILE)" \
        --region "$AWS_REGION" \
        --storage-class STANDARD_IA

    if [[ $? -eq 0 ]]; then
        success "Snapshot uploaded to S3 successfully"
    else
        warning "Failed to upload snapshot to S3, but local backup is available"
    fi
else
    warning "AWS CLI not found. Skipping S3 upload."
fi

# Cleanup old backups
log "Cleaning up old backups (keeping last $RETENTION_DAYS days)..."
find "$BACKUP_DIR" -name "etcd-snapshot-*.db.gz" -type f -mtime +$RETENTION_DAYS -delete

if [[ $? -eq 0 ]]; then
    success "Old backups cleaned up successfully"
else
    warning "Failed to cleanup old backups"
fi

# List recent backups
log "Recent backups:"
ls -lh "$BACKUP_DIR" | tail -n 5 | tee -a "$LOG_FILE"

# Send notification (optional)
if command -v curl &> /dev/null && [[ -n "${SLACK_WEBHOOK_URL:-}" ]]; then
    log "Sending notification to Slack..."
    curl -X POST "$SLACK_WEBHOOK_URL" \
        -H 'Content-Type: application/json' \
        -d "{
            \"text\": \"✅ ETCD Backup Completed\",
            \"attachments\": [{
                \"color\": \"good\",
                \"fields\": [
                    {\"title\": \"Timestamp\", \"value\": \"$TIMESTAMP\", \"short\": true},
                    {\"title\": \"Size\", \"value\": \"$COMPRESSED_SIZE\", \"short\": true},
                    {\"title\": \"Keys\", \"value\": \"$TOTAL_KEYS\", \"short\": true},
                    {\"title\": \"Status\", \"value\": \"Success\", \"short\": true}
                ]
            }]
        }" &> /dev/null
fi

log "=========================================="
log "ETCD Backup Process Completed Successfully"
log "Backup File: $COMPRESSED_FILE"
log "=========================================="

# Exit successfully
exit 0
