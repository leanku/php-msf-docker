# 第一阶段：构建环境
FROM almalinux:8 AS builder

# 定义版本和目录
ARG PHP_VERSION=8.3
ARG NGINX_VERSION=1.25.4
ARG REDIS_VERSION=7.2.4
ARG GOCRON_VERSION=1.5.3
ENV INSTALL_DIR=/php-msf
ENV DATA_DIR=${INSTALL_DIR}/data
ENV WWW_DIR=${DATA_DIR}/www

# 安装编译工具和依赖
RUN dnf install -y cyrus-sasl-devel dnf-plugins-core epel-release \
    && dnf config-manager --set-enabled powertools \
    && dnf update -y \
    && dnf install -y wget unzip git gcc gcc-c++ make cmake autoconf libtool pkgconfig \
    openssl-devel zlib-devel curl-devel libxml2-devel libicu-devel libevent-devel tar bzip2 which \
    sqlite-devel systemd-devel ncurses-devel libffi-devel flex pcre-devel  \
    libjpeg-devel libpng-devel freetype-devel libwebp-devel libxslt-devel libzip-devel \
    bzip2-devel readline-devel libcurl-devel libmemcached bison \
    libmemcached-devel re2c oniguruma-devel libjpeg-turbo-devel abseil-cpp-devel automake \
    && dnf clean all

# 创建目录结构
RUN mkdir -p ${INSTALL_DIR}/{nginx,php,redis,gocron,protobuf} \
    && mkdir -p ${DATA_DIR}/{nginx/logs,php/logs,redis/logs,gocron/logs,supervisor/logs,sshd/logs,www} \
    && mkdir -p ${WWW_DIR} \
    && mkdir -p ${INSTALL_DIR}/SoftwarePackage/

# 不易下载的包可直接COPY
COPY ./package/ ${INSTALL_DIR}/SoftwarePackage/

# 安装 Nginx
RUN  cd /tmp \
    && wget https://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz \
    && tar -zxvf nginx-${NGINX_VERSION}.tar.gz \
    && cd nginx-${NGINX_VERSION} \
    && ./configure --prefix=${INSTALL_DIR}/nginx --with-http_ssl_module --with-http_v2_module \
    && make -j$(nproc) && make install \
    && rm -rf /tmp/nginx-*

# 验证安装
ENV PKG_CONFIG_PATH=/usr/local/lib64/pkgconfig:/usr/local/share/pkgconfig

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
        --with-libzip \
        --with-zlib \
        --with-curl \
        --with-mysqli \
        --with-pdo-mysql \
        --with-pear \
        --enable-mbstring \
        --with-libxml \
        --enable-soap \
        --enable-intl \
        --enable-gd \
        --with-jpeg \
        --with-webp \
        --with-freetype \
        --with-iconv \
        --with-gettext \
        --with-bz2 \
        --with-zip \
        --enable-mysqlnd \
        --enable-pcntl \
        --enable-bcmath \
        --enable-sockets \
        --enable-opcache \
        --enable-debug \
    && make -j$(nproc) && \
    make install \
    && cp php.ini-production ${INSTALL_DIR}/php/etc/php.ini \
    && echo "scan_dir = ${INSTALL_DIR}/php/etc/conf.d" >> ${INSTALL_DIR}/php/etc/php.ini

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

# 编译安装rabbitmq-c
RUN cd /tmp \
    && wget https://github.com/alanxz/rabbitmq-c/archive/refs/tags/v0.11.0.tar.gz -O rabbitmq-c.tar.gz \
    && tar -zxvf rabbitmq-c.tar.gz \
    && cd rabbitmq-c-0.11.0 \
    && mkdir build && cd build \
    && cmake -DCMAKE_INSTALL_PREFIX=/php-msf/rabbitmq-c .. && \
    make && make install && \
    export PKG_CONFIG_PATH=${INSTALL_DIR}/rabbitmq-c/lib/pkgconfig:$PKG_CONFIG_PATH \
    && export LD_LIBRARY_PATH=${INSTALL_DIR}/rabbitmq-c/lib:$LD_LIBRARY_PATH \
    && rm -rf /tmp/rabbitmq-c-*

# 编译安装libmemcached存在许多依赖问题，
# 先安装 dnf-plugins-core（提供 config-manager）， 启用 CRB（Common Repository Base）仓库 再安装libmemcached-devel

# 安装 Protocol Buffers (# 不需要Abseil的稳定版本)
ENV PROTOBUF_VERSION="3.21.12"
RUN cd ${INSTALL_DIR}/SoftwarePackage && \
    if [ ! -f "protobuf.tar.gz" ]; then \
        git clone -b v${PROTOBUF_VERSION} --depth 1 https://github.com/protocolbuffers/protobuf; \
    else \
        tar -zxvf protobuf.tar.gz; \
    fi \
    && cd protobuf && \
    ./autogen.sh && \
    ./configure --prefix=${INSTALL_DIR}/protobuf && \
    make -j$(nproc) && \
    make install && \
    echo "${INSTALL_DIR}/protobuf/lib" > /etc/ld.so.conf.d/protobuf.conf && \
    ldconfig

# 安装abseil
RUN cd ${INSTALL_DIR}/SoftwarePackage && \
    if [ ! -f "abseil-cpp.tar.gz" ]; then \
        git clone -b 20230802.1 https://github.com/abseil/abseil-cpp.git; \
    else \
        tar -zxvf abseil-cpp.tar.gz; \
    fi \
    && cd abseil-cpp \
    && mkdir build && cd build && \
    cmake .. -DCMAKE_INSTALL_PREFIX="${INSTALL_DIR}/abseil" -DCMAKE_POSITION_INDEPENDENT_CODE=ON -DCMAKE_CXX_STANDARD=17 && \
    make -j$(nproc) && make install && \
    export PKG_CONFIG_PATH="${INSTALL_DIR}/abseil/lib64/pkgconfig:${PKG_CONFIG_PATH}"

# 安装grpc
ENV GRPC_VERSION="1.46.7"
ENV PATH="${INSTALL_DIR}/protobuf/bin:${PATH}"
RUN cd ${INSTALL_DIR}/SoftwarePackage && \
    if [ ! -f "grpc.tar.gz" ]; then \
            git clone --recurse-submodules -b v${GRPC_VERSION} --depth 1 https://github.com/grpc/grpc; \
    else \
        tar -zxvf grpc.tar.gz; \
    fi \
    && cd grpc \
    && dnf remove -y abseil-cpp-devel && \
    git submodule update --init third_party/abseil-cpp third_party/cares && \
    mkdir -p build && cd build && \
    export PATH="${INSTALL_DIR}/protobuf/bin:${PATH}" && \
    export Protobuf_INCLUDE_DIR=/php-msf/protobuf/include && \
    export Protobuf_LIBRARY=/php-msf/protobuf/lib/libprotobuf.so && \
    cmake .. \
            -DCMAKE_INSTALL_PREFIX=${INSTALL_DIR}/grpc \
            -DgRPC_INSTALL=ON \
            -DgRPC_BUILD_TESTS=OFF \
            -DgRPC_PROTOBUF_PROVIDER=package \
            -DCMAKE_PREFIX_PATH="${INSTALL_DIR}/protobuf;${INSTALL_DIR}/abseil" \
            -DProtobuf_ROOT="${INSTALL_DIR}/protobuf" \
            -DProtobuf_INCLUDE_DIR="${INSTALL_DIR}/protobuf/include" \
            -DProtobuf_LIBRARY="${INSTALL_DIR}/protobuf/lib/libprotobuf.so" \
            -DProtobuf_PROTOC_EXECUTABLE="${INSTALL_DIR}/protobuf/bin/protoc" \
            -DgRPC_ABSL_PROVIDER=package \
            -Dabsl_DIR="${INSTALL_DIR}/abseil/lib64/cmake/absl" \
            -DCMAKE_LIBRARY_PATH="${INSTALL_DIR}/abseil/lib64" \
            -DgRPC_CARES_PROVIDER=module \
            -DgRPC_RE2_PROVIDER=module \
            -DgRPC_SSL_PROVIDER=package \
            -DgRPC_ZLIB_PROVIDER=package \
            -DCMAKE_BUILD_TYPE=Release \
            -DCMAKE_POLICY_DEFAULT_CMP0074=NEW \
            -DABSL_PROPAGATE_CXX_STD=ON \
            -DCMAKE_CXX_STANDARD=17 \
            -DABSL_ENABLE_INSTALL=ON \
            -DCMAKE_CXX_FLAGS="-DABSL_LEGACY_THREAD_ANNOTATIONS -DABSL_CONSUME_DLL" \
            -DCMAKE_C_FLAGS="-Dstrncmpi=strncasecmp" && \
    make -j$(nproc) && make install && \
    echo "${INSTALL_DIR}/grpc/lib" > /etc/ld.so.conf.d/grpc.conf && \
    ldconfig

# 设置环境变量rabbitmq-c:protobuf:grpc
ENV PKG_CONFIG_PATH="${INSTALL_DIR}/rabbitmq-c/lib/pkgconfig:${INSTALL_DIR}/protobuf/lib/pkgconfig:${INSTALL_DIR}/grpc/lib/pkgconfig:${INSTALL_DIR}/abseil/lib64/pkgconfig:${PKG_CONFIG_PATH}"
ENV LD_LIBRARY_PATH="${INSTALL_DIR}/rabbitmq-c/lib:${INSTALL_DIR}/protobuf/lib:${INSTALL_DIR}/grpc/lib:${INSTALL_DIR}/abseil/lib64:/usr/local/lib64:/usr/local/lib"

#RUN pkg-config --modversion grpc && \
#    pkg-config --modversion absl_base && exit 1
#RUN ls -a /php-msf/grpc &&  \
#    echo -e "\n ls grpc/lib==="  \
#    && ls -a /php-msf/grpc/lib  \
#    && echo -e "\n ls grpc/include/grpc===" \
#    && ls -a /php-msf/grpc/include/grpc \
#    && echo -e "\n ls grpc/lib/pkgconfig==="  \
#    && ls -a /php-msf/grpc/lib/pkgconfig && exit 1

# 安装 PHP 扩展（grpc protobuf swoole redis amqp memcached ...）
COPY ./install-php-extensions.sh /tmp/
RUN chmod +x /tmp/install-php-extensions.sh \
    && /tmp/install-php-extensions.sh "${INSTALL_DIR}/php" "grpc protobuf swoole redis amqp memcached" \
    && rm -rf /tmp/install-php-extensions.sh\
    && rm -rf ${INSTALL_DIR}/SoftwarePackage/*

# 第二阶段：运行环境
FROM almalinux:8

# 从 builder 复制已编译的软件
ENV INSTALL_DIR=/php-msf
ENV DATA_DIR=${INSTALL_DIR}/data
ENV WWW_DIR=${DATA_DIR}/www
COPY --from=builder ${INSTALL_DIR} ${INSTALL_DIR}
COPY --from=builder /etc/ssh /etc/ssh
COPY --from=builder /usr/local/lib64 /usr/local/lib64
# COPY --from=builder /home/super /home/super

WORKDIR /home
# 安装supervisor等运行依赖
RUN dnf install -y epel-release && \
    dnf install -y supervisor && \
    dnf install -y openssl pcre zlib libxml2 libzip \
    libjpeg libwebp libpng freetype libicu \
    libmemcached autoconf automake \
    sudo vim wget openssh-server git htop which glibc-langpack-zh \
    oniguruma --nogpgcheck \
    && dnf clean all

# 全局安装composer及加速
ENV PATH="${INSTALL_DIR}/php/bin:${PATH}"
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer && \
    composer config -g repo.packagist composer https://mirrors.aliyun.com/composer/

RUN echo 'export PATH="/php-msf/php/bin:/php-msf/nginx/sbin:/php-msf/redis/bin:/php-msf/protobuf/bin:/php-msf/grpc/bin:$PATH"' >> /etc/profile && \
    echo 'export PATH="/php-msf/php/bin:/php-msf/nginx/sbin:/php-msf/redis/bin:/php-msf/protobuf/bin:/php-msf/grpc/bin:$PATH"' >> /etc/bash.bashrc && \
    echo 'PermitUserEnvironment yes' >> /etc/ssh/sshd_config && \
    source /etc/profile

# 创建用户和权限
RUN groupadd super && \
    useradd -g super nginx && \
    echo "root:zV9eA8nI2eS5kA1h" | chpasswd && \
    useradd -m -s /bin/bash -g super super && \
    echo "super:123456" | chpasswd && \
    echo 'super  ALL=(ALL)  NOPASSWD: ALL' > /etc/sudoers && \
    chown -R super:super ${INSTALL_DIR}/ /var/run && \
    chown -R super:super ${INSTALL_DIR}/nginx/ && \
    usermod -aG wheel super && \
    chmod -R 775 ${INSTALL_DIR}

#配置super账号可远程SSH
RUN mkdir -p /home/super/.ssh && \
    chmod 700 /home/super/.ssh && \
    rm -f /etc/ssh/ssh_host_* \
    && ssh-keygen -A && \
    sed -i 's/#PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config && \
    sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config && \
    echo "AllowUsers root super" >> /etc/ssh/sshd_config

# 配置 Nginx（代理 PHP-FPM）
COPY ./config/nginx/conf.d/www.conf ${INSTALL_DIR}/nginx/conf/conf.d/www.conf
COPY ./config/nginx/conf/nginx.conf ${INSTALL_DIR}/nginx/conf/nginx.conf

# 配置 PHP-FPM
COPY ./config/php/php-fpm.conf ${INSTALL_DIR}/php/etc/php-fpm.conf
COPY ./config/php/www.conf ${INSTALL_DIR}/php/etc/php-fpm.d/www.conf
COPY www/index.php ${WWW_DIR}/

# 配置 Supervisor
RUN mkdir -p etc/supervisor/supervisord.d && \
touch /php-msf/data/supervisor/logs/supervisord.log \
&& ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
COPY ./config/supervisor/supervisord.conf /etc/supervisord.conf
COPY ./config/supervisor/supervisord.d/*.conf /etc/supervisor/supervisord.d/

COPY ./check_install.sh /home
COPY ./entrypoint.sh /home
COPY ./config/motd /etc/motd

# 暴露端口（Nginx:80, Redis:6379, SSH:22, gocron:5920）
EXPOSE 80 6379 22 5920 8000 9501

# 启动命令
#CMD ["/usr/bin/supervisord", "-n", "-c", "/etc/supervisord.conf"]
ENTRYPOINT ["/home/entrypoint.sh"]
CMD ["-D"]


