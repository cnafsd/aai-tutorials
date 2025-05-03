# Docker compose for VOMS Attribute Authority (voms-aa)

Run the services with

```bash
docker compose up -d
```

The docker-compose contains several services:

* `db`: is a mysql database used by INDIGO IAM and VOMS-AA. A dump of the database with test users plus a _test0_ certificate linked to an account may be enabled
* `trust`: docker image for the GRID CA certificates, mounted in the `/etc/grid-security/certificates` path of the other services. The _igi-test-ca_ used in this deployment is also present in that path
* `nginx-voms`: is the NGINX reverse proxy which forwards requests to the VOMS-AA microservice (it differs by the `iam` service since it supports HTTPG). URL of this service is https://voms.test.example:8443
* `vomsaa`: is the VOMS-AA microservice which acts as VOMS Admin
* `clients`: is an image containing GRID clients (in particular _voms-proxy-init_) used to query the VOMS AA service.
  
To resolve the hostname of the service, add a line in your `/etc/hosts` file with

```
127.0.0.1	voms.test.example
```

## Setup credentials

This voms-aa is connected to an IAM db where a test0 certificate is linked to the test user.
The user is also member of the `indigo-dc/xfer` default group and `/indigo-dc/webdav` optional group.

Thus, the `clients` container may directly ask for proxies.

Set the user certificates with

```bash
cp /certs/test0.cert.pem ~/.globus/usercert.pem
cp /certs/test0.key.pem ~/.globus/userkey.pem
```

Ask for a VO proxy with

```bash
$ voms-proxy-init -voms indigo-dc
Enter GRID pass phrase for this identity:
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