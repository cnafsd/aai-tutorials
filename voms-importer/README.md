# VOMS importer

This folder allows to import VOMS users from https://meteora.cloud.cnaf.infn.it:8443/ (VOMS server) into https://iam-dev.cloud.cnaf.infn.it (INDIGO IAM).

## Compose

Run the compose and enter in the container with

```bash
docker compose up -d
docker compose exec importer bash
```

Modify the [oidc-agent.env](./oidc-agent.env) file updating the OIDC_AGENT_ALIAS and _SECRET of the oidc-agent Client registered in iam-dev. 

Run the script which initializes your admin credentials

```bash
init-credentials.sh
```

Run the importer

```bash
vomsimporter --vo test.vo --voms-host meteora.cloud.cnaf.infn.it --voms-port 8443 --iam-host iam-dev.cloud.cnaf.infn.it --skip-duplicate-accounts-checks
```

_The `skip-duplicate-accounts-checks` option is required in the importer version `0.1.15` otherwise an error will pop-up_.

## Docker

To run the importer directly from docker

```bash
docker run --rm -it -e X509_USER_PROXY=/tmp/x509up_u501 -e IAM_ENDPOINT=https://iam-dev.cloud.cnaf.infn.it --env-file oidc-agent.env -v ~/.config/oidc-agent:/home/test/.config/oidc-agent -v ~/.globus:/home/test/.globus --entrypoint bash indigoiam/voms-importer:v0.1.15
```

(it requires you have a local GRID certificate/key pair with proper permissions in the `~/.globus`).

Modify the [oidc-agent.env](./oidc-agent.env) file updating the OIDC_AGENT_ALIAS and _SECRET of the oidc-agent Client registered in iam-dev. 

Run the script which initializes your admin credentials

```bash
init-credentials.sh
```

and run the importer with

```bash
vomsimporter --vo test.vo --voms-host meteora.cloud.cnaf.infn.it --voms-port 8443 --iam-host iam-dev.cloud.cnaf.infn.it --skip-duplicate-accounts-checks --debug
```

## More options

More options can be used to run the importer.

### email-mapfile

To override email account for duplicate email in VOMS synchronizing (not existing) IAM users

```bash
vomsimporter --vo test.vo --voms-host meteora.cloud.cnaf.infn.it --voms-port 8443 --iam-host iam-dev.cloud.cnaf.infn.it --skip-duplicate-accounts-checks --email-mapfile /volume/email-mapfile 
```

### id-file

To run the importer for only selected accounts

```bash
vomsimporter --vo test.vo --voms-host meteora.cloud.cnaf.infn.it --voms-port 8443 --iam-host iam-dev.cloud.cnaf.infn.it --skip-duplicate-accounts-checks --id-file /volume/id-file 
```

### username-attr

Create an IAM account with username equal to a VOMS attribute whose key is _nickname_

```bash
vomsimporter --vo test.vo --voms-host meteora.cloud.cnaf.infn.it --voms-port 8443 --iam-host iam-dev.cloud.cnaf.infn.it --skip-duplicate-accounts-checks --username-attr=nickname
```

### synchronize-activation-status

To synchronize the VOMS user's activation status with IAM, including importing the disabled VOMS users

```bash
vomsimporter --vo test.vo --voms-host meteora.cloud.cnaf.infn.it --voms-port 8443 --iam-host iam-dev.cloud.cnaf.infn.it --skip-duplicate-accounts-checks --synchronize-activation-status
```

### skip-users-import

To not import VOMS users into IAM

```bash
vomsimporter --vo test.vo --voms-host meteora.cloud.cnaf.infn.it --voms-port 8443 --iam-host iam-dev.cloud.cnaf.infn.it --skip-duplicate-accounts-checks --skip-users-import
```