# php-msf-docker

## 介绍
Dockerfile搭建的基于almalinux:8镜像的一套PHP开发环境：

* 工具包含：nginx，redis, [gocron](https://github.com/ouqiang/gocron), [supervisor](https://www.supervisord.org/), [protobuf](https://protobuf.dev/)
* php扩展：常用扩展及swoole, grpc, amqp, memcache, redis, protobuf
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
    -p 8000:8000 \
    -p 5920:5920 \
    -p 2222:22 \
    -v /Users/xxx/Docker/www:/php-msf/data/www \
    --name php-msf \
    leanku/php-msf-docker:almalinux-php8.2
    
# windows 挂载路径示例
-v D:\Develop\Docker\docker\new\php-msf-docker\www:/php-msf/data/www
```

### 验证服务：
* Nginx: http://localhost
* SSH: ssh super@localhost -p 2222（密码 123456）
* gocron: http://localhost:5920
* phpinfo(): http://127.0.0.1:8000/

服务管理：使用supervisor |start|stop|reload
如nginx重启：supervisorctl restart nginx

## 自定义
PHP扩展：install-php-extensions.sh中定义php扩展及版本
软件版本定义：.env