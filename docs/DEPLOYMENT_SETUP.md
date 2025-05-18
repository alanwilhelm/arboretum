# Deployment Setup Guide

This guide provides step-by-step instructions for setting up deployment for the Arboretum project.

## GitHub Secrets Setup

Before deploying, you need to set up the following secrets in your GitHub repository:

1. Go to Settings > Secrets and variables > Actions
2. Add the following secrets:
   - `SSH_PRIVATE_KEY`: The contents of your `~/.ssh/esprezzo/norcal-pub.pem` file
   - `DATABASE_URL`: `ecto://arboretum_prod:your_password@localhost/arboretum_prod`
   - `SECRET_KEY_BASE`: Generate with `mix phx.gen.secret`

## Server Preparation

1. SSH into the server:
   ```bash
   ssh -i ~/.ssh/esprezzo/norcal-pub.pem ubuntu@54.153.44.7
   ```

2. Run the server preparation script:
   ```bash
   ./scripts/prepare_server.sh
   ```

3. Create the environment file:
   ```bash
   cat > /var/www/arboretum/.env << 'EOF'
   PHX_HOST=arboretum.esprezzo.io
   PORT=4000
   DATABASE_URL=ecto://arboretum_prod:your_password@localhost/arboretum_prod
   SECRET_KEY_BASE=<generate with mix phx.gen.secret>
   MIX_ENV=prod
   PHX_SERVER=true
   EOF
   ```

## Deployment Workflow

The CI/CD pipeline is configured to:

1. Run tests on every push to `main` and `develop` branches
2. Build and deploy to production only when pushing to `main`
3. The deployment process:
   - Builds a release
   - Uploads it to the server
   - Backs up the current release
   - Extracts the new release
   - Runs database migrations
   - Restarts the systemd service

## Manual Deployment

If you need to deploy manually:

1. Build the release locally:
   ```bash
   MIX_ENV=prod mix deps.get
   MIX_ENV=prod mix compile
   MIX_ENV=prod mix assets.deploy
   MIX_ENV=prod mix phx.gen.release
   MIX_ENV=prod mix release
   ```

2. Copy to server:
   ```bash
   scp -i ~/.ssh/esprezzo/norcal-pub.pem \
     _build/prod/rel/arboretum/arboretum-*.tar.gz \
     ubuntu@54.153.44.7:/var/www/arboretum/
   ```

3. SSH into server and deploy:
   ```bash
   cd /var/www/arboretum
   sudo systemctl stop arboretum
   tar -xzf arboretum-*.tar.gz
   rm arboretum-*.tar.gz
   source .env
   ./bin/arboretum eval "Arboretum.Release.migrate"
   sudo systemctl start arboretum
   ```

## Monitoring

Check application status:
```bash
sudo systemctl status arboretum
sudo journalctl -u arboretum -f
```

## SSL Setup

Once the domain is pointed to the server:
```bash
sudo certbot --nginx -d arboretum.esprezzo.io
```

## Troubleshooting

### Database Connection Issues
- Check PostgreSQL is running: `sudo systemctl status postgresql`
- Check the DATABASE_URL in .env file
- Test connection: `psql -U arboretum_prod -h localhost -d arboretum_prod`

### Application Won't Start
- Check logs: `sudo journalctl -u arboretum -n 100`
- Check environment file: `cat /var/www/arboretum/.env`
- Check file permissions: `ls -la /var/www/arboretum/`