#!/bin/bash

# Script to prepare the server for Arboretum deployment
# Run this once on a fresh server

set -euo pipefail

echo "=== Preparing server for Arboretum deployment ==="

# Update system
echo "Updating system packages..."
sudo apt-get update
sudo apt-get upgrade -y

# Install PostgreSQL
echo "Installing PostgreSQL..."
sudo apt-get install -y postgresql postgresql-contrib

# Create PostgreSQL user and database
echo "Setting up PostgreSQL database..."
sudo -u postgres psql << EOF
CREATE USER arboretum_prod WITH PASSWORD 'secure_password_here';
CREATE DATABASE arboretum_prod;
GRANT ALL PRIVILEGES ON DATABASE arboretum_prod TO arboretum_prod;
EOF

# Create application directory
echo "Creating application directory..."
sudo mkdir -p /var/www/arboretum
sudo chown ubuntu:ubuntu /var/www/arboretum

# Create systemd service
echo "Creating systemd service..."
sudo bash -c 'cat > /etc/systemd/system/arboretum.service << EOF
[Unit]
Description=Arboretum Phoenix App
After=network.target

[Service]
Type=simple
User=ubuntu
WorkingDirectory=/var/www/arboretum
EnvironmentFile=/var/www/arboretum/.env
ExecStart=/var/www/arboretum/bin/arboretum start
ExecStop=/var/www/arboretum/bin/arboretum stop
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF'

# Enable the service
sudo systemctl enable arboretum

# Install Nginx
echo "Installing Nginx..."
sudo apt-get install -y nginx

# Configure Nginx
echo "Configuring Nginx..."
sudo bash -c 'cat > /etc/nginx/sites-available/arboretum << EOF
server {
    listen 80;
    server_name arboretum.esprezzo.io;

    location / {
        proxy_pass http://localhost:4000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header X-Real-IP \$remote_addr;
    }
}
EOF'

# Enable the site
sudo ln -s /etc/nginx/sites-available/arboretum /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl restart nginx

# Install certbot for SSL
echo "Installing certbot..."
sudo apt-get install -y certbot python3-certbot-nginx

echo "=== Server preparation complete ==="
echo ""
echo "Next steps:"
echo "1. Update the PostgreSQL password in the script"
echo "2. Create .env file in /var/www/arboretum with:"
echo "   PHX_HOST=arboretum.esprezzo.io"
echo "   PORT=4000"
echo "   DATABASE_URL=ecto://arboretum_prod:your_password@localhost/arboretum_prod"
echo "   SECRET_KEY_BASE=<generated with mix phx.gen.secret>"
echo "   MIX_ENV=prod"
echo "   PHX_SERVER=true"
echo "3. Run: sudo certbot --nginx -d arboretum.esprezzo.io"
echo "4. Deploy the application"