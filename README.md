# AAI tutorials

This repo holds docker-compose files for AAI tutorials, in particular

* [indigo-iam](./indigo-iam/) folder can be used to play with the IAM web interface and `iam-test-client` (a demo Web application which allows you to get an access token)
* [storm-webdav](./storm-webdav/) folder can be used to play with StoRM WebDAV, including its access policies, with the already created X.509 credentials and VOMS proxies
* [voms-importer](./voms-importer/) it allows to import users from the a test instance of [VOMS Admin](https://meteora.cloud.cnaf.infn.it:8443/) into our test [IAM](https://iam-dev.cloud.cnaf.infn.it)
* [vomsaa](./vomsaa) folder contains a VOMS AA server (issuing proxies) and a Grid clients container. A db is also loaded and populated with users and linked certificates, which allows you to ask for a VOMS proxy with different attributes
* [vomsaa-iam](./vomsaa-iam) allows you to ask for a VOMS proxy with different attributes and JWT token to local services. Also, you can play with group membership (i.e. add/remove the _test_ user to some group) and check that the change is propagated in the VOMS proxy/access token
* [vomsaa-iam-webdav](./vomsaa-iam-webdav/) self-contained examples on how to get a token (from the local IAM) or a proxy (from the local VOMS AA) and access a StoRM WebDAV resource
* [vomsaa-webdav](./vomsaa-webdav/) allows to ask for a token to the local VOMS AA and be authorized to access resources served by the local StoRM WebDAV.

## Requisite

The basic requisite to run these tutorials is to have docker installed with the compose plugin

- to install docker engin on linux follow [this guide](https://docs.docker.com/engine/install/) (where you can find the list to the various platforms)
- to install the compose plugin on linux follow [this guide](https://docs.docker.com/compose/install/linux/).