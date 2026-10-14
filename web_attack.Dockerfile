FROM alpine:latest

# Installation des outils nécessaires (bash et curl)
RUN apk add --no-cache bash curl

# Copie du script d'attaque dans le conteneur
COPY web_attack/attack_simulation.sh /attack_simulation.sh

# Attribution des droits d'exécution
RUN chmod +x /attack_simulation.sh

# Commande par défaut pour garder le conteneur actif
CMD ["tail", "-f", "/dev/null"]

# Utilisé pour importer un script de débogage si nécessaire
#COPY web_attack/debug.sh /debug.sh
#RUN chmod +x /debug.sh