# AlphaPay – AWS Deployment Guide

*Interactive Source Diagram:* 🌐 **[Open/Edit in Draw.io (Google Drive)](https://drive.google.com/file/d/1hs1qO98tOMvZOIirGhfb_jUCJuWc1JQX/view?usp=sharing)**

This guide details the step-by-step procedures to build, deploy, and distribute the AlphaPay fintech platform on AWS using three hosting options:

*   **Option A: S3 Serverless Hosting (Recommended)** – Ultra-cost-effective, serverless, zero-maintenance.
*   **Option B: EC2 Virtual Server Hosting** – Self-hosted virtual Linux instance with Nginx and SSL.
*   **Option C: Hybrid EC2 + S3 Sync Hosting** – Static files served from EC2 Nginx but automatically synced/pulled from an S3 bucket source.

---

## Option A: S3 Serverless Hosting (Recommended)

### Architecture
```
User → CloudFront (CDN + SSL) → S3 Bucket (Private static files)
           ↑
     GitHub Actions (CI/CD)
     builds & deploys on push to main
```

### 1. Create Private S3 Bucket
Run these commands via the AWS CLI or create the bucket in the AWS Console:
```bash
# Create S3 bucket (replace region as needed)
aws s3api create-bucket \
  --bucket alphapay-africa-static \
  --region us-east-1

# Enable static website hosting
aws s3 website s3://alphapay-africa-static \
  --index-document index.html \
  --error-document 404.html
```

### 2. Configure S3 Bucket Policy (OAC Only)
To prevent users from bypassing CloudFront and accessing S3 directly, attach the following policy to allow access ONLY from CloudFront Origin Access Control (OAC):
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowCloudFrontServicePrincipalReadOnly",
      "Effect": "Allow",
      "Principal": {
        "Service": "cloudfront.amazonaws.com"
      },
      "Action": "s3:GetObject",
      "Resource": "arn:aws:s3:::alphapay-africa-static/*",
      "Condition": {
        "StringEquals": {
          "AWS:SourceArn": "arn:aws:cloudfront::YOUR_ACCOUNT_ID:distribution/YOUR_CLOUDFRONT_DISTRIBUTION_ID"
        }
      }
    }
  ]
}
```

### 3. Setup CloudFront Distribution
1. Go to **AWS CloudFront Console** → **Create Distribution**.
2. **Origin Domain**: Select the S3 bucket created above.
3. **Origin Access**: Choose **Origin Access Control (OAC)** and create control settings.
4. **Default Root Object**: Enter `index.html`.
5. **Viewer Protocol Policy**: Select **Redirect HTTP to HTTPS**.
6. **SSL Certificate**: Generate an SSL certificate for your domain (`alphapay.africa`) via **AWS Certificate Manager (ACM)** in us-east-1 and attach it.
7. Set alternate domain names (CNAMEs): `alphapay.africa`, `www.alphapay.africa`.
8. **SPA Routing Fallback (Custom Error Responses)**:
   To prevent `403 Forbidden` or `404 Not Found` when directly accessing subpaths (like `/signup/` or `/signin/`), you must configure CloudFront custom error responses:
   - Go to the **Error pages** tab of your distribution.
   - Click **Create custom error response**.
   - Select **403: Forbidden**. Set *Customize error response* to **Yes**, *Response page path* to `/index.html`, and *HTTP response code* to **200: OK**.
   - Repeat the exact same steps to create a custom error response for **404: Not Found** (re-routing it to `/index.html` with a **200: OK** response).

### 4. Astro Configuration Requirements
To ensure the build outputs align with CloudFront routing, make sure `astro.config.mjs` has the following options configured:
```javascript
import { defineConfig } from 'astro/config';

export default defineConfig({
  trailingSlash: 'always', // Forces pages to compile as folders with index.html
  base: '/',              // Ensures relative root paths are loaded
  output: 'static'        // Explicitly declares static routing
});
```

### 5. Setup GitHub Actions CI/CD
Add these repository secrets on GitHub under `Settings → Secrets and variables → Actions`:
*   `AWS_ACCESS_KEY_ID`: Your IAM deployment access key.
*   `AWS_SECRET_ACCESS_KEY`: Your IAM deployment secret.
*   `CLOUDFRONT_DISTRIBUTION_ID`: The ID of your CloudFront distribution.

The CI/CD workflow `.github/workflows/deploy-s3.yml` runs automatically on pushes to `main`.

---

## Option B: EC2 Virtual Server Hosting with Nginx

### Architecture
```
User → Route 53 (DNS) → CloudFront (CDN + SSL) → Nginx (EC2 Instance Server)
                                                     ↑
                                               GitHub Actions / rsync
```

### 1. Launch the EC2 Instance
1. Open the **Amazon EC2 Console** → click **Launch Instance**.
2. **Name**: `alphapay-web-server`.
3. **OS Image (AMI)**: Select **Ubuntu Server 24.04 LTS** (Free Tier eligible).
4. **Instance Type**: Select **t2.micro** or **t3.micro**.
5. **Key Pair**: Select or create a new key pair (e.g. `alphapay-key.pem`) to access the instance over SSH.
6. **Network Settings** (Security Group):
    *   Create a Security Group: `alphapay-web-sg`.
    *   Add the following inbound rules:
        *   **SSH (Port 22)**: Set Source to **My IP** (highly recommended for security).
        *   **HTTP (Port 80)**: Set Source to **Anywhere** (0.0.0.0/0).
        *   **HTTPS (Port 443)**: Set Source to **Anywhere** (0.0.0.0/0).

### 2. Allocate and Associate an Elastic IP
To ensure the server public IP remains static across restarts:
1. Go to **EC2 Console** → **Network & Security** → **Elastic IPs**.
2. Click **Allocate Elastic IP address** → **Allocate**.
3. Select the allocated IP → click **Actions** → **Associate Elastic IP address**.
4. Choose **Instance** → select `alphapay-web-server` → click **Associate**.

### 3. Install Nginx and Dependencies
SSH into your instance:
```bash
ssh -i "alphapay-key.pem" ubuntu@YOUR_EC2_PUBLIC_IP
```
Update server packages and install Nginx:
```bash
sudo apt update -y && sudo apt upgrade -y
sudo apt install nginx -y
sudo systemctl enable nginx
sudo systemctl start nginx
```

### 4. Configure Nginx Server Blocks
1. Create a directory to store the Astro built web files:
```bash
sudo mkdir -p /var/www/alphapay
sudo chown -R ubuntu:ubuntu /var/www/alphapay
```
2. Create an Nginx server configuration:
```bash
sudo nano /etc/nginx/sites-available/alphapay
```
3. Paste the following configuration, replacing domain names with your own:
```nginx
server {
    listen 80;
    server_name alphapay.africa www.alphapay.africa;

    root /var/www/alphapay;
    index index.html;

    # Handle client-side routing fallback for Astro static SPA
    location / {
        try_files $uri $uri/ /index.html;
    }

    # Custom 404 handler
    error_page 404 /404.html;

    # Performance optimizations - cache static assets
    location ~* \.(?:css|js)$ {
        expires 1y;
        access_log off;
        add_header Cache-Control "public, max-age=31536000, immutable";
    }

    location ~* \.(?:ico|gif|jpe?g|png|woff2?|eot|otf|ttf|svg)$ {
        expires 30d;
        access_log off;
        add_header Cache-Control "public, max-age=2592000";
    }
}
```
4. Enable the configuration and restart Nginx:
```bash
sudo ln -sf /etc/nginx/sites-available/alphapay /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default
sudo nginx -t
sudo systemctl restart nginx
```

### 5. Build and Deploy Web Files
On your local computer or CI/CD runner:
1. Build the Astro static files:
```bash
npm install
npm run build
```
2. Deploy the build output (`dist/` folder) to the EC2 server:
```bash
rsync -avz --delete -e "ssh -i alphapay-key.pem" dist/ ubuntu@YOUR_EC2_PUBLIC_IP:/var/www/alphapay/
```

### 6. Configure SSL Certificate via Let's Encrypt (Certbot)
Run the following inside your EC2 terminal to obtain a free SSL certificate:
```bash
sudo apt install certbot python3-certbot-nginx -y
sudo certbot --nginx -d alphapay.africa -d www.alphapay.africa
# Certbot will verify the domains and configure the HTTPS settings inside Nginx automatically.
```

### 7. Configure CloudFront as a CDN for the EC2 Instance
To cache content globally and protect the EC2 instance from DDoS attacks:
1. Open the **AWS CloudFront Console** → **Create Distribution**.
2. **Origin Domain**: Enter your EC2 **Elastic IP** or public DNS name (e.g. `ec2-xx-xx-xx-xx.compute-1.amazonaws.com`).
3. **Protocol**: Select **HTTPS Only** (to keep the link between CloudFront and Nginx encrypted).
4. **Behavior**:
    *   **Viewer Protocol Policy**: Select **Redirect HTTP to HTTPS**.
    *   **Allowed HTTP Methods**: `GET, HEAD, OPTIONS`.
5. **Cache Key & Origin Requests**: Select **CacheOptimized**.
6. **SSL Certificate**: Generate/Attach the ACM SSL certificate matching `alphapay.africa` to the distribution.

### 8. Setup GitHub Actions CI/CD (Automated EC2 Pipeline)
To automate the build and deployment process to your EC2 instance on every push to the `main` branch:

1. **Configure Environment Secrets**:
   Go to your GitHub repository → **Settings** → **Secrets and variables** → **Actions** → **New environment secret** under the `end-to-end-cloud` environment:
   - `EC2_HOST`: The public IP or DNS name of your EC2 instance.
   - `EC2_USERNAME`: The SSH login username (e.g., `ec2-user` or `ubuntu`).
   - `EC2_SSH_KEY`: The contents of your private SSH key (`.pem` file).

2. **How the Automated Pipeline Works**:
   The workflow defined in `.github/workflows/deploy-ec2.yml` runs automatically and performs the following actions:
   - **Code Checkout**: Clones the codebase onto the GitHub runner.
   - **Runner Build**: Installs dependencies and compiles the Astro static build into `dist/` on the runner, avoiding memory exhaustion issues on smaller EC2 instances (like `t2.micro`).
   - **Pre-deploy Prep**: Connects via SSH to prepare `/var/www/alphapay` on the EC2 instance and sets ownership permissions.
   - **Rsync Sync**: Copies the built files from the runner using `rsync` directly to the target directory.
   - **Self-Healing Nginx**:
     - Automatically stops conflicting web services like Apache (`httpd` or `apache2`).
     - Checks if Nginx is installed, and automatically installs it if missing (supporting Ubuntu, Amazon Linux 2023, and CentOS/RHEL).
     - Modifies the default Nginx configuration (`/etc/nginx/nginx.conf`) to change the default listen port to `8080` to prevent conflicts on port 80.
     - Configures a catch-all block for AlphaPay on port 80 if no prior configuration exists, making the site immediately active at the EC2 public IP.
     - Restarts/reloads Nginx to serve the newly deployed files.

---

## Option C: Hybrid EC2 + S3 Sync Hosting (Automated Static Pull)

### Architecture
```
GitHub Actions (CI/CD) → S3 Bucket (Private source)
                               ↑ (IAM Role read sync)
                         EC2 Instance (Nginx pulls from S3 via cron)
                               ↑
                         CloudFront (CDN + SSL)
```

In this option, the CI/CD pipeline remains simple and only pushes static files to the private S3 bucket. The EC2 instance securely pulls/syncs files from S3 to Nginx's local `/var/www/alphapay` directory using an IAM Role.

### 1. Create and Attach IAM Role to EC2
To authorize the EC2 instance to pull files from S3 without hardcoding secret keys:
1. Go to the **IAM Console** → **Roles** → **Create Role**.
2. **Select Trusted Entity**: Choose **AWS Service** → **EC2**.
3. **Permissions**: Attach the **AmazonS3ReadOnlyAccess** managed policy.
4. **Name**: `alphapay-ec2-s3-role`.
5. Go to the **EC2 Console** → select your instance → click **Actions** → **Security** → **Modify IAM role**.
6. Select `alphapay-ec2-s3-role` and click **Update IAM role**.

### 2. Configure Nginx Server Blocks
Setup Nginx to serve the `/var/www/alphapay` directory (use the same Nginx configuration detailed in **Option B, Step 4**).

### 3. Install AWS CLI on the EC2 Server
Connect to your EC2 instance via SSH and install the AWS Command Line Interface:
```bash
sudo apt update -y
sudo apt install unzip -y
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
# Verify integration (should list files without needing config keys)
aws s3 ls s3://alphapay-africa-static
```

### 4. Create the S3 Auto-Sync Script
1. Create the sync script:
```bash
sudo nano /usr/local/bin/sync-s3-to-nginx.sh
```
2. Paste this script inside (make sure to replace with your S3 bucket name):
```bash
#!/bin/bash
# Sync files from S3 to Nginx root directory
aws s3 sync s3://alphapay-africa-static /var/www/alphapay/ --delete

# Set permissions
chown -R ubuntu:ubuntu /var/www/alphapay/
chmod -R 755 /var/www/alphapay/
```
3. Make the script executable:
```bash
sudo chmod +x /usr/local/bin/sync-s3-to-nginx.sh
```

### 5. Schedule Automated Sync via Cron
To check for and pull S3 updates automatically every 2 minutes:
1. Open the crontab editor:
```bash
crontab -e
```
2. Add this line at the bottom of the file:
```cron
*/2 * * * * /usr/local/bin/sync-s3-to-nginx.sh > /dev/null 2>&1
```

### 6. Configure SSL (Certbot) & CloudFront CDN
Refer to **Option B, Steps 6 & 7** to configure Let's Encrypt SSL certificates for Nginx and route traffic securely through a CloudFront CDN.

---

## Custom Domain Setup (Route 53)
Create an Alias record pointing your domain to the CloudFront distribution:
```bash
# UPSERT Route 53 CNAME/A Alias to Route requests to CloudFront
aws route53 change-resource-record-sets \
  --hosted-zone-id YOUR_ZONE_ID \
  --change-batch '{
    "Changes": [{
      "Action": "UPSERT",
      "ResourceRecordSet": {
        "Name": "alphapay.africa",
        "Type": "A",
        "AliasTarget": {
          "HostedZoneId": "Z2FDTNDATAQYW2",
          "DNSName": "YOUR_CLOUDFRONT_DOMAIN.cloudfront.net.",
          "EvaluateTargetHealth": false
        }
      }
    }]
  }'
```

---

*Built by Team Alpha — Azubi Africa Internship Programme, Project 1: End-to-End Cloud Solution Design & Deployment*
