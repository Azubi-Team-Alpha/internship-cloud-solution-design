#!/bin/bash
# scripts/deploy-ec2.sh - Script to SSH into EC2 and deploy the latest build files

set -e

# Configuration
EC2_HOST=${1:-$EC2_HOST}
EC2_USER=${2:-"ec2-user"}
SSH_KEY_PATH=${3:-$SSH_KEY_PATH}
WEB_DIR="/var/www/alphapay"

if [ -z "$EC2_HOST" ]; then
  echo "Error: EC2_HOST is not set."
  echo "Usage: $0 <ec2-host> [ec2-user] [ssh-key-path]"
  exit 1
fi

echo "=== Remote Deployment Started ==="
echo "Connecting to EC2 host: $EC2_HOST as $EC2_USER..."

# 1. Ensure the web directory exists on EC2 and is owned by the SSH user
echo "1. Preparing web directory on remote host..."
if [ -n "$SSH_KEY_PATH" ]; then
  ssh -o StrictHostKeyChecking=no -i "$SSH_KEY_PATH" "$EC2_USER@$EC2_HOST" \
    "sudo mkdir -p $WEB_DIR && sudo chown -R $EC2_USER:$EC2_USER $WEB_DIR"
else
  ssh -o StrictHostKeyChecking=no "$EC2_USER@$EC2_HOST" \
    "sudo mkdir -p $WEB_DIR && sudo chown -R $EC2_USER:$EC2_USER $WEB_DIR"
fi

# 2. Copy built files from the runner to the web directory on EC2
echo "2. Copying built files to EC2 web directory..."
if [ -n "$SSH_KEY_PATH" ]; then
  rsync -avz --delete -e "ssh -o StrictHostKeyChecking=no -i $SSH_KEY_PATH" \
    dist/ "$EC2_USER@$EC2_HOST:$WEB_DIR/"
else
  rsync -avz --delete -e "ssh -o StrictHostKeyChecking=no" \
    dist/ "$EC2_USER@$EC2_HOST:$WEB_DIR/"
fi

# 3. Reload Nginx to serve the new files
echo "3. Reloading Nginx server..."
if [ -n "$SSH_KEY_PATH" ]; then
  ssh -o StrictHostKeyChecking=no -i "$SSH_KEY_PATH" "$EC2_USER@$EC2_HOST" "sudo systemctl reload nginx"
else
  ssh -o StrictHostKeyChecking=no "$EC2_USER@$EC2_HOST" "sudo systemctl reload nginx"
fi

echo "=== Remote Deployment Finished Successfully ==="
