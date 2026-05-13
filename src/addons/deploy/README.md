# AgentKit Add-on: Deploy Scripts Pack

Production-grade deployment scripts for Docker Swarm with zero-downtime deploys, rollback, backup/restore, and security gates.

## What's Included

### Core Scripts
- `deploy.sh` — Main deployment orchestrator (full or backend-only scope)
- `bootstrap.sh` — Environment bootstrapping (first-time setup)
- `rollback.sh` — Rollback to previous deployment
- `validate-env.sh` — Pre-deploy environment variable validation
- `healthcheck.sh` — Service health check
- `smoke-test.sh` — Post-deploy smoke test

### Database Management
- `backup-postgres.sh` — PostgreSQL backup automation
- `restore-postgres.sh` — PostgreSQL restore from backup
- `pre-migration-check.sh` — Pre-flight migration validation
- `restore-all-before-migrations.sh` — Full snapshot restore before migrations
- `snapshot-volumes.sh` — Volume snapshot for disaster recovery

### Security & Secrets
- `load-secrets.sh` — Load deployment secrets into shell env
- `generate-secrets-from-env.sh` — Generate Docker secrets from .env
- `security-review-check.sh` — Security compliance gate
- `killswitch-test.sh` — Emergency killswitch validation

### Infrastructure
- `docker-entrypoint.sh` — Container entrypoint template
- `autoscale.sh` — Docker Swarm autoscaling management
- `normalize-swarm-hosts-env.sh` — Swarm host normalization

### Templates
- `docker-compose.yml` — Multi-service dev/test stack
- `stack.yml` — Docker Swarm production stack
- `stack-multinode.yml` — Multi-node Swarm configuration
- `.env.example` — Environment variable template

## Deploy Flow

```
validate-env → load-secrets → pre-migration-check → deploy → healthcheck → smoke-test
                                                                    ↓ (fail)
                                                                rollback
```

## Installation

```bash
# Copy to your project
cp -r src/addons/deploy/scripts/ your-project/deploy/scripts/
cp src/addons/deploy/templates/* your-project/deploy/

# Edit .env from example
cp your-project/deploy/.env.example your-project/deploy/.env

# First deploy
cd your-project/deploy && ./scripts/bootstrap.sh && ./scripts/deploy.sh
```

## Prerequisites

- Docker Swarm initialized (`docker swarm init`)
- SSH access to production server
- PostgreSQL for database features
