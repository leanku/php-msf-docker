# PHP MSF Docker 开发环境

基于 Alpine Linux 的 PHP 开发镜像，内置 Nginx、PHP-FPM、Redis、Node.js、Composer 与 Supervisor。镜像采用多阶段构建，默认提供精简运行环境；需要交互调试工具时可构建 `dev` 目标。

## 组件版本

| 组件 | 版本/说明 |
| --- | --- |
| Alpine Linux | 3.23 |
| PHP | 8.5.10（PHP-FPM） |
| Nginx | 1.30.4 |
| Redis Server | 7.4.11，启用 TLS 编译 |
| Node.js / npm | 由 Alpine 3.23 仓库提供 |
| Composer | 构建时安装的 Composer 最新稳定版 |

## 快速开始

```sh
git switch alpine-php8.5
cp .env.example .env
./build.sh build
./build.sh test
```

构建后启动容器：

```sh
docker run --rm -it \
  --name php-msf \
  --env-file .env \
  -p 8000:8000 \
  -p 6379:6379 \
  -p 2222:22 \
  -v "$(pwd)/www:/php-msf/data/www" \
  -v php-msf-redis:/php-msf/data/redis \
  -v php-msf-logs:/php-msf/data \
  php-msf:alpine-php8.5
```

浏览器访问 `http://localhost:8000`。应用目录为 `/php-msf/data/www`。默认会输出phpinfo页。

完整命令:

```bash 
docker run -d \
  --name php-msf-8.5 \
  --restart unless-stopped \
  --env-file .env \
  -p 8000:8000 \
  -p 6379:6379 \
  -p 16379:16379 \
  -p 9000:9000 \
  -p 2222:22 \
  -v "$(pwd)/www:/php-msf/data/www" \
  -v php-msf-redis:/php-msf/data/redis \
  -v php-msf-logs:/php-msf/data \
  php-msf:alpine-php8.5
```

## 构建与发布

复制环境变量模板后，按实际镜像仓库修改 `.env`：

```sh
cp .env.example .env
```

| 命令 | 用途 |
| --- | --- |
| `./build.sh build` | 构建运行镜像 |
| `./build.sh test` | 验证 PHP 扩展、Nginx、Redis、Node.js 与 npm |
| `./build.sh tag` | 为本地镜像打仓库标签，需要设置 `REGISTRY_IMAGE` |
| `./build.sh push` | 构建并推送镜像，需要预先完成 `docker login` 并设置 `REGISTRY_IMAGE` |

默认镜像为 `php-msf:alpine-php8.5`。如需多平台构建，可在 `.env` 中设置：

```dotenv
PLATFORM=linux/amd64
```

若构建需要重新下载和编译全部组件：

```sh
docker build --no-cache --target runtime -t php-msf:alpine-php8.5 .
```

### 开发镜像

运行镜像不包含 Vim、Git、Wget、Htop 和 Procps。需要它们时构建开发目标：

```sh
BUILD_TARGET=dev ./build.sh build
```

## PHP 扩展与配置

内置 PHP 核心能力包括：

- 图像：GD（JPEG、WebP、FreeType）、Imagick、Exif。
- 数据与国际化：MySQLi、PDO MySQL、PDO SQLite、Intl、Mbstring、XML、XSL、SOAP、Zip、Bzip2。
- 加密与网络：OpenSSL、Sodium、cURL、Sockets、PCNTL、FTP。
- 性能：OPcache、APCu、igbinary、Redis、Memcached。
- 消息与 RPC：AMQP、Protobuf、Swoole。

gRPC 扩展的源码编译耗时较长，当前不随默认镜像启用。如需要，可在 `install-php-extensions.sh` 的 `EXTENSIONS` 列表中加入 `grpc` 后重新构建。

PHP 配置文件位置：

| 配置 | 容器内路径 | 仓库路径 |
| --- | --- | --- |
| 主配置 | `/php-msf/php/etc/php.ini` | PHP 官方 production 模板 |
| 基础与安全配置 | `/php-msf/php/etc/conf.d/00-base.ini` | `config/php/conf.d/00-base.ini` |
| OPcache 配置 | `/php-msf/php/etc/conf.d/10-opcache.ini` | `config/php/conf.d/10-opcache.ini` |
| PHP-FPM | `/php-msf/php/etc/php-fpm.conf` | `config/php/php-fpm.conf` |

## Redis

默认启动单 Redis 实例，数据写入 `/php-msf/data/redis`，已启用 AOF（每秒刷盘）和 RDB 快照。

### 单实例密码

在 `.env` 中设置密码后，将同时配置 `requirepass` 与 `masterauth`：

```dotenv
REDIS_PASSWORD=replace-with-a-strong-password
```

密码不得包含空白字符或双引号。

### Redis Cluster 节点模式

镜像支持作为 Redis Cluster 的单个节点运行；每个节点需要独立容器、独立数据卷、彼此可访问的地址，以及外部执行集群创建命令。

为每个节点的环境变量设置：

```dotenv
REDIS_CLUSTER_ENABLED=true
REDIS_CLUSTER_PORT=6379
REDIS_CLUSTER_BUS_PORT=16379
REDIS_CLUSTER_ANNOUNCE_IP=10.0.0.11
REDIS_CLUSTER_ANNOUNCE_PORT=6379
REDIS_CLUSTER_ANNOUNCE_BUS_PORT=16379
```

启动集群节点时需暴露数据端口和集群总线端口：

```sh
docker run --rm -d \
  --name redis-node-1 \
  --env-file .env \
  -p 6379:6379 \
  -p 16379:16379 \
  -v redis-node-1:/php-msf/data/redis \
  php-msf:alpine-php8.5
```

在所有节点启动后，从任一节点创建集群。以下示例为三主三从，地址必须替换为实际可互通地址：

```sh
docker exec -it redis-node-1 redis-cli \
  --cluster create \
  10.0.0.11:6379 10.0.0.12:6379 10.0.0.13:6379 \
  10.0.0.21:6379 10.0.0.22:6379 10.0.0.23:6379 \
  --cluster-replicas 1
```

> Docker Desktop、Kubernetes 或跨主机网络环境中，`REDIS_CLUSTER_ANNOUNCE_IP` 必须是集群节点实际可以相互访问的地址，不能盲目使用 `localhost`。

## 端口与目录

| 用途 | 端口/路径 |
| --- | --- |
| Nginx HTTP | `8000` |
| PHP-FPM | `9000` |
| Redis | `6379` |
| Redis Cluster Bus | `16379` |
| SSH | `22` |
| 网站根目录 | `/php-msf/data/www` |
| PHP 日志 | `/php-msf/data/php/logs` |
| Nginx 日志 | `/php-msf/data/nginx/logs` |
| Redis 数据和日志 | `/php-msf/data/redis`、`/php-msf/data/redis/logs` |

## 进程管理

入口脚本启动 SSH 服务后由 Supervisor 管理以下进程：

- Nginx
- PHP-FPM
- Redis

查看进程状态：

```sh
docker exec -it php-msf supervisorctl status
```

## 安全说明

- 本项目定位为开发环境。Redis 默认绑定全部网络接口，生产部署必须设置 `REDIS_PASSWORD`，并通过安全组、网络策略或反向代理限制访问来源。
- 不要将实际密码写入 `.env.example` 或提交 `.env`；`.env` 已由 Git 忽略且已从 Docker 构建上下文排除。
- 镜像支持SSH 与 `super`：```123456``` 用户行为。生产部署前应禁用不需要的 SSH 服务，并替换默认账户凭据。
- 建议将应用源码、Redis 数据和日志挂载到持久化卷，避免容器重建造成数据丢失。

## 常见构建问题

| 现象 | 处理方式 |
| --- | --- |
| 旧层仍使用不兼容扩展 | 使用 `docker build --no-cache ...` 重新构建 |
| Redis 扩展找不到 `php_smart_string.h` | 确认构建日志使用 `redis-6.3.0`，而不是旧版 6.2.0 |
| AMQP 编译的 Zend API 参数错误 | 确认构建日志使用 `amqp-2.2.0` |
| gRPC 编译耗时过长 | 默认未启用；按需加入扩展列表后单独构建 |

## 其他问题
- Laravel目录权限问题为例
```
ls -ld /proc/9
chown -R nginx:www-data storage bootstrap/cache
chmod -R 775 storage bootstrap/cache
```
