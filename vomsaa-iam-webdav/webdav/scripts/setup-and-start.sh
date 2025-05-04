#!/bin/sh
set -ex

# This uploads the igi-test-ca in the Java keystore
/scripts/init-bundle.sh

java ${STORM_WEBDAV_JVM_OPTS} -cp app:app/lib/* org.italiangrid.storm.webdav.WebdavService