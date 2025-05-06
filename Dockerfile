# 第一阶段：构建环境
FROM centos:7 AS builder

# 定义版本和目录
ARG PHP_VERSION=8.3
ARG NGINX_VERSION=1.25.4
ARG REDIS_VERSION=7.2.4
ARG GOCRON_VERSION=1.5.3
ENV INSTALL_DIR=/php-msf
ENV DATA_DIR=${INSTALL_DIR}/data
ENV WWW_DIR=${DATA_DIR}/www

# 安装编译工具和依赖
RUN sed -i 's/mirrorlist/#mirrorlist/g' /etc/yum.repos.d/CentOS-*.repo \
    && sed -i 's|#baseurl=http://mirror.centos.org|baseurl=https://mirrors.aliyun.com|g' \
    /etc/yum.repos.d/CentOS-*.repo \
    && yum install -y epel-release \
    && yum install -y wget unzip git gcc gcc-c++ make autoconf openssl-devel pcre-devel zlib-devel \
       libxml2-devel libjpeg-devel libpng-devel libwebp-devel freetype-devel \
       bzip2-devel readline-devel libxslt-devel sqlite-devel oniguruma-devel cmake cmake3 \
       librabbitmq-devel libmemcached-devel \
       libcurl-devel \
       grpc-devel grpc-plugins \
    && yum clean all
    # && rm -rf /var/cache/yum

# 创建目录结构
RUN mkdir -p ${INSTALL_DIR}/{nginx,php,redis,gocron,protobuf} \
    && mkdir -p ${DATA_DIR}/{nginx/logs,php/logs,redis/logs,gocron/logs,supervisor/logs,sshd/logs,www} \
    && mkdir -p ${WWW_DIR} \
    && mkdir -p ${INSTALL_DIR}/pkg

COPY ./package/ ${INSTALL_DIR}/pkg/

# 安装 Nginx
RUN  cd /tmp \
    && wget https://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz \
    && tar -zxvf nginx-${NGINX_VERSION}.tar.gz \
    && cd nginx-${NGINX_VERSION} \
    && ./configure --prefix=${INSTALL_DIR}/nginx --with-http_ssl_module --with-http_v2_module \
    && make -j$(nproc) && make install \
    && rm -rf /tmp/nginx-*

# 下载并编译 libzip 1.9.2（兼容 PHP 8 的版本，# 注意libzip >= 0.11）
RUN set -e; \
    cd /tmp; \
    if [ -f "${INSTALL_DIR}/pkg/libzip-1.9.2.tar.gz" ]; then \
        echo "使用本地 libzip 源码包..."; \
        cp ${INSTALL_DIR}/pkg/libzip-1.9.2.tar.gz .; \
    else \
        echo "本地未找到源码包，从网络下载..."; \
        yum install -y openssl11 && \
        wget --secure-protocol=TLSv1_2 https://libzip.org/download/libzip-1.9.2.tar.gz || \
        (echo "下载失败，请检查网络或提前将源码包放入 ./package/ 目录"; exit 1); \
    fi; \
    tar -zxvf libzip-1.9.2.tar.gz && \
    cd libzip-1.9.2 && \
    mkdir build && cd build && \
    cmake3 -DCMAKE_INSTALL_PREFIX=/usr/local -DENABLE_PKGCONFIG=ON .. && \
    make -j$(nproc) && make install && \
    echo "/usr/local/lib64" >> /etc/ld.so.conf && \
    ldconfig && \
    rm -rf /tmp/libzip-1.9.2*

# 设置环境变量让 PHP 能找到 libzip
ENV PKG_CONFIG_PATH=/usr/local/lib64/pkgconfig:/usr/local/share/pkgconfig
# 验证安装
RUN pkg-config --exists libzip && \
    pkg-config --modversion libzip

# 升级cmake
RUN wget https://github.com/Kitware/CMake/releases/download/v3.22.1/cmake-3.22.1-linux-x86_64.tar.gz && \
    tar -xzf cmake-3.22.1-linux-x86_64.tar.gz \
    && mv cmake-3.22.1-linux-x86_64 ${INSTALL_DIR}/cmake \
    && export PATH=${INSTALL_DIR}/cmake/bin:$PATH

# 安装 PHP
RUN cd /tmp \
    && wget https://www.php.net/distributions/php-${PHP_VERSION}.tar.gz \
    && tar -zxvf php-${PHP_VERSION}.tar.gz \
    && cd php-${PHP_VERSION} \
    && ./configure --prefix=${INSTALL_DIR}/php/ \
        --with-config-file-path=${INSTALL_DIR}/php/etc \
        --with-config-file-scan-dir=${INSTALL_DIR}/php/etc/conf.d \
        --with-extension-dir=${INSTALL_DIR}/php/extensions \
        --enable-fpm \
        --with-fpm-user=nginx \
        --with-fpm-group=nginx \
        --with-openssl \
        #显式指定 libzip 路径
        --with-libzip=/usr/local/lib64 \
        --with-zlib \
        --with-curl \
        --with-mysqli \
        --with-pdo-mysql \
        #新版改用如下 --with-gd \
        --enable-gd \
        --with-jpeg \
        --with-webp \
        --with-freetype \
        # 移除 --with-xmlrpc \
        --with-iconv \
        --with-gettext \
        --with-bz2 \
        --with-zip \
        --enable-mysqlnd \
        --enable-pcntl \
        --enable-sockets \
        --enable-opcache \
        --enable-debug \
        --with-pear \
    && make -j$(nproc) && \
    make install \
    && cp php.ini-production ${INSTALL_DIR}/php/etc/php.ini
    # && echo "scan_dir = ${INSTALL_DIR}/php/etc/conf.d" >> ${INSTALL_DIR}/php/etc/php.ini
    # && rm -rf /tmp/php-*

# 安装 Redis
RUN cd /tmp \
    && wget https://download.redis.io/releases/redis-${REDIS_VERSION}.tar.gz \
    && tar -zxvf redis-${REDIS_VERSION}.tar.gz \
    && cd redis-${REDIS_VERSION} \
    && make -j$(nproc) && make PREFIX=${INSTALL_DIR}/redis install \
    && rm -rf /tmp/redis-*

# 安装 gocron
RUN cd /tmp \
    && wget https://github.com/ouqiang/gocron/releases/download/v${GOCRON_VERSION}/gocron-v${GOCRON_VERSION}-linux-amd64.tar.gz -O gocron.tar.gz \
    && tar -zxvf gocron.tar.gz \
    && cd gocron-linux-amd64 \
    && mv gocron ${INSTALL_DIR}/gocron/ \
    && chmod +x ${INSTALL_DIR}/gocron/gocron \
    && rm -rf /tmp/gocron-*

# 安装protoc
RUN cd /tmp \
    && curl -LO https://github.com/protocolbuffers/protobuf/releases/download/v3.20.1/protoc-3.20.1-linux-x86_64.zip && \
    unzip protoc-3.20.1-linux-x86_64.zip -d -d ${INSTALL_DIR}/protobuf && \
    rm -rf /tmp/protoc-*

# 安装 PHP 扩展（memcached、swoole、amqp、grpc）
COPY ./install-php-extensions.sh /tmp/
RUN chmod +x /tmp/install-php-extensions.sh \
    && /tmp/install-php-extensions.sh "${INSTALL_DIR}/php" "grpc swoole redis amqp memcached" \
    && rm -f /tmp/install-php-extensions.sh

# 配置 SSH（用户 super，密码 123456）
#RUN useradd super \
#    && echo "123456" | passwd super --stdin \
#    && mkdir -p /home/super/.ssh \
#    && chmod 700 /home/super/.ssh \
#    && ssh-keygen -A \
#    && sed -i 's/#PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config \
#    && sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config

# 第二阶段：运行环境
FROM centos:7

# 从 builder 复制已编译的软件
ENV INSTALL_DIR=/php-msf
ENV DATA_DIR=${INSTALL_DIR}/data
ENV WWW_DIR=${DATA_DIR}/www
COPY --from=builder ${INSTALL_DIR} ${INSTALL_DIR}
COPY --from=builder /etc/ssh /etc/ssh
COPY --from=builder /usr/local/lib64 /usr/local/lib64
# COPY --from=builder /home/super /home/super

# 安装supervisor等运行依赖
RUN sed -i 's/mirrorlist/#mirrorlist/g' /etc/yum.repos.d/CentOS-*.repo \
    && sed -i 's|#baseurl=http://mirror.centos.org|baseurl=https://mirrors.aliyun.com|g' \
    /etc/yum.repos.d/CentOS-*.repo && \
    yum install -y epel-release && \
    yum install -y supervisor && \
    yum install -y openssl pcre zlib libxml2 \
    libjpeg libwebp libpng freetype \
    libmemcached grpc-plugins autoconf \
    sudo vim wget openssh-server git htop \
    oniguruma --nogpgcheck \
    && yum clean all \
    && rm -rf /var/cache/yum

# 全局安装composer及加速
ENV PATH="${INSTALL_DIR}/php/bin:${PATH}"
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer && \
    composer config -g repo.packagist composer https://mirrors.aliyun.com/composer/

RUN echo 'export PATH="${INSTALL_DIR}/php/bin:{INSTALL_DIR}/protobuf/bin:${INSTALL_DIR}/cmake-4.0.0/bin:$PATH"' >> /etc/profile && \
    echo 'export PATH="${INSTALL_DIR}/php/bin:{INSTALL_DIR}/protobuf/bin:${INSTALL_DIR}/cmake-4.0.0/bin:$PATH"' >> /etc/bash.bashrc && \
    echo 'PermitUserEnvironment yes' >> /etc/ssh/sshd_config && \
    source /etc/profile

# 创建用户和权限
RUN groupadd super && \
    useradd -g super nginx && \
    useradd -m -s /bin/bash -g super super && \
    echo "super:123456" | chpasswd && \
    chown -R super:super ${INSTALL_DIR} /var/run && \
    usermod -aG wheel super && \
    chmod 775 ${INSTALL_DIR}

#配置super账号可远程SSH
RUN mkdir -p /home/super/.ssh && \
    chmod 700 /home/super/.ssh && \
    rm -f /etc/ssh/ssh_host_* \
    && ssh-keygen -A && \
    sed -i 's/#PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config && \
    sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config

# 配置 Nginx（代理 PHP-FPM）
COPY ./config/nginx/conf.d/www.conf ${INSTALL_DIR}/nginx/conf/conf.d/www.conf
COPY ./config/nginx/conf/nginx.conf ${INSTALL_DIR}/nginx/conf/nginx.conf

# 配置 PHP-FPM
COPY ./config/php/php-fpm.conf ${INSTALL_DIR}/php/etc/php-fpm.conf
COPY ./config/php/www.conf ${INSTALL_DIR}/php/etc/php-fpm.d/www.conf
COPY ./index.php ${WWW_DIR}/

# 配置 Supervisor
RUN mkdir -p etc/supervisor/supervisord.d && \
touch php-msf/data/supervisor/logs/supervisord.log \
&& ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
COPY ./config/supervisor/supervisord.conf /etc/supervisord.conf
COPY ./config/supervisor/supervisord.d/*.conf /etc/supervisor/supervisord.d/
COPY ./config/motd /etc/motd

# 暴露端口（Nginx:80, Redis:6379, SSH:22, gocron:5920）
EXPOSE 80 6379 22 5920 8000 9501

# 启动命令
CMD ["/usr/bin/supervisord", "-n", "-c", "/etc/supervisord.conf"]