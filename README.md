# ShikshaSpace Infrastructure

## Services
- user-service (port 7501)
- shikshaspace-service (port 7502)

## Deployment
1. Update versions in docker-compose.yml
2. Push to GitLab
3. On server: `git pull && ./deploy.sh`

## Traefik Dashboard
http://server-ip:9090
