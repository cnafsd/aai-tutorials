#!/bin/bash

# SPDX-FileCopyrightText: 2014 Istituto Nazionale di Fisica Nucleare
#
# SPDX-License-Identifier: Apache-2.0

set -e

if [ ! -e "openssl.conf" ]; then
  >&2 echo "The configuration file 'openssl.conf' doesn't exist in this directory"
  exit 1
fi

certs_dir=/certs
ta_dir=/trust-anchors
ca_bundle_prefix=/etc/pki
vomsdir=/vomsdir

rm -rf "${certs_dir}"
mkdir -p "${certs_dir}"
rm -rf "${ta_dir}"
mkdir -p "${ta_dir}"
rm -rf "${vomsdir}"
mkdir -p "${vomsdir}"

export CA_NAME=igi_test_ca
export X509_CERT_DIR="${ta_dir}"

make_ca.sh

# Create server certificates
for c in voms_test_example storm_test_example; do
  make_cert.sh ${c}
  cp igi_test_ca/certs/${c}.* "${certs_dir}"
done

chmod 600 "${certs_dir}"/*.cert.pem
chmod 400 "${certs_dir}"/*.key.pem
chmod 600 "${certs_dir}"/*.p12
chown 1000:1000 "${certs_dir}"/*

# Create LSC file for test.vo
mkdir -p "${vomsdir}"/test.vo
openssl x509 -in "${certs_dir}"/voms_test_example.cert.pem -noout -subject -issuer -nameopt compat \
  | sed -e 's/subject=//' -e 's/issuer=//' > "${vomsdir}"/test.vo/voms.test.example.lsc

# Create user certificates
for i in $(seq 0 5); do
  make_cert.sh test${i}
  cp igi_test_ca/certs/test${i}.* "${certs_dir}"
done

faketime -f -1y env make_cert.sh expired
cp igi_test_ca/certs/expired.* "${certs_dir}"

make_cert.sh revoked
cp igi_test_ca/certs/revoked.* "${certs_dir}"
revoke_cert.sh revoked

proxy_name=x509up_test.vo
echo pass | voms-proxy-fake --debug -conf proxies.d/${proxy_name}.conf -out "${certs_dir}"/${proxy_name} \
  --pwstdin
chmod 600 "${certs_dir}"/${proxy_name}

chmod 600 "${certs_dir}"/*.cert.pem
chmod 400 "${certs_dir}"/*.key.pem
chmod 600 "${certs_dir}"/*.p12
chown 1000:1000 "${certs_dir}"/*

make_crl.sh
install_ca.sh igi_test_ca "${ta_dir}"

# Add igi-test-ca to system certificates
ca_bundle="${ca_bundle_prefix}"/tls/certs
cat "${ta_dir}"/igi_test_ca.pem >> "${ca_bundle}"/ca-bundle.crt
