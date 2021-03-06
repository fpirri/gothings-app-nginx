#!/bin/bash
# Richiesta certificati tramite certbot
#
# ref.: https://pentacent.medium.com/nginx-and-lets-encrypt-with-docker-in-less-than-5-minutes-b4b8a60d3a71
#
# costanti di personalizzazione
###############################################################################
###  da mettere in un file di configurazione                                    DA FARE IN PRODUZIONE
##############
# ----------------------------------
# Define app
AppName="nginx"
AppDisplayName="Nginx Proxy"
#
# ----------------------------------
# variabili globali interne
UserName=yesfi
AppDir="/home/${UserName}/sysdata/${AppName}/"
#
#-------------------------------------
# costanti X certbot
domains=(pirri.me test.pirri.me)
email="vmaticfp@gothings.org"
ConfigWorkDir="/home/yesfi/dockrepo/sysdata/${AppName}/"
#
rsa_key_size=4096
data_path="${ConfigWorkDir}data/certbot"
staging=0 # Set to 1 if you are testing your setup to avoid hitting request limits
#
DebugMode=1
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
    return 41 #                                           certbot -->  ERRORE 41
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

echo
echo "### Dovremmo verificare che nginx sta funzionando ..."
#docker-compose -f nginx-certbot.yml up --force-recreate -d nginx
#RetValue=$?
echo "...  lo faremo poi."
RetValue=0
if [ ${RetValue} -gt 0 ]; then
  bugmessage ERROR "${RetValue}" "    config.sh: get ssl params"
  exit 42 #                                               certbot -->  ERRORE 42
fi
echo
echo "### Requesting certificate for $domains ..."
#Join $domains to -d args
domain_args=""
for domain in "${domains[@]}"; do
  domain_args="$domain_args -d $domain"
done

# Select appropriate email arg
email_arg="--email $email"

# Enable staging mode if needed
#if [ $staging != "0" ]; then staging_arg="--staging"; fi

echo
echo "... Run certbot"
docker-compose -f certbot.yml up -d
RetValue=$?
if [ ${RetValue} -gt 0 ]; then
  bugmessage ERROR "${RetValue}" "     certbot ERROR"
  exit 45 #                                               certbot -->  ERRORE 45
fi
echo "certbot now DOWN"

echo
echo "================================================================"
echo "Renew certificates OK"
echo
pause
exit 0