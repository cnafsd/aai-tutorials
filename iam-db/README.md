# Docker compose for INDIGO IAM db

This service is used by the `iam-login-service` application (read/write mode) and `voms-aa` (read-only).

## Dump of IAM db

This folder contains a dump of the IAM database.

The database is populated with an IAM Admin, test users, attributes, linked certificates, etc

The credentials used to login are

* Admin user: admin/password
* user test: test/password


## Run

Run the IAM db with

```bash
docker compose up -d
```

Enter in the container and connect to the db with

```bash
docker-compose exec db bash
mysql -u iam -ppwd -P3307 iam
```