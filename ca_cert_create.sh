#!/bin/bash -e

set -ex
# 创建CA根证书
# 设置创建目录不建议有空格
export CA_NAME="CA"

# 注意仔细阅读以下信息
# C:国家,S:省、州
# 申请证书时，要填写的必要信息
# [ policy_match ]   注意：match必须匹配，客户端申请证书和CA颁发填写的信息必须相同，如果配置里面配置了policy = policy_match 那签发的证书的countryName、stateOrProvinceName、organizationName 必须要匹配，如果policy = policy_anything 那就不需要配置。
# C: countryName     　　　　= match国家
# S: stateOrProvinceName 　= match省、州
# O: organizationName 　　  = match组织、公司名
# OU: organizationalUnitName = optional 部门
# CN: commonName 　　　　 = supplied 给哪个域名颁发
# emailAddress 　　　　  = optional[ policy_anything ] 邮件地址

# 国家名(2个字母的代号)
C="CN"
# 省
ST="Guangdong"
# 市
L="Guangzhou"
# 公司名
O="Example"
# 组织或部门名
OU="Root CA"
# 服务器FQDN或颁发者名
CN="Example Root CA"
# 可以不写邮箱
# 邮箱地址
emailAddress="it@example.com"

# 设置CA证书有效期
DAYS=3650

mkdir -p ./"${CA_NAME}"/{private,newcerts}
touch "./${CA_NAME}/index.txt"

if [[ ! -f "./${CA_NAME}/serial" ]];then
  echo 01 > "./${CA_NAME}/serial"
fi

if [[ ! -f "./${CA_NAME}/crlnumber" ]];then
  echo 01 > "./${CA_NAME}/crlnumber"
fi

if [[ ! -f "./${CA_NAME}/cacert.pem" ]];then
  # 不想证书显示OU emailAddress 的话创建证书时就不加上这两个参数即可 -subj "/C=${C}/ST=${ST}/L=${L}/O=${O}/OU=${OU}/CN=${CN}/emailAddress=${emailAddress}"
  # 如果需要配置私钥密码 只需要将 -nodes 替换为 -passout pass:123456
  # openssl req -utf8 -new -x509 -days ${DAYS} -newkey rsa:2048 -nodes -keyout "./${CA_NAME}/private/ca.key" -out "./${CA_NAME}/ca.crt" -subj "/C=${C}/ST=${ST}/O=${O}/CN=${CN}"
  # windows 系统下MinGW 版本的openssl创建时 -subj后面的参数 / 需要转义,建议使用git自带的openssl
  # openssl req -utf8 -new -x509 -days ${DAYS} -newkey rsa:2048 -nodes -keyout "./"${CA_NAME}"/private/ca.key" -out "./"${CA_NAME}"/ca.crt" -subj "//C=${C}\ST=${ST}\O=${O}\CN=${CN}"

  OS=`uname -s`
  if [[ ${OS} == "Darwin" || ${OS} == "Linux" ]];then
    openssl req -utf8 -new -x509 -days ${DAYS} -newkey rsa:2048 -nodes -keyout "./${CA_NAME}/private/ca.key" -out "./${CA_NAME}/ca.crt" -subj "/C=${C}/ST=${ST}/O=${O}/CN=${CN}" -config openssl.cnf
  elif [[ ${OS} =~ "_NT" ]];then
    openssl req -utf8 -new -x509 -days ${DAYS} -newkey rsa:2048 -nodes -keyout "./"${CA_NAME}"/private/ca.key" -out "./"${CA_NAME}"/ca.crt" -subj "//C=${C}\ST=${ST}\O=${O}\CN=${CN}" -config openssl.cnf
  fi
fi

if [[ ! -f "./${CA_NAME}/private/ca.crl" ]];then
  openssl ca -crldays ${DAYS} -gencrl -out "./${CA_NAME}/private/ca.crl" -config openssl.cnf
fi
