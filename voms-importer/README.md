# VOMS importer

This folder allows to import VOMS users from https://meteora.cloud.cnaf.infn.it:8443/ (VOMS server) into https://iam-dev.cloud.cnaf.infn.it (INDIGO IAM).

## Run

In order to perform administrative operations, you need to register an oidc-agent client linked to your IAM Admin account with at least the `openid offline_access iam:admin.read iam:admin.write scim:read scim:write proxy:generate` scopes enabled.

Create an `oidc-agent.env` file in this folder containing the alias and secret for the configuration, e.g.

```bash
OIDC_AGENT_ALIAS=changeme
OIDC_AGENT_SECRET=changeme
```

## Compose

Run the compose and enter in the container with

```bash
docker compose up -d
docker compose exec importer bash
```

(it requires you have a local GRID certificate/key pair with proper permissions in the `~/.globus` folder).

Run the script which initializes your admin credentials

```bash
init-credentials.sh
```

Run the importer

```bash
VOMS_VO=test.vo
VOMS_HOST=meteora.cloud.cnaf.infn.it
VOMS_PORT=8443
IAM_HOST=iam-dev.cloud.cnaf.infn.it
vomsimporter --vo ${VOMS_VO} --voms-host ${VOMS_HOST} --voms-port ${VOMS_PORT} --iam-host ${IAM_HOST} --skip-duplicate-accounts-checks
```

_The `skip-duplicate-accounts-checks` option is required in the importer version `0.1.15` otherwise an error will pop-up_.

## Docker

To run the importer directly from docker

```bash
docker run --rm -it -e X509_USER_PROXY=/tmp/x509up_u501 -e IAM_ENDPOINT=https://iam-dev.cloud.cnaf.infn.it --env-file oidc-agent.env -v ./oidc-agent:/home/test/.config/oidc-agent -v ~/.globus:/home/test/.globus -v ./:/volume --entrypoint bash indigoiam/voms-importer:v0.1.15
```

(it requires you have a local GRID certificate/key pair with proper permissions in the `~/.globus` folder).

Run the script which initializes your admin credentials

```bash
init-credentials.sh
```

and run the importer with

```bash
VOMS_VO=test.vo
VOMS_HOST=meteora.cloud.cnaf.infn.it
VOMS_PORT=8443
IAM_HOST=iam-dev.cloud.cnaf.infn.it
vomsimporter --vo ${VOMS_VO} --voms-host ${VOMS_HOST} --voms-port ${VOMS_PORT} --iam-host ${IAM_HOST} --skip-duplicate-accounts-checks
```

## More options

More options can be used to run the importer.

### email-mapfile

To overwrite email account for duplicate email in VOMS synchronizing (not existing) IAM users

```bash
vomsimporter --email-mapfile /volume/email-mapfile --vo ${VOMS_VO} --voms-host ${VOMS_HOST} --voms-port ${VOMS_PORT} --iam-host ${IAM_HOST} --skip-duplicate-accounts-checks
```

### id-file

To run the importer for only selected accounts

```bash
vomsimporter --id-file /volume/id-file --vo ${VOMS_VO} --voms-host ${VOMS_HOST} --voms-port ${VOMS_PORT} --iam-host ${IAM_HOST} --skip-duplicate-accounts-checks
```

### username-attr

Create an IAM account with username equal to a VOMS attribute whose key is _nickname_

```bash
vomsimporter --username-attr nickname --vo ${VOMS_VO} --voms-host ${VOMS_HOST} --voms-port ${VOMS_PORT} --iam-host ${IAM_HOST} --skip-duplicate-accounts-checks
```

### synchronize-activation-status

To synchronize the VOMS user's activation status with IAM, including importing the disabled VOMS users

```bash
vomsimporter --synchronize-activation-status --vo ${VOMS_VO} --voms-host ${VOMS_HOST} --voms-port ${VOMS_PORT} --iam-host ${IAM_HOST} --skip-duplicate-accounts-checks
```

### skip-users-import

To not import VOMS users into IAM (this way you will import just groups and roles)

```bash
vomsimporter --skip-users-import --vo ${VOMS_VO} --voms-host ${VOMS_HOST} --voms-port ${VOMS_PORT} --iam-host ${IAM_HOST} --skip-duplicate-accounts-checks
```