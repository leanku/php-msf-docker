# php-msf-docker

## 介绍
Dockerfile搭建的一套PHP开发环境：

* 工具包含：nginx，redis, [gocron](https://github.com/ouqiang/gocron), [supervisor](https://www.supervisord.org/), [protobuf](https://protobuf.dev/)
* php扩展：常用扩展及swoole, grpc, amqp, memcache
* 软件目录：/php-msf
* 日志目录：/php-msf/data
* 项目目录：/php-msf/data/www

## 使用
### 构建镜像
方式一：dockerfile构建镜像
``` bash
docker build -t leanku/php-msf-docker:latest .
```

方式二：执行shell构建镜像
```
chmod +x build.sh && ./build.sh
```
### 运行容器:
``` bash
docker run -it \
    -p 80:80 \
    -p 6379:6379 \
    -p 5920:5920 \
    -p 2222:22 \
    -v /Users/lixiaokang/Docker/www:/php-msf/data/www \
    --name php-msf \
    leanku/php-msf-docker:php8.2
```

### 验证服务：
* Nginx: http://localhost
* SSH: ssh super@localhost -p 2222（密码 123456）
* gocron: http://localhost:5920

服务管理：使用supervisor |start|stop|reload
如nginx重启：supervisorctl restart nginx

## 自定义
PHP扩展：install-php-extensions.sh中定义安装其他扩展
软件版本定义：.env
项目目录：/php-msf/data/www