# 🔐 Auth Service — Microservice JWT

![Node.js](https://img.shields.io/badge/Node.js-20-339933?logo=nodedotjs&logoColor=white)
![Express](https://img.shields.io/badge/Express-4.x-000000?logo=express&logoColor=white)
![Docker](https://img.shields.io/badge/Docker-ready-2496ED?logo=docker&logoColor=white)
![GitHub Actions](https://img.shields.io/badge/GitHub_Actions-CI/CD-2088FF?logo=github&logoColor=white)
![Trivy](https://img.shields.io/badge/Trivy-security_scan-1904DA?logo=aqua&logoColor=white)
![GHCR](https://img.shields.io/badge/GHCR-registry-24292e?logo=github&logoColor=white)

Microservice d'authentification JWT — partie de l'architecture microservices e-commerce déployée sur **Kubernetes** (Helm) ou **Docker Swarm** (Kong Gateway).

> 💡 **Objectif Portfolio** : Ce service illustre le pipeline CI/CD complet avec GitHub Actions — tests → build Docker → scan Trivy → push GitHub Container Registry → déploiement Helm.

---

## 🗺️ Positionnement dans l'Architecture

```
          Frontend (192.168.56.114)
                      │
                      ▼
┌──────────────────────────────────────────────┐
│  Kubernetes Cluster (192.168.56.111)         │
│  Ingress :30080                              │
│  ├── 🔐 auth-service    :3001  ← Ce service  │
│  ├── 📦 product-service :3002                │
│  ├── 🛒 order-service   :3003                │
│  └── ⭐ review-service  :3004                │
└──────────────────────────────────────────────┘
                      │
                      ▼
        MariaDB (192.168.56.115:3306)
  ecommerce_db — partagée par tous les services
```

**Rôle de ce service :** Toutes les requêtes authentifiées des autres services passent par le JWT émis ici.

---

## 📡 Endpoints

| Méthode | Endpoint | Auth | Description |
|---------|----------|:----:|-------------|
| `POST` | `/api/auth/register` | — | Inscription utilisateur |
| `POST` | `/api/auth/login` | — | Connexion → retourne JWT |
| `GET` | `/api/auth/me` | JWT | Profil utilisateur courant |
| `GET` | `/api/auth/health` | — | Liveness probe |
| `GET` | `/api/auth/ready` | — | Readiness probe |
| `GET` | `/api/auth/metrics` | — | Métriques Prometheus |
| `GET` | `/api/auth/info` | — | Version et infos service |

---

## 🔄 Pipeline CI/CD (GitHub Actions)

```
                    GitHub Push / Pull Request
                            │
                            ▼
┌─────────────────────────────────────────────────────────┐
│  Job 1 : Test API (parallèle)                          │
│  └── npm install + test-api.sh : 10-13 tests endpoints  │
│  └── Dépendance : MariaDB 10.11                         │
├─────────────────────────────────────────────────────────┤
│  Job 2 : Dependency Scanning (parallèle)                │
│  └── Trivy FS scan : scanne les vulnérabilités          │
├─────────────────────────────────────────────────────────┤
│  Job 3 : Build Docker Image (après tests réussis)      │
│  └── Docker multi-stage : Node 20 Alpine                │
│  └── Sauvegarde l'image en artefact                     │
├─────────────────────────────────────────────────────────┤
│  Job 4 : Scan Container (main uniquement)              │
│  └── Trivy container scan : détecte vulnérabilités      │
├─────────────────────────────────────────────────────────┤
│  Job 5 : Push to GHCR (main uniquement)                │
│  └── GitHub Container Registry : ghcr.io/...           │
│  └── Tags : commit-sha + latest                        │
└─────────────────────────────────────────────────────────┘
```

**Fichier CI/CD :**
- `.github/workflows/ci.yml` — Pipeline GitHub Actions complète avec tests, scans de sécurité et déploiement

---

## ⚡ Quick Start

```bash
git clone https://gitlab.com/yara_portfolio/devops/ecommerce/microservice/auth-service.git
cd auth-service
cp .env.example .env
nano .env   # Définir DB_HOST, DB_PASSWORD, JWT_SECRET

npm install && npm start
# ✅ http://localhost:3001/api/auth/health
```

---

## 📋 Prérequis

| Outil | Version | Usage |
|-------|---------|-------|
| Node.js | >= 18.0.0 | Runtime |
| npm | >= 9.0.0 | Packages |
| Docker | >= 20.10 | Build & run conteneur |
| MariaDB | 10.11+ | Accès réseau requis |

---

## 📁 Structure du Projet

```
auth-service/
├── src/
│   ├── config/
│   │   └── database.js         # Pool de connexions MariaDB
│   ├── middleware/
│   │   ├── authMiddleware.js   # Vérification JWT
│   │   └── metrics.js          # Collecte métriques Prometheus
│   ├── routes/
│   │   └── auth.js             # register, login, me, health, metrics
│   └── server.js               # Point d'entrée Express
├── testapi/
│   ├── test-api.sh             # Tests intégration endpoints (10-13 tests)
│   ├── data-test-api.sql       # Données de test BD
│   ├── security-scan.sh        # Scan CVE avec Trivy
│   └── git-security-scan.sh    # Détection secrets dans le code
├── Dockerfile
├── Jenkinsfile-ci
├── .gitlab-ci.yml
├── .env.example
└── package.json
```

---

## ⚙️ Variables d'Environnement

| Variable | Description | Valeur | Requis |
|----------|-------------|--------|--------|
| `PORT` | Port du service | `3001` | ✅ |
| `NODE_ENV` | Environnement | `production` | ❌ |
| `DB_HOST` | IP serveur MariaDB | `192.168.56.115` | ✅ |
| `DB_PORT` | Port MariaDB | `3306` | ✅ |
| `DB_NAME` | Base de données | `ecommerce_db` | ✅ |
| `DB_USER` | Utilisateur BD | `devops_user` | ✅ |
| `DB_PASSWORD` | Mot de passe BD | — | ✅ |
| `JWT_SECRET` | Clé secrète JWT (min 32 chars) | — | ✅ |

---

## 🚀 Déploiement

### Local (npm)

```bash
npm install
npm start        # Production
npm run dev      # Développement (nodemon)
```

### Docker

```bash
# Build
docker build -t auth-service:v3.2 .

# Run
docker run -d \
  --name auth-service \
  -p 3001:3001 \
  -e DB_HOST=192.168.56.115 \
  -e DB_PASSWORD=devops_password \
  -e JWT_SECRET=your_secret_min_32_chars \
  auth-service:v3.2
```

### Kubernetes (via Helm Chart)

```bash
# Depuis le repo helm-chart
helm upgrade ecommerce-microservices . \
  --reuse-values \
  --set services.authService.image.tag=v3.2
```

Voir [k8s-helm-chart](https://gitlab.com/yara_portfolio/devops/ecommerce/devops-tools/k8s-helm-chart) pour le déploiement complet.

---

## 📊 Métriques Prometheus

```bash
curl http://localhost:3001/api/auth/metrics
```

Métriques exposées :

```
# Système Node.js
nodejs_heap_size_total_bytes
nodejs_heap_used_bytes
process_cpu_seconds_total

# HTTP
http_requests_total{method, route, status_code}
http_request_duration_seconds
http_request_errors_total
```

---

## 🧪 Tests

```bash
# Health & Readiness
curl http://localhost:3001/api/auth/health
curl http://localhost:3001/api/auth/ready

# Inscription
curl -X POST http://localhost:3001/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{"email":"test@test.com","password":"password123","name":"Test User"}'

# Connexion → JWT
curl -X POST http://localhost:3001/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"admin@ecommerce.com","password":"admin123"}'

# Profil (avec token)
curl http://localhost:3001/api/auth/me \
  -H "Authorization: Bearer YOUR_JWT_TOKEN"

# Suite de tests complète
cd testapi && bash test-api.sh
```

---

## 🛡️ Sécurité

```bash
# Scan CVE de l'image Docker
cd testapi && bash security-scan.sh

# Détection de secrets dans le code
bash git-security-scan.sh
```

---

## 🔗 Projets Liés

| Composant | Repository |
|-----------|------------|
| 📦 Product Service | [product-service](https://gitlab.com/yara_portfolio/devops/ecommerce/microservice/product-service) |
| 🛒 Order Service | [order-service](https://gitlab.com/yara_portfolio/devops/ecommerce/microservice/order-service) |
| ⭐ Review Service | [review-service](https://gitlab.com/yara_portfolio/devops/ecommerce/microservice/review-service) |
| ⎈ Helm Chart | [k8s-helm-chart](https://gitlab.com/yara_portfolio/devops/ecommerce/devops-tools/k8s-helm-chart) |
| 🐝 Docker Swarm | [docker-swarm](https://gitlab.com/yara_portfolio/devops/ecommerce/devops-tools/docker-swarm) |
| 🗄️ Base de données | [ecommerce-database](https://gitlab.com/yara_portfolio/devops/ecommerce/ecommerce-database) |
| 🤖 Ansible Deployment | [ansible-deployment](https://gitlab.com/yara_portfolio/devops/ecommerce/ansible-deployment) |

---

## 👨‍💻 Auteur

**Yara Mahi Mohamed** — Portfolio DevOps & SRE

*⭐ N'oubliez pas de star ce repo si vous le trouvez utile !*
