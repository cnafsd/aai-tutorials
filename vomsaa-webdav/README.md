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

Ask for a VOMPS proxy with

```bash
$ voms-proxy-init -voms indigo-dc
Enter GRID pass phrase for this identity:  #pass
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

Ask for the specific VOMS Role `webdav` with

```bash
$ voms-proxy-init -voms indigo-dc:/indigo-dc/Role=webdav
Enter GRID pass phrase for this identity: #pass
Contacting voms.test.example:8443 [/C=IT/O=IGI/CN=voms.test.example] "indigo-dc"...
Remote VOMS server contacted succesfully.


Created proxy in /tmp/x509up_u1000.

Your proxy is valid until Mon May 05 00:15:17 CEST 2025
$ voms-proxy-info -all
subject   : /C=IT/O=IGI/CN=test0/CN=889219289
issuer    : /C=IT/O=IGI/CN=test0
identity  : /C=IT/O=IGI/CN=test0
type      : RFC3820 compliant impersonation proxy
strength  : 2048
path      : /tmp/x509up_u1000
timeleft  : 11:59:57
key usage : Digital Signature, Non Repudiation, Key Encipherment
=== VO indigo-dc extension information ===
VO        : indigo-dc
subject   : /C=IT/O=IGI/CN=test0
issuer    : /C=IT/O=IGI/CN=voms.test.example
attribute : /indigo-dc/Role=webdav/Capability=NULL
attribute : /indigo-dc/Role=NULL/Capability=NULL
attribute : /indigo-dc/xfers/Role=NULL/Capability=NULL
timeleft  : 11:59:57
uri       : voms.test.example:8080
```

Ask to set `/indigo-dc/xfers` as primary group (i.e. appearing as first attribute in the proxy)

```bash
$ voms-proxy-init -voms indigo-dc -order /indigo-dc/xfers
Enter GRID pass phrase for this identity:  #pass
Contacting voms.test.example:8443 [/C=IT/O=IGI/CN=voms.test.example] "indigo-dc"...
Remote VOMS server contacted succesfully.


Created proxy in /tmp/x509up_u1000.

Your proxy is valid until Mon May 05 00:21:35 CEST 2025
[test@e8431e11f954 ~]$ voms-proxy-info -all
subject   : /C=IT/O=IGI/CN=test0/CN=385623803
issuer    : /C=IT/O=IGI/CN=test0
identity  : /C=IT/O=IGI/CN=test0
type      : RFC3820 compliant impersonation proxy
strength  : 2048
path      : /tmp/x509up_u1000
timeleft  : 11:59:55
key usage : Digital Signature, Non Repudiation, Key Encipherment
=== VO indigo-dc extension information ===
VO        : indigo-dc
subject   : /C=IT/O=IGI/CN=test0
issuer    : /C=IT/O=IGI/CN=voms.test.example
attribute : /indigo-dc/xfers/Role=NULL/Capability=NULL
attribute : /indigo-dc/Role=NULL/Capability=NULL
timeleft  : 11:59:55
uri       : voms.test.example:8080
```