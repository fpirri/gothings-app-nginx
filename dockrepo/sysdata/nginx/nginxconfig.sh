#!/bin/bash
# ref.: https://pentacent.medium.com/nginx-and-lets-encrypt-with-docker-in-less-than-5-minutes-b4b8a60d3a71
#
# costanti di personalizzazione
###############################################################################
###  da mettere in un file di configurazione                                    DA FARE IN PRODUZIONE
domains=(pirri.me test.pirri.me)
ConfigWorkDir="/home/yesfi/dockrepo/sysdata/nginx/"
# Adding a valid address is strongly recommended
email="vmaticfp@gothings.org"
#
rsa_key_size=4096
data_path="${ConfigWorkDir}data/certbot"
staging=0 # Set to 1 if you are testing your setup to avoid hitting request limits
#
#  Funzioni utili
###############################################################################
avanti(){
# Domanda di continuazione personalizzabile
# call:    avanti \$1
#   \$1:   <stringa di domanda>
  echo "----------------------------------------------------------------"
  read -rsp "$1" -n 1 key
  echo
}
#
pause() {
#  Domanda 'continue or exit'
  avanti 'Press any key to continue or ^C to EXIT ...'
}
#
##########################################################################
#
echo "--------------------------------------------------------------"
echo "SCRIPT: $0"
echo
if ! cd "${ConfigWorkDir}" ; then
    echo "Failed to enter folder ${ConfigWorkDir}"
    echo "Aborting ..."
    return 66
fi

#  ci serve docker-compose:
if ! [ -x "$(command -v docker-compose)" ]; then
  echo "Error: docker-compose is not installed." >&2
  exit 1
fi
#
echo
echo "Sono in sviluppo, le mie azioni vanno VERIFICATE"
echo
echo -n "You are:  "
whoami
echo "You work in the directory:"
pwd
echo "Working directory content:"
ls -la
echo
pause

if [ -d "$data_path" ]; then
  read -p "Existing data found for $domains. Continue and replace existing certificate? (y/N) " decision
  if [ "$decision" != "Y" ] && [ "$decision" != "y" ]; then
    exit
  fi
fi

#
# lettura dei file di configurazione certbot
#  in produzione:  memorizzare i dati nel posto previsto?                       DA RIVEDERE
#
if [ ! -e "$data_path/conf/options-ssl-nginx.conf" ] || [ ! -e "$data_path/conf/ssl-dhparams.pem" ]; then
  echo "... Downloading recommended TLS parameters ..."
  mkdir -p "$data_path/conf"
  curl -s https://raw.githubusercontent.com/certbot/certbot/master/certbot-nginx/certbot_nginx/_internal/tls_configs/options-ssl-nginx.conf > "$data_path/conf/options-ssl-nginx.conf"
  curl -s https://raw.githubusercontent.com/certbot/certbot/master/certbot/certbot/ssl-dhparams.pem > "$data_path/conf/ssl-dhparams.pem"
  echo
fi

echo "### Creating dummy certificate for $domains ..."
path="/etc/letsencrypt/live/$domains"
mkdir -p "$data_path/conf/live/$domains"
docker-compose -f nginx.yml run --rm --entrypoint "\
  openssl req -x509 -nodes -newkey rsa:$rsa_key_size -days 1\
    -keyout '$path/privkey.pem' \
    -out '$path/fullchain.pem' \
    -subj '/CN=localhost'" certbot

echo
echo "### Starting nginx ..."
docker-compose -f nginx.yml up --force-recreate -d nginx
echo

echo "### Deleting dummy certificate for $domains ..."
docker-compose -f nginx.yml run --rm --entrypoint "\
  rm -Rf /etc/letsencrypt/live/$domains && \
  rm -Rf /etc/letsencrypt/archive/$domains && \
  rm -Rf /etc/letsencrypt/renewal/$domains.conf" certbot
echo

echo "### Requesting certificate for $domains ..."
#Join $domains to -d args
domain_args=""
for domain in "${domains[@]}"; do
  domain_args="$domain_args -d $domain"
done

# Select appropriate email arg
case "$email" in
  "") email_arg="--register-unsafely-without-email" ;;
  *) email_arg="--email $email" ;;
esac

# Enable staging mode if needed
if [ $staging != "0" ]; then staging_arg="--staging"; fi

docker-compose -f nginx.yml run --rm --entrypoint "\
  certbot certonly --webroot -w /var/www/certbot \
    $staging_arg \
    $email_arg \
    $domain_args \
    --rsa-key-size $rsa_key_size \
    --agree-tos \
    --force-renewal" certbot
echo

echo "... Reloading nginx ..."
docker-compose -f nginx.yml exec nginx nginx -s reload
echo
echo "================================================================"
echo "NGINX proxy is started!"
echo
echo "Please verify nginx is OK"
echo
pause
return 0
