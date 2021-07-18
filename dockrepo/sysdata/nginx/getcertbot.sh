#!/bin/bash
# ref.: https://pentacent.medium.com/nginx-and-lets-encrypt-with-docker-in-less-than-5-minutes-b4b8a60d3a71
#
# costanti di personalizzazione
###############################################################################
###  da mettere in un file di configurazione                                    DA FARE IN PRODUZIONE
domains=(servicewp.pirri.me)
ConfigWorkDir="/home/yesfi/dockrepo/sysdata/nginx/"
# Adding a valid address is strongly recommended
email="vmaticfp@gothings.org"
#
rsa_key_size=4096
data_path="${ConfigWorkDir}data/certbot"
LivePath="$data_path/conf/live/"
AppLivePath="$LivePath$domains"
staging=0 # Set to 1 if you are testing your setup to avoid hitting request limits
#
DebugMode=1
#
# ----------------------------------
# costanti varie
Red='\033[0;41;30m'
Std='\033[0;0;39m'
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
bugmessage(){
# stampa di un avviso di errore, se DebugMode -gt 0
#
#  $1 :  ERROR oppure WARNING oppure NOTE
#  $2 :  codice di errore
#  stampa piccola storia  <-- vecchio debuglog !!!                              DA RIVEDERE
#  $3 :  avviso all'utente, come '... il file xxx e' essenziale ...'
#
  if [ ${DebugMode} -gt 0 ]; then
    echo 
    echo "------------------------------------------------------"
    echo -e "${Red} $1 $2 - debug message: ${Std}"
    echo -e "$3"
    echo "------------------------------------------------------"
    echo 
  fi
}
#
##########################################################################
bugprint(){
# stampa di un avviso, ma solo se DebugMode -gt 0
#
#  $1 :  avviso all'utente, come: 'ho fatto questo o quello'
#
  if [ ${DebugMode} -gt 0 ]; then
    echo $1
  fi
}
#
##########################################################################
#                                                                     MAIN
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
echo "Live domains in this droplet:"
ls -la $LivePath
echo
echo "Data path for this app:"
echo "  $AppLivePath"
echo "dovrebbe essere:"
echo "  /home/yesfi/dockrepo/sysdata/nginx/data/certbot/conf/live/$domains"

echo
echo "Ci serve che nginx stia girando in questa droplet"
echo -e "${Red} Verificalo prima di proseguire !!! ${Std}"
pause

echo
echo "Ci serve che certbot NON stia girando in questa droplet"
echo -e "${Red} Verificalo prima di proseguire !!! ${Std}"
pause




if [ -d "$AppLivePath" ]; then
  echo -e "${Red} ATTENTION ! ${Std}"
  echo "Existing data found for $domains. "
  echo "If you continue existing certificates will be replaced."
  echo "STOP this script if you like to preserve existing certificates."
  read -p "Do you like to stop this script ? (y/N) " decision
  if [[ "$decision" == "Y" || "$decision" == "y" ]]; then
    exit 0
  fi
fi

if [ -d "$AppLivePath" ]; then
  echo "### Deleting dummy certificate for $domains ..."
  docker-compose -f certbot.yml run --rm --entrypoint "\
    rm -Rf /etc/letsencrypt/live/$domains && \
    rm -Rf /etc/letsencrypt/archive/$domains && \
    rm -Rf /etc/letsencrypt/renewal/$domains.conf" certbot
  RetValue=$?
  if [ ${RetValue} -gt 0 ]; then
    bugmessage ERROR "${RetValue}" "    config.sh: delete certificates"
    exit 35 #                                                   Starting nginx -->  ERRORE 35
  fi
  echo
fi



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

docker-compose -f certbot.yml run --rm --entrypoint "\
  certbot certonly --webroot -w /var/www/certbot \
    $staging_arg \
    $email_arg \
    $domain_args \
    --rsa-key-size $rsa_key_size \
    --agree-tos \
    --force-renewal" certbot
RetValue=$?
if [ ${RetValue} -gt 0 ]; then
  bugmessage ERROR "${RetValue}" "    config.sh: run nginx & certbot"
  exit 36 #                                              run nginx & certbot -->  ERRORE 36
fi
echo
echo
echo "================================================================"
echo "Config script OK"
echo
exit 0






################################################
echo "Fine esperimento ..."
exit

#
# lettura dei file di configurazione certbot
#  in produzione:  memorizzare i dati nel posto previsto?                       DA RIVEDERE
#
if [ ! -e "$data_path/conf/options-ssl-nginx.conf" ] || [ ! -e "$data_path/conf/ssl-dhparams.pem" ]; then
  echo "... Downloading recommended TLS parameters ..."
  mkdir -p "$data_path/conf"
  curl -s https://raw.githubusercontent.com/certbot/certbot/master/certbot-nginx/certbot_nginx/_internal/tls_configs/options-ssl-nginx.conf > "$data_path/conf/options-ssl-nginx.conf"
  RetValue=$?
  if [ ${RetValue} -gt 0 ]; then
    bugmessage ERROR "${RetValue}" "    config.sh: get ssl params"
    exit 31 #                                              ssl config error  -->  ERRORE 31
  fi
  curl -s https://raw.githubusercontent.com/certbot/certbot/master/certbot/certbot/ssl-dhparams.pem > "$data_path/conf/ssl-dhparams.pem"
  RetValue=$?
  if [ ${RetValue} -gt 0 ]; then
    bugmessage ERROR "${RetValue}" "    config.sh: get ssl params"
    exit 32 #                                              ssl config error  -->  ERRORE 32
  fi
  echo
fi

echo "### Creating dummy certificate for $domains ..."
path="/etc/letsencrypt/live/$domains"
mkdir -p "$data_path/conf/live/$domains"
docker-compose -f nginx-certbot.yml run --rm --entrypoint "\
  openssl req -x509 -nodes -newkey rsa:$rsa_key_size -days 1\
    -keyout '$path/privkey.pem' \
    -out '$path/fullchain.pem' \
    -subj '/CN=localhost'" certbot
RetValue=$?
if [ ${RetValue} -gt 0 ]; then
  bugmessage ERROR "${RetValue}" "    config.sh: get ssl params"
  exit 33 #                                                ssl get RSA keys  -->  ERRORE 33
fi

echo
echo "### Starting nginx ..."
docker-compose -f nginx-certbot.yml up --force-recreate -d nginx
RetValue=$?
if [ ${RetValue} -gt 0 ]; then
  bugmessage ERROR "${RetValue}" "    config.sh: get ssl params"
  exit 34 #                                                   Starting nginx -->  ERRORE 34
fi
echo

echo "### Deleting dummy certificate for $domains ..."
docker-compose -f nginx-certbot.yml run --rm --entrypoint "\
  rm -Rf /etc/letsencrypt/live/$domains && \
  rm -Rf /etc/letsencrypt/archive/$domains && \
  rm -Rf /etc/letsencrypt/renewal/$domains.conf" certbot
RetValue=$?
if [ ${RetValue} -gt 0 ]; then
  bugmessage ERROR "${RetValue}" "    config.sh: delete certificates"
  exit 35 #                                                   Starting nginx -->  ERRORE 35
fi
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

docker-compose -f nginx-certbot.yml run --rm --entrypoint "\
  certbot certonly --webroot -w /var/www/certbot \
    $staging_arg \
    $email_arg \
    $domain_args \
    --rsa-key-size $rsa_key_size \
    --agree-tos \
    --force-renewal" certbot
RetValue=$?
if [ ${RetValue} -gt 0 ]; then
  bugmessage ERROR "${RetValue}" "    config.sh: run nginx & certbot"
  exit 35 #                                              run nginx & certbot -->  ERRORE 35
fi
echo

echo "... Reloading nginx ..."
docker-compose -f nginx-certbot.yml exec nginx nginx -s reload
RetValue=$?
if [ ${RetValue} -gt 0 ]; then
  bugmessage ERROR "${RetValue}" "    config.sh: reload nginx"
  exit 36 #                                              run nginx & certbot -->  ERRORE 36
fi
echo "NGINX proxy is started!"

echo "... Reset nginx & certbot"
docker-compose -f nginx-certbot.yml down
RetValue=$?
if [ ${RetValue} -gt 0 ]; then
  bugmessage ERROR "${RetValue}" "    nginx & certbot down"
  exit 37 #                                             nginx & certbot down -->  ERRORE 37
fi
echo "NGINX proxy and certbot now DOWN"

echo
echo "================================================================"
echo "Config script OK"
echo
pause
exit 0



################################################
echo "PAUSA di sviluppo. Exiting ..."
exit 166
