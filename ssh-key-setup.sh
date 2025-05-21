#!/bin/sh

KEY_NAME=id_gitea
PUB_KEY_NAME=id_gitea.pub

if [ -f "$KEY_NAME" ] && [ -f "$PUB_KEY_NAME" ]; then
    echo "Key already exists, exiting"
    exit 0
fi

ssh-keygen -C "gitea ssh key" -f $KEY_NAME -N "" -t ed25519

printf "Username: "
read USERNAME
printf "Password: "
stty -echo
read PASSWORD
stty echo
echo

GITEA_URL=git.robaertschi.me

curl -X POST -H "Content-Type: application/json" -d "{ \"key\": \"$(cat $PUB_KEY_NAME)\", \"title\": \"gitea key for minimim from $(date)\", \"read_only\": false }" https://$USERNAME:$PASSWORD@${GITEA_URL}/api/v1/user/keys
