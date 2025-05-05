#!/bin/bash
set -e

IAM_HOSTNAME=${IAM_HOSTNAME:-"https://iam.test.example"}
IAM_DEVICE_CODE_ENDPOINT="${IAM_HOSTNAME}/devicecode"
IAM_TOKEN_ENDPOINT="${IAM_HOSTNAME}/token"

IAM_CLIENT_ID=${IAM_CLIENT_ID:-6a86717b-5153-4592-a636-2bf021694a58}
IAM_CLIENT_SECRET=${IAM_CLIENT_SECRET:-D61143C3cG7KqTIRV9C_2PcUnj1gZa8MMxj50JKVEUbO29n4SeHK89jbWlWPOzmfqLFzwrzrJqzyC9Rhwqu7EA} 
IAM_CLIENT_SCOPES=${IAM_CLIENT_SCOPES:-"wlcg.groups"}
IAM_CLIENT_AUDIENCE=${IAM_CLIENT_AUDIENCE}

exit_msg() {
  echo "Giving up as requested by user..."
  exit 1
}

if [[ -z "${IAM_DEVICE_CODE_ENDPOINT}" ]]; then
  echo "Please set the IAM_DEVICE_CODE_ENDPOINT env variable"
  exit 1
fi

IAM_CLIENT_AUDIENCE=${IAM_CLIENT_AUDIENCE}

response=$(mktemp)

curl -s -f -L \
  -u ${IAM_CLIENT_ID}:${IAM_CLIENT_SECRET} \
  -d client_id=${IAM_CLIENT_ID} \
  -d scope="${IAM_CLIENT_SCOPES}" \
  ${IAM_DEVICE_CODE_ENDPOINT} > ${response}  

if [ $? -ne 0 ]; then
  echo "Error contacting IAM"
  cat ${response}
  exit 1
fi

device_code=$(jq -r .device_code ${response})
user_code=$(jq -r .user_code ${response})
verification_uri=$(jq -r .verification_uri ${response})
expires_in=$(jq -r .expires_in ${response})

trap "exit_msg" INT 

echo "Please open the following URL in the browser:"
echo

echo ${verification_uri}'?user_code='${user_code}
echo

echo "and, after having been authenticated, enter the following code when requested:"
echo

echo ${user_code}

echo
echo "Note that the code above expires in ${expires_in} seconds..."
echo "Once you have correctly authenticated and authorized this device, this script can be restarted to obtain a token. "


while true; do

  while true; do
    echo
    echo "Proceed? [Y/N] (CTRL-c to abort)"
    read a
    [[ $a = "y" || $a = "Y" ]] && break
    [[ $a = "n" || $a = "N" ]] && exit 0
  done 

  if [ -n "${IAM_CLIENT_AUDIENCE}" ]; then
    curl -q -L -s \
      -u ${IAM_CLIENT_ID}:${IAM_CLIENT_SECRET} \
      -d grant_type=urn:ietf:params:oauth:grant-type:device_code \
      -d device_code=${device_code} \
      -d audience="${IAM_CLIENT_AUDIENCE}" \
      ${IAM_TOKEN_ENDPOINT} \
      2>&1 > ${response}
  else
    curl -q -L -s \
      -u ${IAM_CLIENT_ID}:${IAM_CLIENT_SECRET} \
      -d grant_type=urn:ietf:params:oauth:grant-type:device_code \
      -d device_code=${device_code} \
      ${IAM_TOKEN_ENDPOINT} \
      2>&1 > ${response}
  fi

  if [ $? -ne 0 ]; then
    echo "Error contacting IAM"
    cat ${response}
    exit 1
  fi

  error=$(jq -r .error ${response})
  error_description=$(jq -r .error_description ${response})

  if [[ "${error}" != "null" ]]; then
    echo "The IAM returned the following error:"
    echo
    echo ${error} " " ${error_description}
    echo
    continue;
  fi

  access_token=$(jq -r .access_token ${response})
  refresh_token=$(jq -r .refresh_token ${response})
  scope=$(jq -r .scope ${response})
  expires_in=$(jq -r .expires_in ${response})
  


  echo
  echo "An access token was issued, with the following scopes:"
  echo
  echo ${scope}
  echo
  echo "which expires in ${expires_in} seconds:"
  echo 
  echo ${access_token}
  echo

  if [[ "${refresh_token}" != "null" ]]; then
    echo "A refresh token was issued:"
    echo
    echo ${refresh_token}
    echo
  fi

  exit 0

done