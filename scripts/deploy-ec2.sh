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

# 3. Ensure Nginx is installed, configured, running, and reloaded
echo "3. Configuring and reloading Nginx..."
RELOAD_COMMANDS=$(cat <<'EOF'
  # Check if nginx service exists, install if missing
  if ! systemctl list-unit-files --type=service | grep -q nginx; then
    echo "Nginx service not found. Installing Nginx..."
    if command -v apt-get >/dev/null 2>&1; then
      sudo apt-get update -y
      sudo apt-get install -y nginx
    elif command -v dnf >/dev/null 2>&1; then
      sudo dnf install -y nginx
    elif command -v yum >/dev/null 2>&1; then
      sudo yum install -y nginx
    else
      echo "Error: Package manager not supported. Please install Nginx manually."
      exit 1
    fi
    
    echo "Enabling and starting Nginx..."
    sudo systemctl enable nginx
    sudo systemctl start nginx
  fi

  # Automatically setup basic catch-all Nginx block if none exists
  if [ ! -f /etc/nginx/sites-available/alphapay ] && [ ! -f /etc/nginx/conf.d/alphapay.conf ]; then
    echo "No Nginx configuration found for AlphaPay. Setting up default config..."
    
    NGINX_CONF='server {
    listen 80;
    server_name _;
    root /var/www/alphapay;
    index index.html;
    location / {
        try_files $uri $uri/ /index.html;
    }
}'

    if [ -d /etc/nginx/sites-available ]; then
      echo "$NGINX_CONF" | sudo tee /etc/nginx/sites-available/alphapay > /dev/null
      sudo ln -sf /etc/nginx/sites-available/alphapay /etc/nginx/sites-enabled/
      sudo rm -f /etc/nginx/sites-enabled/default
    elif [ -d /etc/nginx/conf.d ]; then
      echo "$NGINX_CONF" | sudo tee /etc/nginx/conf.d/alphapay.conf > /dev/null
    fi
  fi

  echo "Reloading Nginx server..."
  sudo systemctl reload nginx || sudo systemctl restart nginx
EOF
)

if [ -n "$SSH_KEY_PATH" ]; then
  ssh -o StrictHostKeyChecking=no -i "$SSH_KEY_PATH" "$EC2_USER@$EC2_HOST" "$RELOAD_COMMANDS"
else
  ssh -o StrictHostKeyChecking=no "$EC2_USER@$EC2_HOST" "$RELOAD_COMMANDS"
fi

echo "=== Remote Deployment Finished Successfully ==="
