#!/bin/bash -e

# 吊销一个签证过的证书

if [[ $# != 1 ]]
then
   echo "USEAGE: $0 revoke_cert_path.crt" 
   exit 0
fi

export CA_NAME="CA"

openssl ca -config openssl.cnf -revoke "${1}"
openssl ca -config openssl.cnf -gencrl -out "./${CA_NAME}/private/ca.crl"

# 查看吊销证书crl文件：
# openssl crl -in "./${CA_NAME}/private/ca.crl" -noout -text

echo "please config nginx: ssl_crl certs/ca.crl;  #启用吊销证书检查"

