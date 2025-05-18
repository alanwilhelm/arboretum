# Arboretum Deployment Guide

This guide describes how to deploy the Arboretum Phoenix application to the production server.

## Server Information

- **Server**: norcal-pub
- **IP Address**: 54.153.44.7
- **OS**: Ubuntu 22.04.5 LTS
- **User**: ubuntu
- **SSH Key**: `~/.ssh/esprezzo/norcal-pub.pem`

## Prerequisites

The following should already be installed on the server (see ELIXIR_ASDF_INSTALLATION.md):
- ASDF
- Erlang 27.3.4
- Elixir 1.18.3
- Phoenix 1.7.21

Additional requirements:
- PostgreSQL
- Node.js (for assets compilation)

## Setup PostgreSQL

1. Install PostgreSQL:
```bash
sudo apt-get install postgresql postgresql-contrib
```

2. Configure PostgreSQL:
```bash
sudo -u postgres psql
CREATE USER arboretum_prod WITH PASSWORD 'your_secure_password';
CREATE DATABASE arboretum_prod;
GRANT ALL PRIVILEGES ON DATABASE arboretum_prod TO arboretum_prod;
\q
```

## Application Deployment

### 1. Prepare the Server

Create the application directory:
```bash
sudo mkdir -p /var/www/arboretum
sudo chown ubuntu:ubuntu /var/www/arboretum
```

### 2. Setup Environment Variables

Create the environment file:
```bash
cat > /var/www/arboretum/.env << 'EOF'
PHX_HOST=arboretum.esprezzo.io
PORT=4000
DATABASE_URL=ecto://arboretum_prod:your_secure_password@localhost/arboretum_prod
SECRET_KEY_BASE=$(mix phx.gen.secret)
MIX_ENV=prod
PHX_SERVER=true
EOF
```

### 3. Build and Deploy

The deployment can be done manually or through CI/CD:

#### Manual Deployment

1. On your local machine, build the release:
```bash
MIX_ENV=prod mix deps.get
MIX_ENV=prod mix compile
MIX_ENV=prod mix assets.deploy
MIX_ENV=prod mix phx.gen.release
MIX_ENV=prod mix release
```

2. Copy the release to the server:
```bash
scp -i ~/.ssh/esprezzo/norcal-pub.pem \
  _build/prod/rel/arboretum/arboretum-*.tar.gz \
  ubuntu@54.153.44.7:/var/www/arboretum/
```

3. On the server, extract and run:
```bash
cd /var/www/arboretum
tar -xzf arboretum-*.tar.gz
source .env
./bin/arboretum eval "Arboretum.Release.migrate"
./bin/arboretum daemon
```

#### CI/CD Deployment

See `.github/workflows/ci.yml` for automated deployment configuration.

## Service Configuration

Create a systemd service:
```bash
sudo cat > /etc/systemd/system/arboretum.service << 'EOF'
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
EOF

sudo systemctl enable arboretum
sudo systemctl start arboretum
```

## Nginx Configuration

If you want to use Nginx as a reverse proxy:

1. Install Nginx:
```bash
sudo apt-get install nginx
```

2. Configure Nginx:
```bash
sudo cat > /etc/nginx/sites-available/arboretum << 'EOF'
server {
    listen 80;
    server_name arboretum.esprezzo.io;

    location / {
        proxy_pass http://localhost:4000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
    }
}
EOF

sudo ln -s /etc/nginx/sites-available/arboretum /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl restart nginx
```

## SSL Configuration

Use certbot for SSL certificates:
```bash
sudo apt-get install certbot python3-certbot-nginx
sudo certbot --nginx -d arboretum.esprezzo.io
```

## Monitoring

Check application status:
```bash
sudo systemctl status arboretum
sudo journalctl -u arboretum -f
```

## Database Migrations

Run migrations:
```bash
cd /var/www/arboretum
./bin/arboretum eval "Arboretum.Release.migrate"
```

## Rolling Updates

For updates without downtime:
1. Build a new release locally
2. Upload to server
3. Use the following commands:
```bash
cd /var/www/arboretum
./bin/arboretum stop
tar -xzf arboretum-new-version.tar.gz
./bin/arboretum daemon
```

## Troubleshooting

### Check logs
```bash
sudo journalctl -u arboretum -n 100
```

### Check database connection
```bash
cd /var/www/arboretum
./bin/arboretum remote
Arboretum.Repo.query("SELECT 1")
```

### Restart the service
```bash
sudo systemctl restart arboretum
```