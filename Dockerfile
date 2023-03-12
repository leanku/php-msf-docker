FROM centos:centos7.9.2009
LABEL maintainer="Leanku<leanku@foxmail.com>"
ARG NGINX_VERSION=1.21.5
ARG PHP_VERSION=8.1.14
ARG GH_MIRROR_URL="https://kgithub.com"
ENV HOME /php-msf
ENV NGX_WWW_ROOT /php-msf/data/www
ENV NGX_LOG_ROOT /php-msf/data/wwwlogs
ENV TMP /tmp/php-msf/
ENV DEBIAN_FRONTEND=noninteractive
RUN mkdir -p /data/{wwwroot,wwwlogs,}

RUN set -eux \
    ; \
    yum -y install wget \
    # Change yum repos
    mv /etc/yum.repos.d/CentOS-Base.repo /etc/yum.repos.d/CentOS-Base.repo.backup ; \
    wget -O /etc/yum.repos.d/CentOS-Base.repo https://mirrors.aliyun.com/repo/Centos-7.repo ; \
    # yum install
    yum install -y cc gcc gcc-c++ zlib zlib-devel bzip2-devel openssl-devel ncurses-devel sqlite-devel tar gzip bzip2 ; \
    rpm -ivh https://dl.fedoraproject.org/pub/epel/7/x86_64/Packages/e/epel-release-7-14.noarch.rpm ; \
    yum install -y  libargon2 libargon2-devel libtool libtool-tldl libtool-ltdl-devel cmake3 ; \
    yum install -y \
    tar gzip bzip2 bzip2-devel zip unzip file perl-devel perl-ExtUtils-Embed perl-CPAN autoconf cmake librabbitmq-devel \
    libpng-devel libjpeg-devel freetype-devel libicu-devel oniguruma-deve libxslt-devel libzip-devel dnf oniguruma oniguruma-devel gd-devel postgresql-devel \
    zlib1g zlib1g-dev openssl libsqlite3-devel libxml2 libxml2-devel libcurl-devel libc-client-devel \
    libcurl3-gnutls libcurl4-gnutls-dev libcurl4-openssl-dev libpng-dev libjpeg8 libjpeg8-dev \
    libicu-devel libxslt1-devel libzip-devel libssl-devel libfreetype-devel libfreetype6 libpq-devel libpq5 libpcre3 libpcre3-devel libsodium-devel ; \
    ln -s /usr/lib64/libc-client.so /usr/lib/libc-client.so ; \
    yum -y install net-tools openssl openssh-server ; \
    yum install -y git python3 python3-devel vim curl supervisor ; \
    yum install -y nodejs && rpm -qa 'node|npm'
   

    
RUN set -eux \
    ; \
    mkdir -p "${TMP}" && cd "${TMP}" ; \
    #cmake3
    yum remove cmake -y ; \
    if [[ -n "${GH_MIRROR_URL}" ]] ; then \
      curl -Lk --retry 3 "${GH_MIRROR_URL}/Kitware/CMake/archive/refs/tags/v3.25.2.tar.gz" | gunzip | tar x ; \
    else \
      curl -Lk --retry 3 "https://github.com/Kitware/CMake/archive/refs/tags/v3.25.2.tar.gz" | gunzip | tar x ; \
    fi \
      ; \
    cd CMake* ; \
    ./bootstrap && make && make install ; \
    cd .. ; \
    # libzip
    yum remove libzip libzip-devel -y ; \
    if [[ -n "${GH_MIRROR_URL}" ]] ; then \
      curl -Lk --retry 3 "${GH_MIRROR_URL}/nih-at/libzip/archive/refs/tags/v1.9.2.tar.gz" | gunzip | tar x ; \
    else \
      curl -Lk --retry 3 "https://github.com/nih-at/libzip/archive/refs/tags/v1.9.2.tar.gz" | gunzip | tar x ; \
    fi \
      ; \
    cd libzip-1.9.2 ; \
    mkdir build && cd build ; \
    cmake -DCMAKE_INSTALL_PREFIX=/usr .. ; \
    make && make install ; \
    cd ../../ ; \
    #-----libsodium
    if [[ -n "${GH_MIRROR_URL}" ]] ; then \
      curl -Lk --retry 3 "${GH_MIRROR_URL}/jedisct1/libsodium/releases/download/1.0.18-RELEASE/libsodium-1.0.18.tar.gz" | gunzip | tar x ; \
    else \
      curl -Lk --retry 3 "https://github.com/jedisct1/jedisct1/libsodium/releases/download/1.0.18-RELEASE/libsodium-1.0.18.tar.gz" | gunzip | tar x ; \
    fi \
      ; \
    cd libsodium* ; \
    ./configure ; \
    make -j8 && make install ; \
    echo /usr/local/lib > /etc/ld.so.conf.d/usr_local_lib.conf ; \
    ldconfig ; \
    cd .. ; \
    #redis
    curl -Lk --retry 3 "https://download.redis.io/releases/redis-5.0.6.tar.gz" | gunzip | tar x ; \
    cd redis-5.0.6 ; \
    # mkdir -p /usr/local/redis/{etc,data,run,} ; \
    make && make install PREFIX=/usr/local/redis ; \
    cp ${TMP}/redis-5.0.6/redis.conf /usr/local/redis/bin/ ; \
    ln -s /usr/local/redis/bin/* /usr/local/bin/ ; \
    cd .. ; \
    # nginx
    curl -Lk --retry 3 "https://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz" | gunzip | tar x ; \
    cd "nginx-${NGINX_VERSION}" ; \
    ./configure --prefix=/usr/local/nginx \
          --user=super --group=super \
          --error-log-path="${NGX_LOG_ROOT}/nginx_error.log" \
          --http-log-path="${NGX_LOG_ROOT}/nginx_access.log" \
          --pid-path=/var/run/nginx.pid \
          --with-pcre \
          --with-http_ssl_module \
          --with-http_v2_module \
          --without-mail_pop3_module \
          --without-mail_imap_module \
          --with-http_gzip_static_module \
        ; \
    make && make install ; \
    ln -s /usr/local/nginx/sbin/* /usr/local/bin/ ; \
    ln -sf /usr/share/zoneinfo/Asia/Chongqing /etc/localtime ; \
    # useradd
    echo "root:RIRM7X1c" | chpasswd ; \
    ssh-keygen -t rsa -f /etc/ssh/ssh_host_rsa_key ; \
    ssh-keygen -t rsa -f /etc/ssh/ssh_host_ecdsa_key ; \
    ssh-keygen -t rsa -f /etc/ssh/ssh_host_ed25519_key ; \
    #useradd -r -s /sbin/nologin -d "${NGX_WWW_ROOT}" -m -k no super ; \
    useradd super ; \
    echo 'super:123456' |chpasswd ; \
    echo 'super  ALL=(ALL)  NOPASSWD: ALL' > /etc/sudoers ; \
    # ssh
    echo y | ssh-keygen -t rsa -f /etc/ssh/ssh_host_rsa_key -N '' ; \
    echo y | ssh-keygen -t dsa -f /etc/ssh/ssh_host_dsa_key -N '' ; \
    echo y | ssh-keygen -t ecdsa -f /etc/ssh/ssh_host_ecdsa_key -N '' ; \
    echo y | ssh-keygen -t ed25519 -f /etc/ssh/ssh_host_ed25519_key -N '' ; \
    sed -ri '/#Port 22/cPort 22' /etc/ssh/sshd_config ; \
    sed -ri '/#ListenAddress 0.0.0.0/cListenAddress 0.0.0.0' /etc/ssh/sshd_config ; \
    sed -ri '/#UseDNS yes/cUseDNS no' /etc/ssh/sshd_config ; \
    echo "RSAAuthentication yes" >> /etc/ssh/sshd_config ; \
    echo "PubkeyAuthentication yes" >> /etc/ssh/sshd_config ; \
    echo "AllowUsers root super" >> /etc/ssh/sshd_config ; \
    cd .. ; \
    # rabbitmq-c
    if [[ -n "${GH_MIRROR_URL}" ]] ; then \
      curl -Lk --retry 3 "${GH_MIRROR_URL}/alanxz/rabbitmq-c/archive/refs/tags/v0.11.0.tar.gz" | gunzip | tar x ; \
    else \
      curl -Lk --retry 3 "https://github.com/alanxz/rabbitmq-c/archive/refs/tags/v0.11.0.tar.gz" | gunzip | tar x ; \
    fi \
      ; \
    cd rabbitmq-c-0.11.0 ; \
    mkdir build && cd build ; \
    cmake -DCMAKE_INSTALL_PREFIX=/usr/local/rabbitmq-c-0.11.0  ..  ; \
    cmake --build .  --target install ; \
    cd ../../ ; \
    # php
    if [[ -n "${GH_MIRROR_URL}" ]] ; then \
      curl -Lk --retry 3 "https://mirror.nju.edu.cn/php/php-${PHP_VERSION}.tar.gz" | gunzip | tar x ; \
    else \
      curl -Lk --retry 3 "https://php.net/distributions/php-${PHP_VERSION}.tar.gz" | gunzip | tar x ; \
    fi \
      ; \
    cd "php-${PHP_VERSION}" ; \
      export PKG_CONFIG_PATH=/usr/local/lib/pkgconfig/ ; \
      ./configure --prefix=/usr/local/php/ \
          --with-config-file-path=/usr/local/php/etc/ \
          --with-config-file-scan-dir=/usr/local/php/etc/php.d/ \
          --with-fpm-user=super \
          --with-fpm-group=super \
          --with-mysqli=mysqlnd \
          --with-pdo-mysql=mysqlnd \
          --with-pgsql \
          --with-pdo-pgsql \
          --with-zip=/usr/local \
          --with-sodium \
          --with-openssl \
          --with-iconv \
          --with-zlib \
          --with-gettext \
          --with-curl \
          --with-freetype \
          --with-jpeg \
          --with-mhash \
          --with-xsl \
          --with-password-argon2 \
          --enable-fpm \
          --enable-xml \
          --enable-shmop \
          --enable-sysvsem \
          --enable-mbregex \
          --enable-mbstring \
          --enable-ftp \
          --enable-mysqlnd \
          --enable-pcntl \
          --enable-sockets \
          --enable-soap \
          --enable-session \
          --enable-bcmath \
          --enable-exif \
          --enable-intl \
          --enable-fileinfo \
          --enable-gd \
          --enable-ipv6 \
          --enable-opcache \
          --enable-rpath \
          --enable-debug \
          --with-pear=DIR \
        ; \
      make && make install ; \
      mkdir /usr/local/php/etc/php.d/ ; \
      cp php.ini-development /usr/local/php/etc/php.ini ; \
      cp /usr/local/php/etc/php-fpm.conf.default /usr/local/php/etc/php-fpm.conf ; \
      cp /usr/local/php/etc/php-fpm.d/www.conf.default /usr/local/php/etc/php-fpm.d/www.conf ; \
      ln -s /usr/local/php/bin/* /bin/ ; \
      ln -s /usr/local/php/sbin/* /bin/ ; \
    cd .. ; \
    # composer
    curl -L -O "https://mirrors.aliyun.com/composer/composer.phar" ; \
    mv composer.phar /usr/local/bin/composer ; \
    chmod +x /usr/local/bin/composer ; \
    EXTENSION_DIR=$(php-config --extension-dir) ; \
    # redis extension
    curl -Lk --retry 3 "https://pecl.php.net/get/redis-5.3.7.tgz" | gunzip | tar x ; \
    cd redis-5.3.7 ; \
    phpize ; \
    ./configure --with-php-config=/usr/local/php/bin/php-config ; \
    make && make install ; \
      if [[ -f "${EXTENSION_DIR}/redis.so" ]]; then \
        touch /usr/local/php/etc/php.d/redis.ini ; \
        echo 'extension=redis.so' > /usr/local/php/etc/php.d/redis.ini ; \
      fi ; \
    cd .. ; \
    # swoole extension
    if [[ -n "${GH_MIRROR_URL}" ]] ; then \
      curl -Lk --retry 3 "${GH_MIRROR_URL}/swoole/swoole-src/archive/v4.8.6.tar.gz" | gunzip | tar x ; \
    else \
      curl -Lk --retry 3 "https://github.com/swoole/swoole-src/archive/v4.8.6.tar.gz" | gunzip | tar x ; \
    fi \
      ; \
    cd swoole-src-4.8.6 ; \
    phpize ; \
    ./configure --with-php-config=/usr/local/php/bin/php-config --enable-openssl --enable-mysqlnd --enable-sockets ; \
    make && make install ; \
    if [[ -f "${EXTENSION_DIR}/swoole.so" ]]; then \
      touch /usr/local/php/etc/php.d/swoole.ini ; \
      echo 'extension=swoole.so' > /usr/local/php/etc/php.d/swoole.ini ; \
    fi ; \
    cd .. ; \
    # php-amqp extension
    # if [[ -n "${GH_MIRROR_URL}" ]] ; then \
      # curl -Lk --retry 3 "${GH_MIRROR_URL}/php-amqp/php-amqp/archive/refs/tags/v1.11.0.tar.gz" | gunzip | tar x ; \
      curl -Lk --retry 3 "https://pecl.php.net/get/amqp-1.10.2.tgz" | gunzip | tar x ; \
    # else \
      # curl -Lk --retry 3 "https://github.com/php-amqp/php-amqp/archive/refs/tags/v1.11.0.tar.gz" | gunzip | tar x ; \
    # fi \
      # ; \
    cd amqp-1.10.2 ; \
    phpize ; \
    ./configure --with-php-config=/usr/local/php/bin/php-config --with-amqp --with-librabbitmq-dir=/usr/local/rabbitmq-c-0.11.0 ; \
    make && make install ; \
    if [[ -f "${EXTENSION_DIR}/amqp.so" ]]; then \
      touch /usr/local/php/etc/php.d/amqp.ini ; \
      echo 'extension=amqp.so' > /usr/local/php/etc/php.d/amqp.ini ; \
    fi ; \
    cd / ; \
    \rm -rf "${TMP}" ;


WORKDIR /home
EXPOSE 22 80 443 6379 8080 8000 9501
COPY nginx.conf /usr/local/nginx/conf/
COPY conf.d /usr/local/nginx/conf/conf.d/
COPY www "${NGX_WWW_ROOT}"
COPY supervisord/supervisord.conf /etc/supervisord.conf
COPY supervisord/conf.d /etc/supervisord.d
COPY entrypoint.sh /home
COPY motd /etc/motd
RUN yum clean all ; \
    chown -R super:super "${NGX_WWW_ROOT}" ; \
    mkdir -p /var/log/supervisor ; \
    touch /var/log/supervisor/supervisord.log ; \
    touch /var/run/supervisor.sock ; \
    chmod 777 /run ; \
    chmod 777 /var/log ; \
    chmod 777 /var/log/supervisor/supervisord.log ; \
    chmod 777 /var/run/supervisor.sock ; \
    chown -R super:super /usr/local/nginx ; \
    chown -R super:super /php-msf/data ; \
    chown -R super:super /usr/local/php ; \
    chmod 777 /usr/local/nginx ; \
    chown -R super:super /usr/local/redis ; \
    chown -R super:super  /var/log/supervisor ; \
    chown -R super:super  /var/run ; \
    chmod 777 /var/run ; \
    chown -R super:super /usr/sbin/sshd ; \
    chmod 777 /usr/sbin/sshd ; \
    mkdir /var/run/sshd ; \
    chown -R super:super  /var/run/supervisor ; \
    chmod +x /home/entrypoint.sh
ENTRYPOINT ["/home/entrypoint.sh"]
CMD ["-D"]