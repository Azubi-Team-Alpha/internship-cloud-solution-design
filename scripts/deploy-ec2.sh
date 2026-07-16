#!/bin/bash
# scripts/deploy-ec2.sh - Script to SSH into EC2 and deploy the latest code

set -e

# Configuration
EC2_HOST=${1:-$EC2_HOST}
EC2_USER=${2:-"ubuntu"}
SSH_KEY_PATH=${3:-$SSH_KEY_PATH}
REPO_DIR="/home/ubuntu/internship-cloud-solution-design"
WEB_DIR="/var/www/alphapay"

if [ -z "$EC2_HOST" ]; then
  echo "Error: EC2_HOST is not set."
  echo "Usage: $0 <ec2-host> [ec2-user] [ssh-key-path]"
  exit 1
fi

echo "Connecting to EC2 host: $EC2_HOST as $EC2_USER..."

# Define the commands to execute on the remote EC2 instance
REMOTE_COMMANDS=$(cat <<EOF
  echo "=== Remote Deployment Started ==="
  
  # Ensure the repo directory exists
  if [ ! -d "$REPO_DIR" ]; then
    echo "Error: Repository directory $REPO_DIR does not exist on EC2."
    exit 1
  fi

  cd "$REPO_DIR"
  
  echo "1. Fetching and pulling latest changes from main..."
  git fetch origin main
  git reset --hard origin/main
  
  echo "2. Installing dependencies..."
  npm install
  
  echo "3. Building the Astro project..."
  npm run build
  
  echo "4. Copying built files to web directory..."
  sudo rsync -avz --delete dist/ "$WEB_DIR/"
  
  echo "5. Reloading Nginx server..."
  sudo systemctl reload nginx
  
  echo "=== Remote Deployment Finished Successfully ==="
EOF
)

# Execute commands on EC2 via SSH
if [ -n "$SSH_KEY_PATH" ]; then
  ssh -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=no "$EC2_USER@$EC2_HOST" "$REMOTE_COMMANDS"
else
  ssh -o StrictHostKeyChecking=no "$EC2_USER@$EC2_HOST" "$REMOTE_COMMANDS"
fi
