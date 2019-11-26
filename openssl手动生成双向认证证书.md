# openssl手动生成双向认证证书

**注意以下几点**
1.注意将其中的私钥加密密码（-passout参数）修改成自己的密码；下边都是以带-passout参数生成私钥，如果使用-nodes参数，则最后一步"将加密的RSA密钥转成未加密的RSA密钥"不需要执行。

( 另：-passout pass: 是指输出证书时需要输入的密码, -passin pass: 是指输入证书时需要输入的密码。参数一般都是跟在证书后面即可。)

2.证书和密钥给出了直接一步生成和分步生成两种形式，两种形式是等价的，这里使用直接生成形式（分步生成形式被注释）

3.如果命令没有指定 -config openssl.cnf对应的配置文件，则读取默认路径/etc/pki/tls/openssl.cnf 配置, 里面配置了policy = policy_match 那签发的证书的countryName、stateOrProvinceName、organizationName 必须要匹配，如果配置为 policy = policy_anything 那就不需要配置。

match: 必须匹配
supplied: 需要提供
optional: 可选的

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

4.注意将其中的证书信息改成自己的组织信息的。其中证数各参数含义如下：

C-----国家（Country Name）
ST----省份（State or Province Name）
L----城市（Locality Name）
O----公司（Organization Name）
OU----部门（Organizational Unit Name）
CN----产品名（common Name）
emailAddress----邮箱（Email Address）

**subj参数例子**
SUBJ="/C=CN/ST=Guangdong/L=Guangzhou/O=Example/OU=IT/CN=Example Root CA/emailAddress=it@Example.com.cn"

## 1. CA证书及密钥生成

### 1.1. 方法一 (直接生成CA密钥及其自签名证书)

如果想以后读取私钥文件ca_rsa_private.pem时不需要输入密码，亦即不对私钥进行加密存储，那么将-passout pass:123456替换成-nodes

```bash
openssl req -newkey rsa:2048 -passout pass:123456 -keyout ca.key -x509 -days 365 -out ca.crt -subj "/C=CN/O=Example/OU=Root CA/CN=Example Root CA"
```

### 1.2. 方法二 (分步生成CA密钥及其自签名证书)

```bash
openssl genrsa -aes256 -passout pass:123456 -out ca.key 2048
openssl req -new -x509 -days 365 -key ca.key -passin pass:123456 -out ca.crt -subj "/C=CN/O=Example/OU=Root CA/CN=Example Root CA"
```

## 2. 服务器证书及密钥生成

### 2.1. 生成服务器密钥及待签名证书

#### 2.1.1. 方法一: (一步生成)

如果想以后读取私钥文件example.com.key时不需要输入密码，亦即不对私钥进行加密存储，那么将-passout pass:123456替换成-nodes

```bash
openssl req -utf8 -newkey rsa:2048 -passout pass:123456 -keyout example.com.key -out example.com.csr -subj "/C=CN/ST=Guangdong/L=Guangzhou/O=Example/OU=IT/CN=*.example.com"
```

#### 2.1.2. 方法二: (分步生成)

```bash
openssl genrsa -aes256 -passout pass:123456 -out example.com.key 2048
openssl req -utf8 -new -key example.com.key -passin pass:123456 -out example.com.csr -subj "/C=CN/ST=Guangdong/L=Guangzhou/O=Example/OU=IT/CN=*.example.com"
```

### 2.2. 使用CA证书及密钥对服务器证书进行签名

```bash
openssl x509 -req -days 365 -in example.com.csr -CA ca.crt -CAkey ca.key -passin pass:123456 -CAcreateserial -out example.com.crt -extfile example.com.ini -extensions ext
```

### 2.3. 将加密的RSA密钥转成未加密的RSA密钥，避免每次读取都要求输入解密密码

密码就是生成私钥文件时设置的passout、读取私钥文件时要输入的passin，比如example.com.key这个key的密码为123456这里要输入 pass:123456

```bash
openssl rsa -in example.com.key -out example.com_nopass.key -passin pass:123456
```

## 3. 客户端证书及密钥生成 (其实和服务端证书生产方式一样)

### 3.1. 生成客户端密钥及待签名证书

#### 3.1.1. 方法一 (一步生成)

如果想以后读取私钥文件client-01.key时不需要输入密码，亦即不对私钥进行加密存储，那么将-passout pass:client替换成-nodes

```bash
openssl req -newkey rsa:2048 -passout pass:client -keyout client-01.key -out client-01.csr -subj "/C=CN/ST=Guangdong/L=Guangzhou/O=Example/OU=IT/CN=CLIENT-01"
```

#### 3.1.2. 方法二 (分步生成)

```bash
openssl genrsa -aes256 -passout pass:client -out client-01.key 2048
openssl req -new -key client-01.key -passin pass:client -out client-01.csr -subj "/C=CN/ST=Guangdong/L=Guangzhou/O=Example/OU=IT/CN=CLIENT-01"
```

### 3.2. 使用CA证书及密钥对客户端证书进行签名：

openssl x509 -req -days 365 -in client-01.csr -CA ca.crt -CAkey ca.key -passin pass:123456 -CAcreateserial -out client-01.crt

### 3.3. 将加密的RSA密钥转成未加密的RSA密钥，避免每次读取都要求输入解密密码

密码就是生成私钥文件时设置的passout、读取私钥文件时要输入的passin，比如这里要输入"client"
openssl rsa -in client-01.key -out client-01-nopass.key

### 导出p12格式客户端证书，用于客户使用

```bash
# openssl pkcs12 -export -clcerts -CApath ./${CA_PATH}/ -inkey "${CERT_SIGNED_KEY_FILE}" -in "${CERT_SIGNED_FILE}" -certfile "./${CA_CERT_FILE}" -passout pass:${P12_PASSWORD} -out "${P12_CERT_FILE}"

openssl pkcs12 -export -clcerts -CApath ./ -inkey client-01.key -passin pass:client -in client-01.crt -certfile ./ca.crt  -passout pass:123456 -out client-01.p12
```

## 4. 吊销一个签证过的证书

```bash
export CA_NAME="CA"
openssl ca -config openssl.cnf -revoke "${1}/${1}.crt"
openssl ca -config openssl.cnf -gencrl -out "./${CA_NAME}/private/ca.crl"
# 查看吊销证书crl文件：
openssl crl -in "./${CA_NAME}/private/ca.crl" -noout -text
```

然后在nginx 配置中增加吊销证书配置

```conf
ssl_crl certs/ca.crl;  #启用吊销证书检查"
```
