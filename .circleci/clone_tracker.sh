#!/bin/bash

# ping chuck's clone tracking endpoint
wget -S --header="Accept: application/json" \
  --header="Content-Type: application/json" \
  --post-data="{\"date\":\"$(date)\",\"source\":\"circle-ci\",\"count\":1}" \
  -O - https://hooks.zapier.com/hooks/catch/175929/f4hnh4/
