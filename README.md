
# ShikshaSpace Infrastructure

Zero-downtime production deployment with Blue-Green strategy.

---

## Services & Endpoints

### **UI Service**
- **Domain**: https://shubhamsinghrajput.com
- **Ports**: 7500 (Blue), 7510 (Green)
- **Tech**: Vaadin 24.5 + Spring Boot 3.5.6

### **User Service**
- **Domain**: https://users.shubhamsinghrajput.com
- **Ports**: 7501 (Blue), 7511 (Green)
- **Tech**: Spring WebFlux + R2DBC + PostgreSQL

### **ShikshaSpace Service**
- **Domain**: https://shikshaspace.shubhamsinghrajput.com
- **Ports**: 7502 (Blue), 7512 (Green)
- **Tech**: Spring WebFlux + MongoDB

### **Keycloak**
- **Domain**: https://keycloak.shubhamsinghrajput.com
- **Port**: 8080
- **OAuth2/OIDC**: Realm `shikshaspace`

---

## Deployment

### Deploy All Services
./scripts/deploy.sh all

text

### Deploy Specific Service
./scripts/deploy.sh user-service v1.0.39
./scripts/deploy.sh shikshaspace-service v1.0.26
./scripts/deploy.sh shikshaspace-ui v1.0.9

text

### Monitor Health
./scripts/monitor.sh

text

---

## Envoy Admin
- **URL**: http://localhost:9901
- **Health Check**: `curl http://localhost:9901/clusters`
- **Stats**: `curl http://localhost:9901/stats`

---

## Quick Commands

View logs
docker logs user-service-blue -f

Check status
docker ps | grep user-service

Restart Envoy
cd envoy && docker compose restart

