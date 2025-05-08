# Docker compose for StoRM WebDAV

This folder can be used to play with StoRM WebDAV, including its access policies, with the already created X.509 credentials and VOMS proxies.

## Run the compose

Create the required missing file that will contain the oidc-agent client details in
`assets/oidc-agent/oidc-agent.env`

```bash
OIDC_AGENT_ALIAS=changeme
OIDC_AGENT_SECRET=changeme
```

Build the trustanchor

```bash
docker compose build --no-cache trust
```

Run the services with

```bash
docker compose up -d
```

The docker-compose file contains the next services:

* `trust`: docker image for the _igi-test-ca_ CA certificate issuing server/user certificates, usually mounted in the `/etc/grid-security/certificates` path of the other services. The container populates a `/certs` volume containing server/user X.509 certificates and VOMS proxies, self-emitted through `voms-proxy-fake` (without the interaction with a VOMS server)
* `storage-setup`: sidecar container, used to allocate proper volumes (i.e. storage areas) owned by _storm_
* `webdav`: is the main service, also known as StoRM WebDAV. The StoRM WebDAV base URL is https://storm.test.example:8443. It serves the following storage areas:
  * `test.vo` for users presenting a proxy issued by a _test.vo_ VO
  * `noauth`: which allows read/write mode also to anonymous users
  * `fga`: for a fined grained authorization storage area. Its access policies are set in the [application](./assets/etc/storm/webdav/config/application-policies.yml) file
  * `oauth-authz`: for users presenting a token issued by the [IAM DEV](https://iam-dev.cloud.cnaf.infn.it)
* `clients`: used for running the GRID clients (e.g. `voms-proxy-init`, `gfal`, `oidc-agent`, etc.).

To resolve the hostname of the service, add a line in your `/etc/hosts` file with

```
127.0.0.1	storm.test.example
```

To stop the services and remove orphans containers (the `trust` one) run

```bash
docker compose down -v --remove-orphans
```

## Clients

To perform tests with GRID clients, enter in the container

```bash
docker compose exec clients bash
```

Some proxy with different VOMS extensions are available in the container (self-created, through `voms-proxy-fake`, meaning without the interaction with a VOMS server)

```bash
$ ls -l /certs/x509up_*
-rw------- 1 test test 6188 May  2 21:07 /certs/x509up_dev
-rw------- 1 test test 6212 May  2 21:07 /certs/x509up_dev_role
-rw------- 1 test test 6204 May  2 21:07 /certs/x509up_test.vo
```

Copy one of them (e.g. the proxy issued by `test.vo`) into the well-known path

```bash
cp /certs/x509up_test.vo /tmp/x509up_u1000
```

and check its content with

```
$ voms-proxy-info -all
subject   : /C=IT/O=IGI/CN=test0/CN=2971505125
issuer    : /C=IT/O=IGI/CN=test0
identity  : /C=IT/O=IGI/CN=test0
type      : RFC3820 compliant impersonation proxy
strength  : 2048
path      : /tmp/x509up_u1000
timeleft  : 11:54:07
key usage : Digital Signature, Key Encipherment
=== VO test.vo extension information ===
VO        : test.vo
subject   : /C=IT/O=IGI/CN=test0
issuer    : /C=IT/O=IGI/CN=voms.test.example
attribute : /test.vo
timeleft  : 11:54:06
uri       : voms.test.example:15000
```

### test.vo

The `test.vo` Storage Area (SA) allows to read/write any proxy signed by a `test.vo`.
To use it, copy the already generated proxy into the well-known path

```bash
cp /certs/x509up_test.vo /tmp/x509up_u1000
```

Create a test file

```bash
echo "Test text" > testfile
```

Copy the file on WebDAV with the VOMS credential and check its content

```bash
$ gfal-copy testfile https://storm.test.example:8443/test.vo/testfile
Copying file:///home/test/testfile   [DONE]  after 0s
$ gfal-cat https://storm.test.example:8443/test.vo/testfile
Test text
```

Remove the test file on WebDAV

```bash
$ gfal-rm https://storm.test.example:8443/test.vo/testfile
https://storm.test.example:8443/test.vo/testfile        DELETED
$ gfal-cat https://storm.test.example:8443/test.vo/testfile
gfal-cat error: 2 (No such file or directory) - Result HTTP 404 : File not found  after 1 attempts
```

Cross-check that you cannot create a file in the fine-grained SA

```bash
$ gfal-copy testfile https://storm.test.example:8443/fga/testfile
Copying file:///home/test/testfile   [FAILED]  after 0s                                                                  
gfal-copy error: 1 (Operation not permitted) - DESTINATION OVERWRITE   HTTP 403 : Permission refused 
```

### fga

This is a fine-grained SA, whose permissions are the following
* read/write to `/dev/webdav` members (optional IAM group) of [IAM DEV](https://iam-dev.cloud.cnaf.infn.it) and users with VOMS role = webdav
* read access to tokens issued by [IAM DEV](https://iam-dev.cloud.cnaf.infn.it) and proxies signed by the `dev` VO
* read access to anyone to the `/fga/public` folder and subfolders.

Check that you have anonymous read-only access to the public area

```bash
$ gfal-ls https://storm.test.example:8443/fga/public
gfal-ls error: 2 (No such file or directory) - Result HTTP 404 : File not found  after 1 attempts
$ gfal-mkdir https://storm.test.example:8443/fga/public
gfal-mkdir error: 13 (Permission denied) - HTTP 401 : Authentication Error
```

Create a test file

```bash
echo "Test text" > testfile
```

#### VOMS role

Use the the proxy with `/dev/Role=webdav` role obtained by a `dev` VO

```bash
cp /certs/x509up_dev_role /tmp/x509up_u1000
```

Copy the file on WebDAV with the VOMS credential and check its content

```bash
$ gfal-copy testfile https://storm.test.example:8443/fga/testfile
Copying file:///home/test/testfile   [DONE]  after 0s
$ gfal-cat https://storm.test.example:8443/fga/testfile
Test text
```

#### VOMS proxy

Now use the generic proxy signed by a `dev` VO

```bash
cp /certs/x509up_dev /tmp/x509up_u1000
```

and cross-check that you can read the file

```bash
$ gfal-cat https://storm.test.example:8443/fga/testfile
Test text
```

but cannot remove it

```bash
$ gfal-rm https://storm.test.example:8443/fga/testfile
https://storm.test.example:8443/fga/testfile    FAILED
gfal-rm error: 1 (Operation not permitted) - DavPosix::unlink  HTTP 403 : Permission refused
```

Now destroy the VOMS proxy

```bash
voms-proxy-destroy
```

#### JWT with default groups

Use a generic token issued by [IAM DEV](https://iam-dev.cloud.cnaf.infn.it) instead. In this tutorial, an `oidc-agent` client configuration mounted in the `clients` container is used, but you should create a new one since the CLIENT_ID/SECRET MUST NOT be shared among users!

Register an oidc-agent client in [IAM DEV](https://iam-dev.cloud.cnaf.infn.it) and save its alias and secret in

```bash
OIDC_AGENT_ALIAS=<alias-for-oidc-agent-client>
OIDC_AGENT_SECRET=<oidc-agent-client-secret>
```

Start the `oidc-agent` service and add the client configuration with

```bash
eval $(oidc-agent-service use)
oidc-add --pw-env=OIDC_AGENT_SECRET ${OIDC_AGENT_ALIAS}
```

Set the environment variable (used by `Gfal`)

```bash
export BEARER_TOKEN=$(oidc-token ${OIDC_AGENT_ALIAS})
```

Cross-check that you can read the file

```bash
$ gfal-cat https://storm.test.example:8443/fga/testfile
Test text
```

but cannot remove it

```bash
$ gfal-rm https://storm.test.example:8443/fga/testfile
https://storm.test.example:8443/fga/testfile    FAILED
gfal-rm error: 1 (Operation not permitted) - DavPosix::unlink  HTTP 403 : Permission refused
```

#### JWT with optional groups

Now ask for a token with the optional `dev/webdav` group

```bash
export BEARER_TOKEN=$(oidc-token -s wlcg.groups:/dev/webdav dev-wlcg)
```

and cross-check that you can read and delete the file

```bash
$ gfal-cat https://storm.test.example:8443/fga/testfile
Test text
$ gfal-rm https://storm.test.example:8443/fga/testfile
https://storm.test.example:8443/fga/testfile    DELETED
$ gfal-cat https://storm.test.example:8443/fga/testfile
gfal-cat error: 2 (No such file or directory) - Result HTTP 404 : File not found  after 1 attempts
```

**Tip:** The Bearer Token is sent to StoRM WebDAV through the HTTP header, means that to create/read/delete the file we could just use curl

```bash
$ BEARER_TOKEN=$(oidc-token -s wlcg.groups:/dev/webdav dev-wlcg)
$ curl -H "Authorization: Bearer $BEARER_TOKEN" https://storm.test.example:8443/fga/newfile -XPUT --upload-file testfile -w '%{http_code}\n'
201
$ curl -H "Authorization: Bearer $BEARER_TOKEN" https://storm.test.example:8443/fga/newfile
Test text
$ $ curl -H "Authorization: Bearer $BEARER_TOKEN" https://storm.test.example:8443/fga/newfile -XDELETE -w '%{http_code}\n'  -s -o /dev/null
204
$ curl -H "Authorization: Bearer $BEARER_TOKEN" https://storm.test.example:8443/fga/newfile -w '%{http_code}\n' -s -o /dev/null
404
```