#!/bin/sh
set -e

OIDC_AGENT_ALIAS=${OIDC_AGENT_ALIAS:-dev-wlcg}

eval $(oidc-agent-service use)
oidc-add --pw-env=OIDC_AGENT_SECRET ${OIDC_AGENT_ALIAS}
IAM_ACCESS_TOKEN=$(oidc-token -s openid ${OIDC_AGENT_ALIAS})

echo -e "\nEncoded access token:\n"
echo $IAM_ACCESS_TOKEN

echo -e "\nDecoded access token:"

echo $IAM_ACCESS_TOKEN | jwt
