# Docker compose for VOMS AA and StoRM WevDAV

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
* `nginx`: is the NGINX reverse proxy which forwards requests to the VOMS-AA microservice. URL of this service is https://voms.test.example:8445
* `vomsaa`: is the VOMS-AA microservice which acts as VOMS Admin. It serves the `indigo-dc` VO
* `db`: is a mysql database used by INDIGO IAM and VOMS-AA. A dump of the database with test users plus a _test0_ certificate linked to an account may be enabled. The test user also belong to the `indigo-dc` VO/IAM group, such that it can request for VOMS proxies
* `storage-setup`: sidecar container, used to allocate proper volumes (i.e. storage areas) owned by _storm_
* `webdav`: is the main service, also known as StoRM WebDAV. The StoRM WebDAV base URL is https://storm.test.example:8443. It serves the following storage areas:
  * `indigo-dc` for users presenting a proxy issued by the `vomsaa` service (serving the `indigo-dc` VO)
  * `test.vo` for users presenting a proxy issued by a _test.vo_ VO
  * `noauth`: which allows read/write mode also to anonymous users
  * `fga`: for a fined grained authorization storage area. Its access policies are set in the [application](./webdav/etc/storm/webdav/config/application-policies.yml) file
  * `oauth-authz`: for users presenting a token issued by the [IAM DEV](https://iam-dev.cloud.cnaf.infn.it)
* `clients`: is an image containing GRID clients (e.g. `voms-proxy-init`, `gfal`, `oidc-agent`, etc.) used to query the VOMS AA service.
  
To resolve the hostname of the services, add a line in your `/etc/hosts` file with

```
127.0.0.1	voms.test.example   storm.test.example
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

This tutorial is provided with an `oidc-agent` client configuration (linked to [IAM DEV](https://iam-dev.cloud.cnaf.infn.it)) mounted in the `clients` container, but you should create a new one since the CLIENT_ID/SECRET MUST NOT be shared among users!

Set the following variable and add the client configuration to the `oidc-agent` service with

```bash
OIDC_AGENT_ALIAS=<alias-for-oidc-agent-client>
OIDC_AGENT_SECRET=<oidc-agent-client-secret>
eval $(oidc-agent-service use)
oidc-add --pw-env=OIDC_AGENT_SECRET ${OIDC_AGENT_ALIAS}
```

## indigo-dc

The `indigo-dc` Storage Area (SA) allows to read/write any proxy signed by a `indigo-dc`.
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
* read/write to `/fga/xfers` folder to `/dev/xfers` members (default IAM group) of [IAM DEV](https://iam-dev.cloud.cnaf.infn.it) and users of `/indigo-dc/xfers` VOMS group
* read/write to SA to `/dev/webdav` members (optional IAM group) of [IAM DEV](https://iam-dev.cloud.cnaf.infn.it) and users with VOMS role = webdav
* read access to tokens issued by [IAM DEV](https://iam-dev.cloud.cnaf.infn.it) and proxies signed by the `dev` and `indigo-dc` VOs
* read access to anyone to the `/fga/public` folder and subfolders.

Temove the proxy if you have one

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

Create an access token issued by [IAM DEV](https://iam-dev.cloud.cnaf.infn.it), with the default WLCG groups

```bash
AT=$(oidc-token -s wlcg.groups ${OIDC_AGENT_ALIAS})
```

and cross check that the `/dev/xfers` is listed among the groups within the _wlcg.group_ claim

```bash
$ echo $AT | cut -d. -f2 | base64 -d 2>/dev/null | jq .
{
  "wlcg.ver": "1.0",
  "sub": "d331b9e3-c5bd-4e1c-a519-c9b93a093d0b",
  "aud": "https://wlcg.cern.ch/jwt/v1/any",
  "nbf": 1746368097,
  "scope": "wlcg.groups",
  "iss": "https://iam-dev.cloud.cnaf.infn.it/",
  "exp": 1746371697,
  "iat": 1746368097,
  "jti": "fb971529-6751-4da8-9119-e6e0492c3d3e",
  "client_id": "cf199b96-bec5-4f2e-a89c-e85d0dfdd8a5",
  "wlcg.groups": [
    "/RootGroup",
    "/cms",
    "/cnafsd",
    "/dev",
    "/dev/xfers",
    "/otello",
    "/otello/editor"
  ]
}
```

Now ask for the `/dev/xfers` group to be the **primary** with

```bash
$ AT=$(oidc-token -s wlcg.groups -s wlcg.groups:/dev/xfers ${OIDC_AGENT_ALIAS})
$ echo $AT | cut -d. -f2 | base64 -d 2>/dev/null | jq .
{
  "wlcg.ver": "1.0",
  "sub": "d331b9e3-c5bd-4e1c-a519-c9b93a093d0b",
  "aud": "https://wlcg.cern.ch/jwt/v1/any",
  "nbf": 1746368468,
  "scope": "wlcg.groups:/dev/xfers wlcg.groups",
  "iss": "https://iam-dev.cloud.cnaf.infn.it/",
  "exp": 1746372068,
  "iat": 1746368468,
  "jti": "143ca821-410f-41b1-957c-13b28354f564",
  "client_id": "cf199b96-bec5-4f2e-a89c-e85d0dfdd8a5",
  "wlcg.groups": [
    "/dev/xfers",
    "/RootGroup",
    "/cms",
    "/cnafsd",
    "/dev",
    "/otello",
    "/otello/editor"
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

Create an access token [IAM DEV](https://iam-dev.cloud.cnaf.infn.it), with the WLCG optional group `/dev/webdav`

```bash
AT=$(oidc-token -s wlcg.groups -s wlcg.groups:/dev/webdav ${OIDC_AGENT_ALIAS})
```

and cross-check that it is listed among the groups within the _wlcg.group_ claim (note that it was not appearing when not explicitely requested)

```bash
$ echo $AT | cut -d. -f2 | base64 -d 2>/dev/null | jq .
{
  "wlcg.ver": "1.0",
  "sub": "d331b9e3-c5bd-4e1c-a519-c9b93a093d0b",
  "aud": "https://wlcg.cern.ch/jwt/v1/any",
  "nbf": 1746369501,
  "scope": "wlcg.groups:/dev/webdav wlcg.groups",
  "iss": "https://iam-dev.cloud.cnaf.infn.it/",
  "exp": 1746373101,
  "iat": 1746369501,
  "jti": "32dbf487-8013-422c-a2b7-0fcb356d8f3f",
  "client_id": "cf199b96-bec5-4f2e-a89c-e85d0dfdd8a5",
  "wlcg.groups": [
    "/dev/webdav",
    "/RootGroup",
    "/cms",
    "/cnafsd",
    "/dev",
    "/dev/xfers",
    "/otello",
    "/otello/editor"
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

Use a generic token with minimum privileges issued by [IAM DEV](https://iam-dev.cloud.cnaf.infn.it)

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
$ AT=$(oidc-token -s wlcg.groups:/dev/webdav dev-wlcg)
$ curl -H "Authorization: Bearer $AT" https://storm.test.example:8443/fga/fga_testing_curl -XPUT --upload-file fga_testing -w '%{http_code}\n'
201
$ curl -H "Authorization: Bearer $AT" https://storm.test.example:8443/fga/fga_testing_curl
Testing the fine grained SA permissions
$ curl -H "Authorization: Bearer $AT" https://storm.test.example:8443/fga/fga_testing_curl -XDELETE -w '%{http_code}\n'  -s -o /dev/null
204
$ curl -H "Authorization: Bearer $AT" https://storm.test.example:8443/fga/fga_testing_curl -w '%{http_code}\n' -s -o /dev/null
404
```