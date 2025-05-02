# Docker compose for INDIGO IAM

Run the services with

```
docker-compose up -d
```

The docker-compose contains several services:

* `trust`: docker image for the GRID CA certificates, mounted in the `/etc/grid-security/certificates` path of the other services. The _igi-test-ca_ used in this deployment is also present in that path
* `iam-be`: is the main service, also known as `iam-login-service`. The INDIGO IAM base URL is https://iam.test.example
* `client`: is an example of a client application (also known as `iam-test-client`), where a login button redirects to `iam-be` to start an authorization code flow. URL of this service is https://iam.test.example/iam-test-client
* `iam`: is an `nginx` image used for TLS termination and reverse proxy
* `db`: is a mysql database used by INDIGO IAM and VOMS-AA. A dump of the database with test users plus a _test0_ certificate linked to an account may be enabled.
  
To resolve the hostname of the service, add a line in your `/etc/hosts` file with

```
127.0.0.1	iam.test.example
```


## INDIGO IAM versions

To switch between different IAM versions, change the `IAM_IMAGE_TAG` variable located in the `.env` file with the desired version.
