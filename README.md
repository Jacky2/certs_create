# nginx、kafka双向证书一键生成

## 1. 简介

此脚本为同时支持nginx及java keystore证书，并可支持泛域名。适用于kafka、nginx双向认证。证书默认有效期是365天。更改的话需要修改openssl.cnf配置文件及创建证书时的 --days 命令参数
**脚本需要有keytool、openssl两个命令支持，并且windows下 openssl 需要是1.1.1d版本不然可能会有莫名的问题**

## 2. 证书创建

### 2.1. 修改脚本配置

修改ca_cert_create.sh和client_cert_create.sh中的配置，如果openssl.cnf 配置里面配置了policy = policy_match 那签发的证书的countryName、stateOrProvinceName、organizationName 必须要匹配。
如果如果命令没有指定 -config openssl.cnf对应的配置文件，则读取默认路径/etc/pki/tls/openssl.cnf 配置, 如果配置为 policy = policy_anything 那就不需要配置。

match: 必须匹配
supplied: 需要提供
optional: 可选的

```ini
# C:国家,S:省、州
# 申请证书时，要填写的必要信息
# [ policy_match ]   注意：match必须匹配，客户端申请证书和CA颁发填写的信息必须相同
# C: countryName     　　　　= match国家
# S: stateOrProvinceName 　= match省、州
# O: organizationName 　　  = match组织、公司名
# OU: organizationalUnitName = optional 部门
# CN: commonName 　　　　 = supplied 给哪个域名颁发
# emailAddress 　　　　  = optional[ policy_anything ] 邮件地址
```

cat  openssl.cnf

```ini
policy      = policy_match

# For the CA policy
[ policy_match ]
countryName             = match
stateOrProvinceName     = match
organizationName        = match
organizationalUnitName  = optional
commonName              = supplied
emailAddress            = optional

[ policy_anything ]
countryName             = optional
stateOrProvinceName     = optional
localityName            = optional
organizationName        = optional
organizationalUnitName  = optional
commonName              = supplied
emailAddress            = optional

```

### 2.2. 创建ca证书

命令

```bash
./ca_cert_create.sh
```

### 2.3. 创建服务端证书

需要支持泛域名配置,需要增加一个文件名与域名（例如：example.com）一致的cnf文件（例如：example.com.cnf）
example.com.cnf 文件内容：

cat example.com.cnf

```ini
[ ext ]
subjectAltName = @dns

[ dns ]
DNS.1 = *.example.com
DNS.2 = example.com
DNS.3 = localhost
DNS.4 = 127.0.0.1
```

使用命令进行创建，修改yourpassword为需要设置的密码（注意：密码不能有特殊符号，如：#￥%&等特殊符号。）。其他配置可通过./client_cert_create.sh -h 查看帮助

```bash
./client_cert_create.sh --ou Tech --cn example.com --ext example.com.cnf --days 3650 --alias server --passwd yourpassword
```

### 2.4. 创建客户端（其他）证书 (如：某个部门)

因客户端证书不需要扩展配置文件则参数不需要配置--ext此项。（注意：密码不能有特殊符号，如：#￥%&等特殊符号。）

```bash
./client_cert_create.sh --ou Tech --cn guangzhou --days 3650 --alias client --passwd yourpassword
```

### 2.5. 吊销证书

```bash
revoke_cert.sh client/client.crt
```

然后复制吊销的证书CA/private/ca.crl到nginx更新吊销证书列表，并在nginx 配置中增加吊销证书配置

```conf
ssl_crl certs/ca.crl;  #启用吊销证书检查"
```

### 2.6. 生成证书--使用说明

```bash
注： 生成的服务端的一系列证书可供服务器端的nginx及kafka使用
例如：
nginx服务端可使用
签名证书：example.com.crt
证书key：example.com.key
CA证书：CA/cacert.pem
nginx双向认证时客户端导入证书文件：client.p12

kafka服务端使用 （与nginx使用同一泛证域名证书，只是转换成java可用的证书）
# keystore证书包含CA证书及签名及密钥
keystore证书：example.com.keystore.jks

# truststore证书仅包含CA证书，将CA证书添加到信任证书里
truststore证书：example.com.truststore.jks

kafka客户端证书
# keystore证书包含CA证书及签名及密钥
keystore证书：client.keystore.jks

# truststore证书仅包含CA证书，将CA证书添加到信任证书里
truststore证书：client.truststore.jks
```

### 2.7. 其他操作说明

```bash
# 服务端证书创建命令
# example for server: ./client_cert_create.sh --ou Tech --cn example.com  --email admin@example.com --ext example.com .cnf --days 3650 --alias server --passwd yourpassword_server

# 客户端证书创建命令
# example for client: ./client_cert_create.sh --ou Tech --cn client1 --email client1@example.com --days 3650 --alias client1 --passwd yourpassword_client

# 查看keystore证书

# keytool -list -keystore client1.keystore.jks -v -storepass 123456

# 查看keystore证书中证书rfc内容

# keytool -list -rfc -keystore client1.keystore.jks -v -storepass 123456

# 查看ca证书

# keytool -printcert -file kafkaca.cer

# 查看服务器证书

# keytool -printcert -file server.cer

# 查看客户端证书

# keytool -printcert -file client1.cer

# kafka验证：

#生产者发起消息

# ./bin/kafka-console-producer.sh --broker-list t-kafka.example.com:9093 --topic test --producer.config config/client-ssl.properties

# # 消息者接收消息

# ./bin/kafka-console-consumer.sh --bootstrap-server t-kafka.example.com:9093 --topic test --consumer.config config/client-ssl.properties
```
