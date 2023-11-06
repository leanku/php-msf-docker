# php-msf-docker
基于dockerhub官方镜像[centos:centos7.9.2009](https://hub.docker.com/layers/library/centos/centos7.9.2009/images/sha256-dead07b4d8ed7e29e98de0f4504d87e8880d4347859d839686a31da35a3b532f?context=explore)制作的php开发环境镜像

参考 [jetsung / docker-nginx-php](https://github.com/jetsung/docker-nginx-php) 修改而来

### Docker Hub   
**php-msf-docker:** [https://hub.docker.com/r/leanku/php-msf-docker](https://hub.docker.com/r/leanku/php-msf-docker)   
   
[English](./README_EN.md) | 简体中文

---
## 镜像内容

---
latest
---
* PHP-8.1.14
* composer
* redis-5.3.7
* swoole-src-5.0.2
* nginx-1.21.5
* supervisor
* node

### 包含扩展：
```bash
amqp apcu bcmath Core ctype curl date dom exif fileinfo filter ftp gd gettext hash iconv inotify intl json libxml mbstring memcached mongodb mysqli mysqlnd openssl pcntl pcre PDO pdo_mysql pdo_pgsql pdo_sqlite pgsql Phar posix redis Reflection session shmop SimpleXML soap sockets sodium SPL sqlite3 standard swoole sysvsem tokenizer xml xmlreader xmlwriter xsl yaml zip zlib
``` 

### Build
```bash
# 方式一
git clone https://github.com/leanku/php-msf-docker.git

cd php-msf-docker

docker build --build-arg PHP_VERSION="8.1.14" \
  --build-arg NGINX_VERSION="1.21.5" \
  -t leanku/php-msf-docker:8.1 \
  .
# 简化为 docker build -t leanku/php-msf-docker:latest .

# 方式二
  ./build.sh leanku env
```
---

### 默认启动
```
docker pull leanku/php-msf-docker

docker run -it -d -p 2202:22 -p 80:80 -p 8000:8000 -p 9501:9501 \
lenaku/php-msf-docker
```
------

### SSH  

默认用户：super   密码：123456

------

### Windows 运行示例
```
docker run --privileged --restart=always -it -d --hostname=php-msf  --name=php-msf-docker -p 2202:22 -p 80:80 -p 8000:8000 -p 9501:9501 -v  D:\Develop\Docker\WWW:/php-msf/data/www leanku/php-msf-docker
```
------

### mac运行示例
```
docker run --privileged --restart=always -it -d --hostname=php-msf  --name=php-msf-docker -p 2202:22 -p 80:80 -p 8000:8000 -p 9501:9501 -v /Users/username/Docker/www:/php-msf/data/www lenaku/php-msf
```

------

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

---

### 定制扩展
```
docker run -it -d -p 2202:22 -p 80:80 -p 3306:3306 -p 8000:8000 -p 9501:9501 \
-v $(pwd)/wwwroot:/php-msf/data/www \
-v $(pwd)/wwwlogs:/php-msf/data/wwwlogs \
-v $(pwd)/extension.sh:/home/extension.sh \
leanku/php-msf-docker
```

> swoole为例：创建文件 ```extension.sh``` (不可更改文件名)，内容为 [swoole](extensions/swoole.sh)   


<br>

### 如有不足，请指正...

### 常用的image
```
#rabbitmq
docker run -d --name rabbitmq -e RABBITMQ_DEFAULT_USER=guest -e RABBITMQ_DEFAULT_PASS=guest -p 15672:15672 -p 5672:5672 rabbitmq:3.8-management

#MySQL
docker run -p 13306:3306 --name mysql5.7 -e MYSQL_ROOT_PASSWORD=root -v D:\Develop\Docker\app-mysql:/var/lib/mysql -d mysql:5.7

#elasticsearch
docker run -d --name es -p 9200:9200 -p 9300:9300 -e "discovery.type=single-node" elasticsearch:latest

#redis
docker run --name redis -p 6379:6379 -d redis redis-server --appendonly yes
```
