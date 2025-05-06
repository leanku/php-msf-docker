#!/bin/bash

# 获取需要安装的扩展列表 ,查找扩展可以去：https://pecl.php.net/
PHP_DIR="$1"
EXTENSIONS="$2"

# 进入 PHP 源码目录（确保 PHP 已安装）
cd /tmp/php-${PHP_VERSION}/ext

# 创建目扩展和配置目录
mkdir -p ${PHP_DIR}/extensions
mkdir ${PHP_DIR}/etc/conf.d

# 验证扩展目录
if ! command -v /php-msf/php/bin/php-config --extension-dir &> /dev/null; then
   echo "ERROR: php-config not found." >&2
exit 1
fi

# 修改配置文件
EXT_DIR=$(/php-msf/php/bin/php-config --extension-dir)
echo "当前扩展目录: $EXT_DIR"
PHP_INI=$(/php-msf/php/bin/php --ini | grep "Loaded Configuration File" | awk '{print $4}')
echo "extension_dir = $EXT_DIR" | tee -a "$PHP_INI" > /dev/null


ext_redis() {
     # 编译安装 redis
    cd /tmp \
    && wget https://pecl.php.net/get/redis-6.2.0.tgz -O redis-6.2.0.tgz \
    && tar -zxvf redis-6.2.0.tgz \
    && cd redis-6.2.0 \
    && ${PHP_DIR}/bin/phpize \
    && ./configure --with-php-config=${PHP_DIR}/bin/php-config \
    && make -j$(nproc) && make install && \
    echo -e "extension=redis.so" > ${PHP_DIR}/etc/conf.d/redis.ini
}

ext_swoole() {
    # 编译安装 Swoole
    cd /tmp \
    && wget https://github.com/swoole/swoole-src/archive/master.tar.gz -O swoole.tar.gz \
    && tar -zxvf swoole.tar.gz \
    && cd swoole-src-master \
    && ${PHP_DIR}/bin/phpize \
    && ./configure --with-php-config=${PHP_DIR}/bin/php-config --enable-openssl --enable-mysqlnd --enable-sockets \
    && make -j$(nproc) && make install && \
    echo -e "extension=swoole.so\nswoole.use_shortname='Off'" > ${PHP_DIR}/etc/conf.d/swoole.ini
}

ext_grpc() {
    #使用devtoolset-10，原gcc版本太低
    yum install -y cmake3 glibc-devel libmpc \
    && wget https://vault.centos.org/7.9.2009/sclo/x86_64/rh/Packages/d/devtoolset-10-runtime-10.1-0.el7.x86_64.rpm \
    && wget https://vault.centos.org/7.9.2009/sclo/x86_64/rh/Packages/d/devtoolset-10-gcc-10.2.1-2.1.el7.x86_64.rpm \
    && wget https://vault.centos.org/7.9.2009/sclo/x86_64/rh/Packages/d/devtoolset-10-gcc-c++-10.2.1-2.1.el7.x86_64.rpm \
    && rpm -ivh devtoolset-10-*.rpm --nodeps && \
    source /opt/rh/devtoolset-10/enable && \
    git clone --recurse-submodules -b v1.55.0 --depth 1 https://github.com/grpc/grpc && \
    cd grpc && \
    mkdir -p cmake/build && \
    cd cmake/build && \
    ln -sf /opt/rh/devtoolset-10/root/usr/lib/gcc/x86_64-redhat-linux/10/32/libstdc++.a /usr/lib64/libstdc++_nonshared.a && \
    ln -sf /opt/rh/devtoolset-10/root/usr/lib/gcc/x86_64-redhat-linux/10/libstdc++.so /usr/lib64/libstdc++_nonshared.so && \
    ldconfig && \
    cmake3 ../.. \
    -DgRPC_INSTALL=ON \
    -DCMAKE_C_COMPILER=/opt/rh/devtoolset-10/root/usr/bin/gcc \
    -DCMAKE_CXX_COMPILER=/opt/rh/devtoolset-10/root/usr/bin/g++ \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_EXE_LINKER_FLAGS="-Wl,--no-keep-memory" \
    -DBUILD_SHARED_LIBS=ON \
    -DgRPC_SSL_PROVIDER=package \
    -DgRPC_ZLIB_PROVIDER=package \
    && make -j$(nproc) && make install \
    && cd ../../src/php/ext/grpc \
    && ${PHP_DIR}/bin/phpize \
    && ./configure --with-php-config=${PHP_DIR}/bin/php-config \
    && make -j$(nproc) && make install && \
    echo -e "extension=grpc.so" > ${PHP_DIR}/etc/conf.d/grpc.ini

    # pecl install grpc
    # 编译安装 gRPC 1.32.0版本为最后一个支持 GCC 4.8 的稳定版本，不强制依赖 Abseil 
    #cd /tmp \
    #&& yum install -y file devtoolset-10-gcc devtoolset-10-gcc-c++ && \
    #source /opt/rh/devtoolset-10/enable \
    #&& wget https://github.com/grpc/grpc/archive/refs/tags/v1.32.0.tar.gz -O grpc.tar.gz \
    #&& tar -zxvf grpc.tar.gz \
    #&& cd grpc-1.32.0 \
    #&& ${PHP_DIR}/bin/phpize \
    #&& ./configure --with-php-config=${PHP_DIR}/bin/php-config \
    #&& make -j$(nproc) && make install && \
    #echo "extension=grpc.so" > ${PHP_DIR}/etc/conf.d/grpc.ini
}

ext_amqp() {
    # 编译安装rabbitmq-c及 AMQP（RabbitMQ）
    yum install -y openssl-devel && \
    cd /tmp \
    && wget https://github.com/alanxz/rabbitmq-c/archive/refs/tags/v0.11.0.tar.gz -O rabbitmq-c.tar.gz \
    && tar -zxvf rabbitmq-c.tar.gz \
    && cd rabbitmq-c-0.11.0 \
    && mkdir build && cd build \
    && cmake -DCMAKE_INSTALL_PREFIX=/usr/local .. && \
    make && make install \
    && cd /tmp \
    && wget https://github.com/php-amqp/php-amqp/archive/master.tar.gz -O amqp.tar.gz \
    && tar -zxvf amqp.tar.gz \
    && cd php-amqp-latest \
    && ${PHP_DIR}/bin/phpize \
    && ./configure --with-php-config=${PHP_DIR}/bin/php-config \
    && make -j$(nproc) && make install && \
    echo "extension=amqp.so" > ${PHP_DIR}/etc/conf.d/amqp.ini
}

ext_memcached() {
    # 安装 memcached 扩展
    cd /tmp \
    && git clone --depth 1 https://github.com/php-memcached-dev/php-memcached \
    && cd php-memcached \
    && ${PHP_DIR}/bin/phpize \
    && ./configure --with-php-config=${PHP_DIR}/bin/php-config \
    && make -j$(nproc) && make install && \
    echo "extension=memcached.so" > ${PHP_DIR}/etc/conf.d/memcached.ini
}

# 主逻辑
# 遍历并编译每个扩展 如果新加扩展需要定义对应的ext_方法
for EXT in $EXTENSIONS; do
    echo "Installing PHP extension: $EXT"
    # 调用固定命名的函数 ext_$EXT，
    if declare -F "ext_$EXT" > /dev/null; then
        "ext_$EXT"
    else
        echo "Function ext_$EXT not found!" >&2
        exit 1
    fi
done
