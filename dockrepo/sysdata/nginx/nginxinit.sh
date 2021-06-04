#!/bin/bash
#
#  script "non faccio niente"
#
##########################################################################
avanti(){
# Domanda di continuazione personalizzabile
# call:    avanti $1
#   $1:    "<stringa di domanda>"
  echo "----------------------------------------------------------------"
  read -rsp "$1" -n 1 key
  echo
}
#
echo "Script": $0"
echo "This is a placeholder for a script that will probably be written in the future"
echo "It may be useful during development only"
avanti 'Press any key to continue ...'
echo 