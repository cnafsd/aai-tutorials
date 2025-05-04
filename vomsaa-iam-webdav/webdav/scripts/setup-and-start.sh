#!/bin/sh
set -ex

# This upload in the java keystore also the igi-test-ca
/scripts/init-bundle.sh

java ${STORM_WEBDAV_JVM_OPTS} -cp app:app/lib/* org.italiangrid.storm.webdav.WebdavService