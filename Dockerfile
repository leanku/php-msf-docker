# 第一阶段：构建环境
FROM alpine:3.23 AS builder

# 定义版本和目录
ARG PHP_VERSION=8.3.29
ARG NGINX_VERSION=1.25.4
ARG REDIS_VERSION=7.2.4
ARG PROTOC_VERSION=3.20.1
ENV INSTALL_DIR=/php-msf \
    DATA_DIR=/php-msf/data \
    WWW_DIR=/php-msf/data/www

# 创建目录结构（合并为一条命令）
RUN mkdir -p \
    ${INSTALL_DIR}/nginx \
    ${INSTALL_DIR}/php \
    ${INSTALL_DIR}/redis \
    ${INSTALL_DIR}/protobuf \
    ${DATA_DIR}/nginx/logs \
    ${DATA_DIR}/php/logs \
    ${DATA_DIR}/redis/logs \
    ${DATA_DIR}/supervisor/logs \
    ${DATA_DIR}/sshd/logs \
    ${WWW_DIR} \
    ${INSTALL_DIR}/SoftwarePackage

# 安装编译工具和依赖
RUN apk add --no-cache \
    # 基础工具
    wget curl unzip git \
    # 编译工具链
    gcc g++ make autoconf automake libtool cmake \
    # PHP 核心依赖
    libxml2-dev libxslt-dev sqlite-dev oniguruma-dev \
    # 图像处理
    libjpeg-turbo-dev libpng-dev libwebp-dev freetype-dev \
    # 压缩和加密
    libzip-dev bzip2-dev openssl-dev zlib-dev \
    # 网络和协议
    curl-dev libmemcached-dev rabbitmq-c-dev \
    # 国际化
    gettext-dev icu-dev \
    # 其他
    readline-dev linux-headers libc-dev

# 复制本地源码包（如果存在）
# COPY ./package/* ${INSTALL_DIR}/SoftwarePackage/

# 安装 Nginx
RUN cd /tmp && \
    # 下载 PCRE 源码
    wget https://sourceforge.net/projects/pcre/files/pcre/8.45/pcre-8.45.tar.gz && \
    tar -zxvf pcre-8.45.tar.gz && \
    # 下载 Nginx 源码
    wget https://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz && \
    tar -zxvf nginx-${NGINX_VERSION}.tar.gz && \
    cd nginx-${NGINX_VERSION} && \
    # 配置编译
    ./configure --prefix=${INSTALL_DIR}/nginx \
        --with-http_ssl_module \
        --with-http_v2_module \
        --with-http_stub_status_module \
        --with-http_realip_module \
        --with-http_gzip_static_module \
        --with-pcre=/tmp/pcre-8.45 \
        --with-pcre-jit \
        --with-stream \
        --with-stream_ssl_module \
        --with-http_sub_module && \
    # 移除 -Werror（使用临时文件方式）
    sed 's/-Werror//g' objs/Makefile > objs/Makefile.tmp && \
    mv objs/Makefile.tmp objs/Makefile && \
    # 编译安装
    make -j$(nproc) && make install && \
    # 验证
    ${INSTALL_DIR}/nginx/sbin/nginx -v && \
    # 清理
    rm -rf /tmp/nginx-* /tmp/pcre-* && \
    adduser -D -H -s /sbin/nologin -G www-data -u 82 nginx 2>/dev/null || true

# 安装 Redis
RUN cd /tmp && \
    wget https://download.redis.io/releases/redis-${REDIS_VERSION}.tar.gz && \
    tar -zxvf redis-${REDIS_VERSION}.tar.gz && \
    cd redis-${REDIS_VERSION} && \
    make -j$(nproc) MALLOC=libc && \
    make PREFIX=${INSTALL_DIR}/redis install && \
    mkdir -p ${INSTALL_DIR}/redis/conf && \
    cp redis.conf ${INSTALL_DIR}/redis/conf/ && \
    rm -rf /tmp/redis-*

# 安装 Protocol Buffers
RUN cd /tmp && \
    wget https://github.com/protocolbuffers/protobuf/releases/download/v${PROTOC_VERSION}/protobuf-cpp-${PROTOC_VERSION}.tar.gz && \
    tar -zxvf protobuf-cpp-${PROTOC_VERSION}.tar.gz && \
    cd protobuf-${PROTOC_VERSION} && \
    ./configure --prefix=${INSTALL_DIR}/protobuf --disable-shared --enable-static && \
    make -j$(nproc) && make install && \
    mkdir -p /etc/ld.so.conf.d && \
    echo "${INSTALL_DIR}/protobuf/lib" >> /etc/ld.so.conf.d/protobuf.conf && \
    ldconfig && \
    ln -sf ${INSTALL_DIR}/protobuf/bin/protoc /usr/local/bin/protoc && \
    rm -rf /tmp/protobuf-*

# 设置环境变量（供后续编译使用）
ENV PKG_CONFIG_PATH=${INSTALL_DIR}/protobuf/lib/pkgconfig:/usr/lib/pkgconfig \
    PATH=${INSTALL_DIR}/protobuf/bin:$PATH

# 安装 PHP
RUN cd /tmp && \
    wget https://www.php.net/distributions/php-${PHP_VERSION}.tar.gz && \
    tar -zxvf php-${PHP_VERSION}.tar.gz && \
    cd php-${PHP_VERSION} && \
    export PKG_CONFIG_PATH="/usr/lib/pkgconfig:${INSTALL_DIR}/protobuf/lib/pkgconfig:${PKG_CONFIG_PATH}" && \
    ./configure --prefix=${INSTALL_DIR}/php \
        --with-config-file-path=${INSTALL_DIR}/php/etc \
        --with-config-file-scan-dir=${INSTALL_DIR}/php/etc/conf.d \
        --with-extension-dir=${INSTALL_DIR}/php/extensions \
        --enable-fpm --with-fpm-user=nginx --with-fpm-group=nginx \
        --with-openssl --with-openssl-dir=/usr --with-curl --with-zlib \
        --with-mysqli --with-pdo-mysql --with-pdo-sqlite \
        --enable-gd --with-jpeg --with-webp --with-freetype \
        --with-iconv --with-gettext --with-bz2 --with-zip --with-libzip=/usr \
        --enable-mysqlnd --enable-pcntl --enable-sockets --enable-opcache \
        --enable-debug --disable-short-tags --enable-bcmath --enable-calendar \
        --enable-exif --enable-ftp --enable-intl --enable-mbstring \
        --enable-soap --enable-xml --with-libxml --with-xmlrpc --with-pcre-jit && \
    make -j$(nproc) && make install && \
    cp php.ini-production ${INSTALL_DIR}/php/etc/php.ini && \
    mkdir -p ${INSTALL_DIR}/php/etc/conf.d ${INSTALL_DIR}/php/var/{run,log} && \
    rm -rf /tmp/php-*

# 设置 PHP 环境变量
ENV PATH=${INSTALL_DIR}/php/bin:${INSTALL_DIR}/php/sbin:$PATH \
    PHP_INI_SCAN_DIR=${INSTALL_DIR}/php/etc/conf.d

# 安装 PHP 扩展
COPY ./install-php-extensions.sh /tmp/
RUN chmod +x /tmp/install-php-extensions.sh && \
    /tmp/install-php-extensions.sh "${INSTALL_DIR}/php" && \
    rm -rf /tmp/install-php-extensions.sh ${INSTALL_DIR}/SoftwarePackage/*

# 第二阶段：运行环境
FROM alpine:3.23

# 定义环境变量
ENV INSTALL_DIR=/php-msf \
    DATA_DIR=/php-msf/data \
    WWW_DIR=/php-msf/data/www \
    PATH=/php-msf/php/bin:/php-msf/php/sbin:/php-msf/nginx/sbin:/php-msf/redis/bin:/php-msf/protobuf/bin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
    LD_LIBRARY_PATH=/php-msf/protobuf/lib:/usr/local/lib \
    PHP_INI_SCAN_DIR=/php-msf/php/etc/conf.d \
    TZ=Asia/Shanghai

WORKDIR /home

# 从 builder 复制编译好的软件
COPY --from=builder ${INSTALL_DIR} ${INSTALL_DIR}
COPY --from=builder /etc/ld.so.conf.d/protobuf.conf /etc/ld.so.conf.d/

# 安装运行时依赖（使用国内镜像源）
RUN sed -i 's/dl-cdn.alpinelinux.org/mirrors.aliyun.com/g' /etc/apk/repositories && \
    apk update && apk add --no-cache \
        supervisor openssh-server sudo vim wget curl git htop tzdata bash shadow \
        openssl pcre zlib libxml2 libzip libjpeg-turbo libwebp libpng freetype \
        icu libmemcached oniguruma imagemagick rabbitmq-c procps musl-locales musl-locales-lang && \
    ln -sf /usr/share/zoneinfo/${TZ} /etc/localtime && echo "${TZ}" > /etc/timezone && \
    rm -rf /var/cache/apk/*

# 安装 Composer
RUN curl -sS https://getcomposer.org/installer | php -- --quiet --install-dir=/usr/local/bin --filename=composer && \
    composer config -g repo.packagist composer https://mirrors.aliyun.com/composer/ --quiet

# 配置环境变量
RUN echo "export PATH=${PATH}" > /etc/profile.d/php-msf.sh && \
    echo "export LD_LIBRARY_PATH=${LD_LIBRARY_PATH}" >> /etc/profile.d/php-msf.sh && \
    echo "export PHP_INI_SCAN_DIR=${PHP_INI_SCAN_DIR}" >> /etc/profile.d/php-msf.sh && \
    chmod +x /etc/profile.d/php-msf.sh

# 创建用户和组
RUN set -ex && \
    # 创建组
    addgroup -g 82 www-data 2>/dev/null || true && \
    addgroup -g 1000 super 2>/dev/null || true && \
    # 创建用户
    adduser -D -H -s /sbin/nologin -G www-data -u 83 nginx 2>/dev/null || true && \
    adduser -D -h /home/super -s /bin/bash -G super -u 1000 super 2>/dev/null || true && \
    # 设置密码和 sudo
    echo "super:123456" | chpasswd && \
    echo "super ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/super && \
    chmod 440 /etc/sudoers.d/super && \
    # 配置 SSH
    mkdir -p /home/super/.ssh && \
    chmod 700 /home/super/.ssh && \
    chown super:super /home/super/.ssh && \
    ssh-keygen -A && \
    sed -i 's/#PermitRootLogin yes/PermitRootLogin no/; s/#PasswordAuthentication yes/PasswordAuthentication yes/; s/#PermitUserEnvironment no/PermitUserEnvironment yes/' /etc/ssh/sshd_config && \
    echo "AllowUsers root super" >> /etc/ssh/sshd_config && \
    mkdir -p /var/run/sshd && \
    # 创建必要目录
    mkdir -p ${INSTALL_DIR}/nginx/conf/conf.d \
             ${INSTALL_DIR}/nginx/conf \
             ${INSTALL_DIR}/php/etc/php-fpm.d \
             ${DATA_DIR}/supervisor/logs \
             /etc/supervisor/conf.d \
             /var/run/php-fpm \
             /var/lock/subsys \
             /var/log/supervisor

# 复制配置文件
COPY ./config/nginx/conf.d/www.conf ${INSTALL_DIR}/nginx/conf/conf.d/
COPY ./config/nginx/conf/nginx.conf ${INSTALL_DIR}/nginx/conf/
COPY ./config/php/php-fpm.conf ${INSTALL_DIR}/php/etc/
COPY ./config/php/www.conf ${INSTALL_DIR}/php/etc/php-fpm.d/
COPY ./config/supervisor/supervisord.conf /etc/
COPY ./config/supervisor/supervisord.d/*.conf /etc/supervisor/conf.d/
COPY ./config/motd /etc/motd
COPY ./www/index.php ${WWW_DIR}/
COPY ./entrypoint.sh /home/

# 设置权限和运行环境
RUN chown -R super:super ${INSTALL_DIR} /var/run && \
    chown -R nginx:www-data ${INSTALL_DIR}/nginx ${INSTALL_DIR}/php/var && \
    chmod -R 755 ${INSTALL_DIR} && \
    chmod +x /home/entrypoint.sh && \
    # supervisor 相关权限
    touch ${DATA_DIR}/supervisor/logs/supervisord.log && \
    chown -R super:super ${DATA_DIR}/supervisor && \
    # Nginx 权限
    chown -R nginx:www-data ${INSTALL_DIR}/nginx && chmod -R 755 ${INSTALL_DIR}/nginx && \
    # PHP-FPM 权限
    mkdir -p ${INSTALL_DIR}/php/var/run ${INSTALL_DIR}/php/var/log && \
    chown -R nginx:www-data ${INSTALL_DIR}/php/var && chmod -R 755 ${INSTALL_DIR}/php/var && \
    mkdir -p /php-msf/data/php/logs && \
    chown -R nginx:www-data /php-msf/data/php && chmod -R 755 /php-msf/data/php && \
    # SSH 权限
    chmod 600 /home/super/.ssh 2>/dev/null || true && \
    # 删除调试符号（减小体积）
    find ${INSTALL_DIR} -type f -name "*.so" -exec strip --strip-debug {} \; 2>/dev/null || true && \
    find ${INSTALL_DIR}/php/bin ${INSTALL_DIR}/php/sbin ${INSTALL_DIR}/nginx/sbin ${INSTALL_DIR}/redis/bin -type f -exec strip --strip-all {} \; 2>/dev/null || true && \
    # 更新库缓存
    ldconfig 2>/dev/null || true

# 验证关键组件
RUN ${INSTALL_DIR}/php/bin/php -v | head -1 && \
    ${INSTALL_DIR}/nginx/sbin/nginx -v 2>&1 | head -1 && \
    ${INSTALL_DIR}/redis/bin/redis-server --version | head -1 || true

# 暴露端口
EXPOSE 80 6379 22 8000 9000 9501 9502

# 启动命令
ENTRYPOINT ["/home/entrypoint.sh"]
CMD ["-D"]