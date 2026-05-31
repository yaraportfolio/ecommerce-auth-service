#!/bin/sh
set -e

# --- CONFIGURATION ---
LOG_FILE="test-results.log"
HTML_FILE="test-api-report.html"

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

# Initialisation du Log Console (Inchangé comme tu l'as demandé)
echo "Auth Service API Full Suite - $(date)" > "$LOG_FILE"
echo "----------------------------------------------------------------------" >> "$LOG_FILE"
printf "%-10s | %-40s | %s\n" "STATUS" "TEST DESCRIPTION" "RESULT" | tee -a "$LOG_FILE"
echo "----------------------------------------------------------------------" >> "$LOG_FILE"

# Initialisation du Dashboard HTML (Largeur réduite et nouvelle couleur)
cat <<EOF > "$HTML_FILE"
<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="UTF-8">
    <style>
        body { font-family: 'Segoe UI', sans-serif; background: #f4f7f9; padding: 20px; }
        .container { max-width: 850px; margin: auto; } /* Largeur légèrement diminuée */
        .header { 
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); /* Nouveau dégradé Indigo/Violet */
            color: white; padding: 20px; border-radius: 12px; text-align: center; 
            box-shadow: 0 4px 15px rgba(0,0,0,0.1); margin-bottom: 25px;
            width: 90%; margin-left: auto; margin-right: auto; /* Cadre légèrement plus étroit */
        }
        .test-card { background: white; border-radius: 8px; margin-bottom: 10px; display: flex; justify-content: space-between; align-items: center; padding: 15px 25px; box-shadow: 0 2px 4px rgba(0,0,0,0.05); border-left: 6px solid #ccc; }
        .PASS { border-left-color: #4caf50; }
        .FAIL { border-left-color: #f44336; }
        .badge { padding: 6px 12px; margin-left: 10px; border-radius: 4px; font-weight: bold; font-size: 0.8em; color: white; }
        .bg-PASS { background: #4caf50; }
        .bg-FAIL { background: #f44336; }
        .tech-info { font-size: 0.8em; color: #7f8c8d; font-family: monospace; margin-top: 5px; word-break: break-all; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🧪 API TEST DASHBOARD</h1>
            <p>Auth-Service | Port: $SERVICE_PORT</p>
        </div>
EOF

run_test() {
  DESC="$1"
  CMD="$2"
  DISPLAY_CMD="$3" # Nouvelle variable pour l'affichage propre
  
  # Si DISPLAY_CMD est vide, on utilise CMD par défaut
  [ -z "$DISPLAY_CMD" ] && DISPLAY_CMD="$CMD"

  if eval "$CMD" > /dev/null 2>&1; then
    printf "${GREEN}%-10s${NC} | %-40s | Success\n" "PASS ✅" "$DESC" | tee -a "$LOG_FILE"
    echo "<div class='test-card PASS'><div><strong>$DESC</strong><div class='tech-info'>$DISPLAY_CMD</div></div><span class='badge bg-PASS'>PASS</span></div>" >> "$HTML_FILE"
  else
    printf "${RED}%-10s${NC} | %-40s | Error\n" "FAIL ❌" "$DESC" | tee -a "$LOG_FILE"
    echo "<div class='test-card FAIL'><div><strong>$DESC</strong><div class='tech-info'>$DISPLAY_CMD</div></div><span class='badge bg-FAIL'>FAIL</span></div>" >> "$HTML_FILE"
    echo "</div></body></html>" >> "$HTML_FILE"
    kill $SERVICE_PID 2>/dev/null || true
    exit 1
  fi
}

# --- DÉMARRAGE ---
echo "Starting service on port ${SERVICE_PORT}..."
echo "Database: ${DB_HOST}:${DB_PORT}/${DB_NAME}"
node src/server.js > service-output.log 2>&1 &
SERVICE_PID=$!
sleep 2
echo "Service PID: $SERVICE_PID"
cat service-output.log
echo "---"
timeout 60 sh -c "until curl -s http://localhost:${SERVICE_PORT}/api/auth/health > /dev/null; do sleep 1; done" || {
  echo "❌ Health check timeout. Service logs:"
  cat service-output.log
  kill $SERVICE_PID 2>/dev/null || true
  exit 124
}

# --- TESTS ---
run_test "1. Health Check (Liveness)" "curl -s http://localhost:${SERVICE_PORT}/api/auth/health | jq -e '.status == \"ok\"'"
run_test "2. Ready Check (Readiness)" "curl -f http://localhost:${SERVICE_PORT}/api/auth/ready | jq -e '.status == \"ready\"'"
run_test "3. Metrics (Prometheus)" "curl -s http://localhost:${SERVICE_PORT}/api/auth/metrics | grep -q 'http_requests_total'"
run_test "4. Service Info (Metadata)" "curl -s http://localhost:${SERVICE_PORT}/api/auth/info | jq -e '.service == \"auth-service\"'"
run_test "5. Register User (Valid)" "curl -s -X POST http://localhost:${SERVICE_PORT}/api/auth/register -H 'Content-Type: application/json' -d '{\"name\":\"Test User\",\"email\":\"test@example.com\",\"password\":\"password123\"}' | jq -e '.message'"
run_test "6. Register (Duplicate Email)" "[ \$(curl -s -o /dev/null -w '%{http_code}' -X POST http://localhost:${SERVICE_PORT}/api/auth/register -H 'Content-Type: application/json' -d '{\"name\":\"Test\",\"email\":\"test@example.com\",\"password\":\"password123\"}') = 400 ]"
run_test "7. Register (Invalid Email Format)" "[ \$(curl -s -o /dev/null -w '%{http_code}' -X POST http://localhost:${SERVICE_PORT}/api/auth/register -H 'Content-Type: application/json' -d '{\"name\":\"Test\",\"email\":\"not-an-email\",\"password\":\"123\"}') = 400 ]"

# --- GESTION DU TOKEN ---
LOGIN_DATA='{"email":"test@example.com","password":"password123"}'
TOKEN=$(curl -s -X POST http://localhost:${SERVICE_PORT}/api/auth/login -H 'Content-Type: application/json' -d "$LOGIN_DATA" | jq -r '.token // empty')

# Utilisation de la variable $TOKEN pour l'affichage (évite le gros bloc de texte)
run_test "8. Login (Valid Credentials)" "[ -n \"$TOKEN\" ] && [ \"$TOKEN\" != \"null\" ]" "curl -s -X POST .../login | jq -r '.token' # Recu: \$TOKEN"
run_test "9. Login (Wrong Password)" "[ \$(curl -s -o /dev/null -w '%{http_code}' -X POST http://localhost:${SERVICE_PORT}/api/auth/login -H 'Content-Type: application/json' -d '{\"email\":\"test@example.com\",\"password\":\"wrong\"}') = 401 ]"
run_test "10. Login (Non-existent User)" "[ \$(curl -s -o /dev/null -w '%{http_code}' -X POST http://localhost:${SERVICE_PORT}/api/auth/login -H 'Content-Type: application/json' -d '{\"email\":\"ghost@example.com\",\"password\":\"password123\"}') = 401 ]"

# Ici on cache le token dans l'affichage HTML en utilisant le texte "$TOKEN"
run_test "11. Profile (Authorized Access)" "curl -s -H \"Authorization: Bearer $TOKEN\" http://localhost:${SERVICE_PORT}/api/auth/me | jq -e '.user.email == \"test@example.com\"'" "curl -H 'Authorization: Bearer \$TOKEN' .../api/auth/me"

run_test "12. Profile (No Token Provided)" "[ \$(curl -s -o /dev/null -w '%{http_code}' http://localhost:${SERVICE_PORT}/api/auth/me) = 401 ]"
run_test "13. Profile (Invalid/Bad Token)" "[ \$(curl -s -o /dev/null -w '%{http_code}' -H 'Authorization: Bearer invalid_token' http://localhost:${SERVICE_PORT}/api/auth/me) = 401 ]"

# --- FINALISATION ---
echo "</div></body></html>" >> "$HTML_FILE"
kill $SERVICE_PID 2>/dev/null || true
echo "✅ Dashboard généré dans $HTML_FILE"