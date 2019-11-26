#!/bin/bash -e

show_help() {
  echo "$0 [-h|-?|--help] [--ou ou] [--cn cn] [--email email]"
  echo "-h|-?|--help  显示帮助"
  echo "--ou       设置组织或部门名，如: IT"
  echo "--cn       设置FQDN或所有者名，如: example.com *.example.com"
  # echo "--email    设置FQDN或所有者邮件，如: test@example.com"
  echo "--ext      扩展文件路径（客户端证书不需要配置），如: example.com.cnf"
  echo "--days     设置证书有效期，如: 3650"
  echo "--alias    设置java证书的别名，如: server 或者 client"
  echo "--passwd   设置java keystore和truststore证书密码"
}

if [[ $# < 12  ]]
then
   show_help
   echo "当前参数量为：$#"
   exit 0
 else
     while [[ $# > 0 ]]
     do
       case $1 in
         -h|-\?|--help)
           show_help
           exit 0
           ;;
         --ou)
           OU="${2}"
           shift
           ;;    
         --cn)
           CN="${2}"      
           shift
           ;;
         --ext)
           EXT="${2}"      
           shift
           ;;
         --days)
           DAYS="${2}"      
           shift
           ;;
         --alias)
           ALIAS="${2}"      
           shift
           ;;
         --passwd)
           PASSWORD="${2}"
           shift
           ;;
         --)
           shift
           break
           ;;
         *)
           # echo -e "Error: $0 invalid option '$1'\nTry '$0 --help' for more information." >&2
           show_help
           exit 1
         ;;
       esac
     shift
     done
fi


# 创建客户端证书
# 非交互式方式创建以下内容:
export CA_NAME="CA"

# 国家名(2个字母的代号)
C=CN
# 省
ST=Guangdong
# 市
L=Guangzhou
# 公司名
O=Example
# 组织或部门名
OU=${OU:-测试部门}
# 服务器FQDN或授予者名
CN=${CN:-demo}
# 可以不写邮箱
# 邮箱地址
# emailAddress=${emailAddress:-demo@example.com}

# 扩展文件
EXT=${EXT}

# 证书有效期
DAYS=${DAYS:-3650}

# C:国家,S:省、州
#3、申请证书时，要填写的必要信息
# [ policy_match ]   注意：match必须匹配，客户端申请证书和CA颁发填写的信息必须相同，如果配置里面配置了policy = policy_match 那签发的证书的countryName、stateOrProvinceName、organizationName 必须要匹配，如果policy = policy_anything 那就不需要配置。
# C: countryName     　　　　= match国家
# S: stateOrProvinceName 　= match省、州
# O: organizationName 　　  = match组织、公司名
# OU: organizationalUnitName = optional 部门
# CN: commonName 　　　　 = supplied 给哪个域名颁发
# emailAddress 　　　　  = optional[ policy_anything ] 邮件地址

# CA证书别名
CA_ALIAS="ca"
# 证书别名
CERT_ALIAS=${ALIAS}

#PASSWORD="123456"

# 证书的truststore storepass密码和keypass密码
TRUST_PASSWORD=$PASSWORD
# 证书的keystore storepass密码和keypass密码
KEY_PASSWORD=$PASSWORD
# p12格式证书密码
P12_PASSWORD=$PASSWORD

# keystore文件名
KEY_STORE="${CN}/${CN}.keystore.jks"
#  truststore文件名
TRUST_STORE="${CN}/${CN}.truststore.jks"

# CA证书文件名（自签名）
CA_CERT_FILE="${CA_NAME}/ca.crt"
# 证书文件名
CERT_FILE="${CN}/${CN}.csr"
# 已签名证书文件名
CERT_SIGNED_FILE="${CN}/${CN}.crt"
# 已签名证书密钥文件名
CERT_SIGNED_KEY_FILE="${CN}/${CN}.key"
# p12证书文件名（包含私钥和公钥）
P12_CERT_FILE="${CN}/${CN}.p12"


echo "O=${O},OU=${OU},CN=${CN},EXT=${EXT},DAYS=${DAYS}"

mkdir -p "${CN}"

# 生成证书请求及私钥
if [[ ! -f "${CERT_SIGNED_KEY_FILE}" ]];then
  # openssl req -utf8 -nodes -newkey rsa:2048 -keyout "${CERT_SIGNED_KEY_FILE}" -new -days 36500 -out "${CERT_FILE}" -subj "/C=${C}/ST=${ST}/L=${L}/O=${O}/OU=${OU}/CN=${CN}/emailAddress=${emailAddress}"
  # 不想证书显示OU emailAddress 的话创建证书时就不加上这两个参数即可
  # openssl req -utf8 -nodes -newkey rsa:2048 -keyout "${CERT_SIGNED_KEY_FILE}" -new -days ${DAYS} -out "${CERT_FILE}" -subj "/C=${C}/ST=${ST}/O=${O}/CN=${CN}"
  # windows 系统下创建时 -subj后面的参数 / 需要转义
  # openssl req -utf8 -nodes -newkey rsa:2048 -keyout "${CERT_SIGNED_KEY_FILE}" -new -days ${DAYS} -out "${CERT_FILE}" -subj "//C=${C}\ST=${ST}\O=${O}\CN=${CN}"

  OS=`uname -s`
  if [[ ${OS} == "Darwin" || ${OS} == "Linux" ]];then
    openssl req -utf8 -nodes -newkey rsa:2048 -keyout "${CERT_SIGNED_KEY_FILE}" -new -days ${DAYS} -out "${CERT_FILE}" -subj "/C=${C}/ST=${ST}/O=${O}/CN=${CN}" -config openssl.cnf
  elif [[ ${OS} =~ "_NT" ]];then
    openssl req -utf8 -nodes -newkey rsa:2048 -keyout "${CERT_SIGNED_KEY_FILE}" -new -days ${DAYS} -out "${CERT_FILE}" -subj "//C=${C}\ST=${ST}\O=${O}\CN=${CN}" -config openssl.cnf
  fi
fi

# 生成签名证书
if [[ ! -f "${CERT_SIGNED_FILE}" ]];then
  if [[ -z ${EXT} ]];then
    openssl ca -utf8 -batch -days ${DAYS} -in "${CERT_FILE}" -out "${CERT_SIGNED_FILE}" -config openssl.cnf
  else
    openssl ca -utf8 -batch -days ${DAYS} -in "${CERT_FILE}" -out "${CERT_SIGNED_FILE}" -extfile ${EXT} -extensions ext -config openssl.cnf
  fi
fi

# 导出p12格式证书
if [[ ! -f "${P12_CERT_FILE}" ]];then
  openssl pkcs12 -export -clcerts -CApath ./${CA_NAME}/ -inkey "${CERT_SIGNED_KEY_FILE}" -in "${CERT_SIGNED_FILE}" -certfile "./${CA_CERT_FILE}" -passout pass:${P12_PASSWORD} -out "${P12_CERT_FILE}"
fi


# 将p12格式证书转换成java可用的 keystore及truststore证书

if [[ ! -f ${TRUST_STORE} ]];then
    # 导入ca证书，生成truststore  -noprompt 不提示，不需要确认 "是否信任此证书?"
    keytool -importcert -keystore ${TRUST_STORE} -storepass ${TRUST_PASSWORD} -alias ${CA_ALIAS} -keypass ${TRUST_PASSWORD} -file ${CA_CERT_FILE} -noprompt
    echo "导入CA证书至truststoree已完成"
fi

if [[ ! -f ${KEY_STORE} ]];then

    # 导入p12证书到keystore
    keytool -importkeystore -srckeystore ./${P12_CERT_FILE} -srcstoretype pkcs12 -srcstorepass ${P12_PASSWORD} -deststoretype pkcs12 -deststorepass ${KEY_PASSWORD} -destkeypass ${KEY_PASSWORD} -destkeystore ${KEY_STORE}
    echo "导入p12证书到keystore已完成"

    # 修改别名
    keytool -changealias -keystore ${KEY_STORE} -alias 1 -destalias ${CN} -deststorepass ${KEY_PASSWORD}
    echo "修改别名已完成"

    # 导入ca证书到keystore  -noprompt 不提示，不需要确认 "是否信任此证书?"
    keytool -importcert -keystore ${KEY_STORE} -storepass ${KEY_PASSWORD} -alias ${CA_ALIAS} -keypass ${KEY_PASSWORD} -file ${CA_CERT_FILE} -noprompt
    echo "导入CA证书到keystore已完成"
fi

# cat << EOF > ${CN}/${CN}-password.txt
cat > ${CN}/${CN}-password.txt << EOF

# ${TRUST_STORE} 证书的truststore storepass密码和keypass密码
TRUST_PASSWORD=$TRUST_PASSWORD

# ${KEY_STORE} 证书的keystore storepass密码和keypass密码
KEY_PASSWORD=$KEY_PASSWORD

# ${P12_CERT_FILE} # p12格式证书密码
P12_PASSWORD=$P12_PASSWORD

EOF
