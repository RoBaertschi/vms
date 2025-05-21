#!/bin/sh

scp -P 22220 ./id_gitea robin@localhost:/home/robin/.ssh/id_ed25519
scp -P 22220 ./id_gitea.pub robin@localhost:/home/robin/.ssh/id_ed25519.pub
