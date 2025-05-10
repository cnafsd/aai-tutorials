# Docker compose for VOMS AA and StoRM WevDAV

This folder allows you to ask for a VOMS proxy with different attributes. Also, you can play with group membership (i.e. add/remove the _test_ user to some group) and check that the change is propagated in the VOMS proxy.

## Run the compose

Build the trustanchor

```bash
docker compose build --no-cache trust
```

Run the services with

```bash
docker compose up -d
```

The docker-compose contains several services:

* `trust`: docker image for the _igi-test-ca_ CA certificates issuing server/user certificates, usually mounted in the `/etc/grid-security/certificates` path of the other services. The container populates a `/certs` volume containing server/user X.509 certificates
* `iam`: is an `nginx` image used for TLS termination and reverse proxy
* `iam-be`: is the main service, also known as `iam-login-service`. The INDIGO IAM base URL is https://iam.test.example
* `nginx-voms`: is the NGINX reverse proxy which forwards requests to the VOMS-AA microservice. URL of this service is https://voms.test.example:8443
* `vomsaa`: is the VOMS-AA microservice which acts as VOMS Admin. It serves the `indigo-dc` VO
* `db`: is a mysql database used by INDIGO IAM and VOMS-AA. A dump of the database with test users plus a _test0_ certificate linked to an account may be enabled. The test user also belong to the `indigo-dc` VO/IAM group, such that it can request for VOMS proxies
* `clients`: is an image containing GRID clients (e.g. `voms-proxy-init`, `oidc-agent`, etc.) used to query the VOMS AA service to obtain VOMS proxies and IAM for getting tokens.
  
To resolve the hostname of the services, add a line in your `/etc/hosts` file with

```
127.0.0.1	voms.test.example   iam.test.example
```

## iam-login-service

Available at https://iam.test.example/.

The IAM database is populated with an Admin and test users with the following credentials

* admin user: login with admin/password
* test user: login with test/password (the test0 certificate is linked to this account).

To have a full production instance (with only the Admin user in the db) remove the injection of the db dump in the db service container. The Admin user will be the only one available during the first login phase.

## VOMS AA

This voms-aa is connected to an IAM db where a test0 certificate is linked to the test user.
The user is also member of the `indigo-dc/xfers` default group and `/indigo-dc/webdav` _optional group_.

Thus, the `clients` container allows you to directly ask voms-aa for AC extensions (i.e. VOMS proxies).
Enter in the container with

```bash
docker compose exec clients bash
```

Set the user certificates with (file permissions have been already properly set by (setup-trust.sh)[../trust/c509/setup-trust.sh])

```bash
cp /certs/test0.cert.pem ~/.globus/usercert.pem
cp /certs/test0.key.pem ~/.globus/userkey.pem
```

Ask for a VOMS proxy with

```bash
$ echo pass | voms-proxy-init -voms indigo-dc -pwstdin
Contacting voms.test.example:8443 [/C=IT/O=IGI/CN=voms.test.example] "indigo-dc"...
Remote VOMS server contacted succesfully.


Created proxy in /tmp/x509up_u1000.

Your proxy is valid until Sat May 03 17:06:56 CEST 2025
$ voms-proxy-info -all
subject   : /C=IT/O=IGI/CN=test0/CN=765564377
issuer    : /C=IT/O=IGI/CN=test0
identity  : /C=IT/O=IGI/CN=test0
type      : RFC3820 compliant impersonation proxy
strength  : 2048
path      : /tmp/x509up_u1000
timeleft  : 11:59:43
key usage : Digital Signature, Non Repudiation, Key Encipherment
=== VO indigo-dc extension information ===
VO        : indigo-dc
subject   : /C=IT/O=IGI/CN=test0
issuer    : /C=IT/O=IGI/CN=voms.test.example
attribute : /indigo-dc/Role=NULL/Capability=NULL
attribute : /indigo-dc/xfers/Role=NULL/Capability=NULL
timeleft  : 11:59:43
uri       : voms.test.example:8080
```

## Tokens

An `oidc-agent` client configuration (registered within the local `iam` service) mounted in the `clients` container is provided. This allows to request for tokens from IAM either with `curl` or `oidc-agent`.
The Client Id and secret are saved in the db dump used in this compose.

Enter in the container with

```bash
docker compose exec clients bash
```

Start the `oidc-agent` service and add the client configuration with

```bash
eval $(oidc-agent-service use)
oidc-add --pw-env=OIDC_AGENT_SECRET ${OIDC_AGENT_ALIAS}
```

the `OIDC_AGENT_ALIAS` and `OIDC_AGENT_SECRET` variables are already defined in the container environment.

Create an access token issued by `iam`, with the default WLCG groups

```bash
AT=$(oidc-token -s wlcg.groups ${OIDC_AGENT_ALIAS})
```

and cross check that the `/indigo-dc/xfers` is listed among the groups within the _wlcg.group_ claim.

```bash
$ echo $AT | cut -d. -f2 | base64 -d 2>/dev/null | jq .
{
  "wlcg.ver": "1.0",
  "sub": "80e5fb8d-b7c8-451a-89ba-346ae278a66f",
  "aud": "https://wlcg.cern.ch/jwt/v1/any",
  "nbf": 1746377814,
  "scope": "wlcg.groups",
  "iss": "https://iam.test.example/",
  "exp": 1746381414,
  "iat": 1746377814,
  "jti": "7cfba15a-c3d1-4356-887d-6e33f13af3c1",
  "client_id": "6a86717b-5153-4592-a636-2bf021694a58",
  "wlcg.groups": [
    "/Analysis",
    "/Production",
    "/indigo-dc",
    "/indigo-dc/xfers"
  ]
}
```

Now ask for the `/indigo-dc/xfers` group to be the **primary** with

```bash
$ AT=$(oidc-token -s wlcg.groups:/indigo-dc/xfers ${OIDC_AGENT_ALIAS})
$ echo $AT | cut -d. -f2 | base64 -d 2>/dev/null | jq .
{
  "wlcg.ver": "1.0",
  "sub": "80e5fb8d-b7c8-451a-89ba-346ae278a66f",
  "aud": "https://wlcg.cern.ch/jwt/v1/any",
  "nbf": 1746377883,
  "scope": "wlcg.groups:/indigo-dc/xfers",
  "iss": "https://iam.test.example/",
  "exp": 1746381483,
  "iat": 1746377883,
  "jti": "ffc95ac6-114b-44fc-bbc6-5bc78382b63e",
  "client_id": "6a86717b-5153-4592-a636-2bf021694a58",
  "wlcg.groups": [
    "/indigo-dc/xfers",
    "/Analysis",
    "/Production",
    "/indigo-dc"
  ]
}
```

Create an access token from `iam`, with the WLCG optional group `/indigo-dc/webdav`

```bash
AT=$(oidc-token -s wlcg.groups:/indigo-dc/webdav ${OIDC_AGENT_ALIAS})
```

and cross-check that it is listed among the groups within the _wlcg.group_ claim (note that it was not appearing when not explicitely requested)

```bash
$ echo $AT | cut -d. -f2 | base64 -d 2>/dev/null | jq .
{
  "wlcg.ver": "1.0",
  "sub": "80e5fb8d-b7c8-451a-89ba-346ae278a66f",
  "aud": "https://wlcg.cern.ch/jwt/v1/any",
  "nbf": 1746384391,
  "scope": "wlcg.groups:/indigo-dc/webdav wlcg.groups",
  "iss": "https://iam.test.example/",
  "exp": 1746387991,
  "iat": 1746384391,
  "jti": "e4234ed7-deb8-48c9-bd39-2d0f59c9f575",
  "client_id": "6a86717b-5153-4592-a636-2bf021694a58",
  "wlcg.groups": [
    "/indigo-dc/webdav",
    "/Analysis",
    "/Production",
    "/indigo-dc",
    "/indigo-dc/xfers"
  ]
}
```