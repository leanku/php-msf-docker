# php-msf-docker
基于dockerhub官方镜像[centos:centos7.9.2009](https://hub.docker.com/layers/library/centos/centos7.9.2009/images/sha256-dead07b4d8ed7e29e98de0f4504d87e8880d4347859d839686a31da35a3b532f?context=explore)制作的php开发环境镜像

参考 [jetsung / docker-nginx-php](https://github.com/jetsung/docker-nginx-php) 修改而来

### Docker Hub   
**php-msf-docker:** [https://hub.docker.com/r/leanku/php-msf-docker](https://hub.docker.com/r/leanku/php-msf-docker)   
   
[English](./README_EN.md) | 简体中文

### 包含扩展
```bash
bcmath,Core,ctype,curl,date,dom,exif,fileinfo,filter,ftp,gd,gettext,hash,iconv,intl,json,libxml,mbstring,mysqli,mysqlnd,openssl,pcntl,pcre,PDO,pdo_mysql,pdo_pgsql,pdo_sqlite,pgsql,Phar,posix,redis,Reflection,session,shmop,SimpleXML,soap,sockets,sodium,SPL,sqlite3,standard,sysvsem,tokenizer,xml,xmlreader,xmlwriter,xsl,zip,zlib
``` 

### 命令行工具
使用 `docker exec {CONTAINER ID} {COMMAND}` 

```bash
# 查看当前进程
docker exec {CONTAINER ID} ps -ef
# 查看当前 PHP 版本
docker exec {CONTAINER ID} php --version

# supervisord
## 帮助
docker exec {CONTAINER ID} supervisorctl --help
## 停止、启动、状态 (stop/start/status)
docker exec {CONTAINER ID} supervisorctl stop all
## 停止 NGINX / PHP
docker exec {CONTAINER ID} supervisorctl stop nginx/php-fpm

# 未启动容器
## 查看 PHP 版本
docker run --rm -it leanku/php-msf-docker:latest php --version

## 查看 NGINX 版本
docker run --rm -itleanku/php-msf-docker:latest nginx -v
```

### 默认启动
```
docker run -it -d -p 2202:22 -p 80:80 -p 3306:3306 -p 8000:8000 -p 9501:9501 \
leanku/php-msf-docker
```

------

### 自定义网站目录
```
docker run --privileged --restart=always -it -d --hostname=php-msf  --name=php-msf-docker -p 2202:22 -p 80:80 -p 3306:3306 -p 8000:8000 -p 9501:9501 -v /Users/lixiaokang/Docker/www:/php-msf/data/www lenaku/php-msf:0.0.1
```

------

### 绑定域名 和 使用 ```SSL``` 证书，让网站支持 ```HTTPS```
```
docker run -d -p 38082:80 \
-p 38083:443 \
-v $(pwd)/wwwroot:/data/wwwroot \
-v $(pwd)/wwwlogs:/data/wwwlogs \
-v $(pwd)/vhost:/usr/local/nginx/conf/vhost \
-v $(pwd)/ssl:/usr/local/nginx/conf/ssl \
leanku/php-msf-docker
```       

------

### 定制扩展
```
docker run -it -d -p 2202:22 -p 80:80 -p 3306:3306 -p 8000:8000 -p 9501:9501 \
-v $(pwd)/wwwroot:/php-msf/data/www \
-v $(pwd)/wwwlogs:/php-msf/data/wwwlogs \
-v $(pwd)/extension.sh:/home/extension.sh \
leanku/php-msf-docker
```

> swoole为例：创建文件 ```extension.sh``` (不可更改文件名)，内容为 [swoole](extensions/swoole.sh)   
