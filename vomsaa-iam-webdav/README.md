# Docker compose for VOMS AA and StoRM WevDAV

This repo holds self-contained examples on how to get a token (from the local IAM) or a proxy (from the local VOMS AA) and access a StoRM WebDAV resource.

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
* `db`: is a mysql database used by INDIGO IAM and VOMS-AA. A dump of the database with test users plus a _test0_ certificate linked to an account may be enabled. The test user also belong to the `indigo-dc` VO/IAM group, such that it can request for VOMS proxies (from the `vomsaa` service) and JWT tokens (from the `iam` service)
* `storage-setup`: sidecar container, used to allocate proper volumes (i.e. storage areas) owned by _storm_
* `webdav`: is the StoRM WebDAV service. The base URL is https://storm.test.example:8443. It serves the following storage areas:
  * `indigo-dc` for users presenting a proxy issued by the local `vomsaa` service (serving the `indigo-dc` VO)
  * `noauth`: which allows read/write mode also to anonymous users
  * `fga`: for a fined grained authorization storage area. Its access policies are set in the [application](./webdav/etc/storm/webdav/config/application-policies.yml) file
  * `oauth-authz`: for users presenting a token issued by the local `iam` service
* `clients`: is an image containing GRID clients (e.g. `voms-proxy-init`, `gfal`, `oidc-agent`, etc.) used to query the local VOMS AA and IAM services.

Basically, both iam and VOMS are local services, so there is no need to register your credentials elsewhere.
  
To resolve the hostname of the services, add a line in your `/etc/hosts` file with

```
127.0.0.1	voms.test.example   iam.test.example   storm.test.example
```

## Setup credentials

### X.509

The `vomsaa` service is connected to an IAM db where a test0 certificate is linked to the test user.
The user is also member of the `indigo-dc/xfers` default group and `/indigo-dc/webdav` _optional group_.

Thus, the `clients` container allows you to directly ask `vomsaa` for AC extensions (i.e. VOMS proxies).
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

### JWT

This tutorial is provided with an `oidc-agent` client configuration (registered within the local `iam` service) mounted in the `clients` container. The CLIEN_ID and SECRET are saved in the db dump used in this compose.

Set the following variable and add the client configuration to the `oidc-agent` service with

```bash
export OIDC_AGENT_ALIAS=test0
export OIDC_AGENT_SECRET=password
eval $(oidc-agent-service use)
oidc-add --pw-env=OIDC_AGENT_SECRET ${OIDC_AGENT_ALIAS}
```

Ask for a token with

```bash
$ oidc-token ${OIDC_AGENT_ALIAS} | cut -d. -f2 | base64 -d 2>/dev/null | jq .
{
  "wlcg.ver": "1.0",
  "sub": "80e5fb8d-b7c8-451a-89ba-346ae278a66f",
  "aud": "https://wlcg.cern.ch/jwt/v1/any",
  "nbf": 1746377395,
  "scope": "openid offline_access wlcg.groups",
  "iss": "https://iam.test.example/",
  "exp": 1746380995,
  "iat": 1746377395,
  "jti": "25f9facb-d77d-4c54-89ec-464152cb91db",
  "client_id": "6a86717b-5153-4592-a636-2bf021694a58",
  "wlcg.groups": [
    "/Analysis",
    "/Production",
    "/indigo-dc",
    "/indigo-dc/xfers"
  ]
}
```

## indigo-dc

The `indigo-dc` Storage Area (SA) allows to read/write any proxy signed by a `indigo-dc` (i.e. the local `vomsaa`).
If not already done, copy the test0 certificates into the `~/.globus` directory and create a VOMS proxy with

```bash
echo pass | voms-proxy-init -voms indigo-dc -pwstdin
```
Create a test file

```bash
echo "Test text" > testfile
```

Copy the file on WebDAV with the VOMS credential and check its content

```bash
$ gfal-copy testfile https://storm.test.example:8443/indigo-dc/testfile
Copying file:///home/test/testfile   [DONE]  after 0s
$ gfal-cat https://storm.test.example:8443/indigo-dc/testfile
Test text
```

Remove the test file on WebDAV

```bash
$ gfal-rm https://storm.test.example:8443/indigo-dc/testfile
https://storm.test.example:8443/indigo-dc/testfile      DELETED
$ gfal-cat https://storm.test.example:8443/indigo-dc/testfile
gfal-cat error: 2 (No such file or directory) - Result HTTP 404 : File not found  after 1 attempts
```

Cross-check that you cannot create a file in the fine-grained SA

```bash
$ gfal-copy testfile https://storm.test.example:8443/fga/testfile
Copying file:///home/test/testfile   [FAILED]  after 0s                                                                  
gfal-copy error: 1 (Operation not permitted) - DESTINATION OVERWRITE   HTTP 403 : Permission refused 
```

## fga

This is a fine-grained SA, whose permissions are the following

* read/write the `/fga/xfers` folder allowed to `/indigo-dc/xfers` members (default IAM group) of the `iam` local service and users of the `/indigo-dc/xfers` VOMS group (the AC is signed by the `vomsaa` local service)
* read/write the whole SA allowed to `/indigo-dc/webdav` members (optional IAM group) and users with VOMS role = webdav
* read access to tokens issued by `iam` and proxies signed by the `indigo-dc` VO
* read access to anyone to the `/fga/public` folder and subfolders.

Remove the proxy if you have one

```bash
voms-proxy-destroy
```

and check that you have anonymous read-only access to the public area

```bash
$ gfal-ls https://storm.test.example:8443/fga/public
gfal-ls error: 2 (No such file or directory) - Result HTTP 404 : File not found  after 1 attempts
$ gfal-mkdir https://storm.test.example:8443/fga/public
gfal-mkdir error: 13 (Permission denied) - HTTP 401 : Authentication Error
```

Create a test file

```bash
echo "Testing the fine grained SA permissions" > fga_testing
```

### VOMS proxy

#### VOMS proxy with primary group

Create a VOMS proxy (signed by `vomsaa`), containing also the groups the user is memeber of, with

```bash
echo pass | voms-proxy-init -voms indigo-dc -pwstdin
```

and cross check that the `/indigo-dc/xfers` is listed among the VOMS attributes

```bash
$ voms-proxy-info -all
subject   : /C=IT/O=IGI/CN=test0/CN=552120961
issuer    : /C=IT/O=IGI/CN=test0
identity  : /C=IT/O=IGI/CN=test0
type      : RFC3820 compliant impersonation proxy
strength  : 2048
path      : /tmp/x509up_u1000
timeleft  : 11:59:52
key usage : Digital Signature, Non Repudiation, Key Encipherment
=== VO indigo-dc extension information ===
VO        : indigo-dc
subject   : /C=IT/O=IGI/CN=test0
issuer    : /C=IT/O=IGI/CN=voms.test.example
attribute : /indigo-dc/Role=NULL/Capability=NULL
attribute : /indigo-dc/xfers/Role=NULL/Capability=NULL
timeleft  : 11:59:51
uri       : voms.test.example:8080
```

Now ask for the `/indigo-dc/xfers` group to be the **primary** with

```bash
$ echo pass | voms-proxy-init -voms indigo-dc -order /indigo-dc/xfers -pwstdin
$ voms-proxy-info -all
subject   : /C=IT/O=IGI/CN=test0/CN=1499357201
issuer    : /C=IT/O=IGI/CN=test0
identity  : /C=IT/O=IGI/CN=test0
type      : RFC3820 compliant impersonation proxy
strength  : 2048
path      : /tmp/x509up_u1000
timeleft  : 11:57:51
key usage : Digital Signature, Non Repudiation, Key Encipherment
=== VO indigo-dc extension information ===
VO        : indigo-dc
subject   : /C=IT/O=IGI/CN=test0
issuer    : /C=IT/O=IGI/CN=voms.test.example
attribute : /indigo-dc/xfers/Role=NULL/Capability=NULL
attribute : /indigo-dc/Role=NULL/Capability=NULL
timeleft  : 11:57:51
uri       : voms.test.example:8080
```

Copy the test file on WebDAV in the dedicated `/fga/xfers` path with the VOMS credential and check its content

```bash
$ gfal-copy fga_testing https://storm.test.example:8443/fga/xfers/fga_testing
Copying file:///home/test/fga_testing   [DONE]  after 0s
$ gfal-cat https://storm.test.example:8443/fga/xfers/fga_testing
Testing the fine grained SA permissions
```

Remove the test file and check that it succeeded with

```bash
$  gfal-rm https://storm.test.example:8443/fga/xfers/fga_testing
https://storm.test.example:8443/fga/xfers/fga_testing   DELETED
$ gfal-cat https://storm.test.example:8443/fga/xfers/fga_testing
gfal-cat error: 2 (No such file or directory) - Result HTTP 404 : File not found  after 1 attempts
```

#### VOMS role

Create a VOMS proxy (signed by `vomsaa`) with Role=webdav with

```bash
echo pass | voms-proxy-init -voms indigo-dc:/indigo-dc/Role=webdav -pwstdin
```

and cross-check that it appears as attribute in the proxy (note that it was not appearing if not explicitely requested)

```bash
$ voms-proxy-info -all
subject   : /C=IT/O=IGI/CN=test0/CN=2077821009
issuer    : /C=IT/O=IGI/CN=test0
identity  : /C=IT/O=IGI/CN=test0
type      : RFC3820 compliant impersonation proxy
strength  : 2048
path      : /tmp/x509up_u1000
timeleft  : 11:59:54
key usage : Digital Signature, Non Repudiation, Key Encipherment
=== VO indigo-dc extension information ===
VO        : indigo-dc
subject   : /C=IT/O=IGI/CN=test0
issuer    : /C=IT/O=IGI/CN=voms.test.example
attribute : /indigo-dc/Role=webdav/Capability=NULL
attribute : /indigo-dc/Role=NULL/Capability=NULL
attribute : /indigo-dc/xfers/Role=NULL/Capability=NULL
timeleft  : 11:59:54
uri       : voms.test.example:8080
```

Copy the file on WebDAV in the SA root (`/fga`) with the VOMS role and check its content

```bash
$ gfal-copy fga_testing https://storm.test.example:8443/fga/fga_testing
Copying file:///home/test/fga_testing   [DONE]  after 0s
$ gfal-cat https://storm.test.example:8443/fga/fga_testing
Testing the fine grained SA permissions
```

#### Generic VOMS proxy

Now use the generic proxy signed by a `indigo-dc` VO

```bash
echo pass | voms-proxy-init -voms indigo-dc -pwstdin
```

and cross-check that you can read the previously created file

```bash
$ gfal-cat https://storm.test.example:8443/fga/fga_testing
Testing the fine grained SA permissions
```

but cannot remove it

```bash
$ gfal-rm https://storm.test.example:8443/fga/fga_testing
https://storm.test.example:8443/fga/fga_testing FAILED
gfal-rm error: 1 (Operation not permitted) - DavPosix::unlink  HTTP 403 : Permission refused
```

Now destroy the VOMS proxy

```bash
voms-proxy-destroy
```

### JWT

#### JWT default group

Create an access token issued by `iam`, with the default WLCG groups

```bash
AT=$(oidc-token -s wlcg.groups ${OIDC_AGENT_ALIAS})
```

and cross check that the `/indigo-dc/xfers` is listed among the groups within the _wlcg.group_ claim

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
$ AT=$(oidc-token -s wlcg.groups -s wlcg.groups:/indigo-dc/xfers ${OIDC_AGENT_ALIAS})
$ echo $AT | cut -d. -f2 | base64 -d 2>/dev/null | jq .
{
  "wlcg.ver": "1.0",
  "sub": "80e5fb8d-b7c8-451a-89ba-346ae278a66f",
  "aud": "https://wlcg.cern.ch/jwt/v1/any",
  "nbf": 1746377883,
  "scope": "wlcg.groups:/indigo-dc/xfers wlcg.groups",
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

Set the `BEARER_TOKEN` environment variable (used by `Gfal`)

```bash
export BEARER_TOKEN=$AT
```

Copy the test file on WebDAV in the dedicated `/fga/xfers` path with the JWT credential and check its content

```bash
$ gfal-copy fga_testing https://storm.test.example:8443/fga/xfers/fga_testing
Copying file:///home/test/fga_testing   [DONE]  after 0s                                                                 
$ gfal-cat https://storm.test.example:8443/fga/xfers/fga_testing
Testing the fine grained SA permissions
```

Remove the test file and check that it succeeded with

```bash
$ gfal-rm https://storm.test.example:8443/fga/xfers/fga_testing
https://storm.test.example:8443/fga/xfers/fga_testing   DELETED
$ gfal-cat https://storm.test.example:8443/fga/xfers/fga_testing
gfal-cat error: 2 (No such file or directory) - Result HTTP 404 : File not found  after 1 attempts
```

#### JWT optional group

Create an access token from `iam`, with the WLCG optional group `/indigo-dc/webdav`

```bash
AT=$(oidc-token -s wlcg.groups -s wlcg.groups:/indigo-dc/webdav ${OIDC_AGENT_ALIAS})
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

Update the `BEARER_TOKEN` environment variable

```bash
export BEARER_TOKEN=$AT
```

Copy the file on WebDAV in the SA root (`/fga`) with the VOMS role and check its content

```bash
$ gfal-copy fga_testing https://storm.test.example:8443/fga/fga_testing_jwt
Copying file:///home/test/fga_testing   [DONE]  after 0s
$ gfal-cat https://storm.test.example:8443/fga/fga_testing_jwt
Testing the fine grained SA permissions
```

#### Generic JWT

Use a generic token with minimum privileges issued by `iam`

```bash
AT=$(oidc-token -s openid ${OIDC_AGENT_ALIAS})
```

Update the `BEARER_TOKEN` environment variable

```bash
export BEARER_TOKEN=$AT
```

Cross-check that you can read the previously created file

```bash
$ gfal-cat https://storm.test.example:8443/fga/fga_testing_jwt
Testing the fine grained SA permissions
```

but cannot remove it

```bash
$  gfal-rm https://storm.test.example:8443/fga/fga_testing_jwt
https://storm.test.example:8443/fga/fga_testing_jwt     FAILED
gfal-rm error: 1 (Operation not permitted) - DavPosix::unlink  HTTP 403 : Permission refused 
```

#### JWT: Tip

The Bearer Token is sent to StoRM WebDAV through the HTTP header, means that to create/read/delete the file we could just use curl

```bash
$ AT=$(oidc-token -s wlcg.groups:/indigo-dc/webdav ${OIDC_AGENT_ALIAS})
$ curl -H "Authorization: Bearer $AT" https://storm.test.example:8443/fga/fga_testing_curl -XPUT --upload-file fga_testing -w '%{http_code}\n'
201
$ curl -H "Authorization: Bearer $AT" https://storm.test.example:8443/fga/fga_testing_curl
Testing the fine grained SA permissions
$ curl -H "Authorization: Bearer $AT" https://storm.test.example:8443/fga/fga_testing_curl -XDELETE -w '%{http_code}\n'  -s -o /dev/null
204
$ curl -H "Authorization: Bearer $AT" https://storm.test.example:8443/fga/fga_testing_curl -w '%{http_code}\n' -s -o /dev/null
404
```