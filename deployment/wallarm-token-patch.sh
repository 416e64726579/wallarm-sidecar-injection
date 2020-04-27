#!/bin/bash

export WALLARM_TOKEN=$(echo "$1" | base64)

sed -e "s|\${WALLARM_TOKEN}|${WALLARM_TOKEN}|g" ./deployment/wallarm-secret.yaml > ./deployment/wallarm-secret-patched.yaml
