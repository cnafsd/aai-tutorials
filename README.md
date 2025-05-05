# AAI tutorials

This repo holds docker-compose files for AAI tutorials, in particular

* [indigo-iam](./indigo-iam/) folder can be used to play with the IAM web interface and `iam-test-client` (a demo Web application which allows you to get an access token)
* [storm-webdav](./storm-webdav) folder can be used to play with StoRM WebDAV, including its access policies, with the already created X.509 credentials and VOMS proxies
* [vomsaa](./vomsaa) folder contains a VOMS AA server (issuing proxies) and a Grid clients container. A db is also loaded and populated with users and linked certificates, which allows you to ask for a VOMS proxy with different attributes
* [vomsaa-iam](./vomsaa-iam) allows you to ask for a VOMS proxy with different attributes. Also, you can play with group membership (i.e. add/remove the _test_ user to some group) and check that the change is propagated in the VOMS proxy
* [vomsaa-iam-webdav](./vomsaa-iam-webdav/) self-contained examples on how to get a token (from the local IAM) or a proxy (from the local VOMS AA) and access a StoRM WebDAV resource
* [vomsaa-webdav](./vomsaa-webdav/) allows to ask for a token to the local VOMS AA and be authorized to access resource by the local StoRM WebDAV.