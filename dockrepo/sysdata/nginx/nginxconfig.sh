#!/bin/bash
# ref.: https://pentacent.medium.com/nginx-and-lets-encrypt-with-docker-in-less-than-5-minutes-b4b8a60d3a71
#
#  Funzioni utili
##########################################################################
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
  avanti 'Press any key to continue or ^C to exit ...'
}
#
##########################################################################
#
echo "Non faccio niente!"
avanti "any key to exit ..."
exit

echo "you have to become root to exec this operation"
echo
[ "$UID" -eq 0 ] || exec sudo "$0" "$@"
echo
echo "now you are:"
whoami

if [ "$(whoami)" != "root" ]; then
        echo "Script must be run as user: root"
        exit 255
fi

if ! [ -x "$(command -v docker-compose)" ]; then
  echo 'Error: docker-compose is not installed.' >&2
  exit 1
fi

domains=(pirri.me test.pirri.me)
rsa_key_size=4096
data_path="./data/certbot"
email="vmaticfp@gothings.org" # Adding a valid address is strongly recommended
staging=0 # Set to 1 if you're testing your setup to avoid hitting request limits

if [ -d "$data_path" ]; then
  read -p "Existing data found for $domains. Continue and replace existing certificate? (y/N) " decision
  if [ "$decision" != "Y" ] && [ "$decision" != "y" ]; then
    exit
  fi
fi

#
# ZONA da modificare ...................
#
#  dati gia' memorizzati al posto previsto
#
  if [ ! -e "$data_path/conf/options-ssl-nginx.conf" ] || [ ! -e "$data_path/conf/ssl-dhparams.pem" ]; then
    echo "### Downloading recommended TLS parameters ..."
    mkdir -p "$data_path/conf"
    #  source file:    https://github.com/certbot/certbot/raw/master/certbot-nginx/certbot_nginx/_internal/tls_configs/options-ssl-nginx.conf
    curl -s https://raw.githubusercontent.com/certbot/certbot/master/certbot-nginx/certbot_nginx/_internal/tls_configs/options-ssl-nginx.conf > "$data_path/conf/options-ssl-nginx.conf"
    # source file:     https://github.com/certbot/certbot/raw/master/certbot/certbot/ssl-dhparams.pem
    curl -s https://raw.githubusercontent.com/certbot/certbot/master/certbot/certbot/ssl-dhparams.pem > "$data_path/conf/ssl-dhparams.pem"
    echo
  fi
# echo "certbot/conf data already downloaded"
# echo "--- modified by vmaticfp"
# .... fin qui!

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

echo "### Requesting Let's Encrypt certificate for $domains ..."
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

echo "### Reloading nginx ..."
docker-compose -f nginx.yml exec nginx nginx -s reload
