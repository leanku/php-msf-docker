#!/bin/bash

# 获取需要安装的扩展列表 ,查找扩展可以去：https://pecl.php.net/
PHP_DIR="$1"
EXTENSIONS="$2"

# 进入 PHP 源码目录（确保 PHP 已安装）
cd /tmp/php-${PHP_VERSION}/ext

# 创建目扩展和配置目录
mkdir -p ${PHP_DIR}/extensions
mkdir -p ${PHP_DIR}/etc/conf.d

# 验证扩展目录
if ! command -v /php-msf/php/bin/php-config --extension-dir &> /dev/null; then
   echo "ERROR: php-config not found." >&2
exit 1
fi

# 修改配置文件
EXT_DIR=$(/php-msf/php/bin/php-config --extension-dir)
echo -e "\n=== PHP扩展目录: $EXT_DIR ==="
echo -e "\n=== 准备安装的PHP扩展: $EXTENSIONS ==="
PHP_INI=$(/php-msf/php/bin/php --ini | grep "Loaded Configuration File" | awk '{print $4}')
echo "extension_dir = $EXT_DIR" | tee -a "$PHP_INI" > /dev/null


ext_redis() {
     # 编译安装 redis
    cd /tmp \
    && wget https://pecl.php.net/get/redis-6.2.0.tgz -O redis-6.2.0.tgz \
    && tar -zxvf redis-6.2.0.tgz \
    && cd redis-6.2.0 \
    && ${PHP_DIR}/bin/phpize && \
    ./configure --with-php-config=${PHP_DIR}/bin/php-config && \
    make -j$(nproc) && make install && \
    echo -e "extension=redis.so" > ${PHP_DIR}/etc/conf.d/redis.ini \
    && rm -rf /tmp/redis-*
}

ext_swoole() {
    # 编译安装 Swoole, 如果是php7需要指定5以下
    cd /tmp \
    && wget https://github.com/swoole/swoole-src/archive/master.tar.gz -O swoole.tar.gz \
    && tar -zxvf swoole.tar.gz \
    && cd swoole-src-master \
    && ${PHP_DIR}/bin/phpize && \
    ./configure --with-php-config=${PHP_DIR}/bin/php-config --enable-openssl --enable-mysqlnd --enable-sockets && \
    make -j$(nproc) && make install && \
    echo -e "extension=swoole.so\nswoole.use_shortname='Off'" > ${PHP_DIR}/etc/conf.d/swoole.ini \
    && rm -rf /tmp/swoole-*
}

ext_grpc() {
  # 安装php-grpc扩展
  ${PHP_DIR}/bin/pecl install grpc-1.54.0 && \
  echo -e "extension=grpc.so" > ${PHP_DIR}/etc/conf.d/grpc.ini
#  export PKG_CONFIG_PATH="/php-msf/abseil/lib64/pkgconfig:/php-msf/grpc/lib/pkgconfig" && \
#  export LD_LIBRARY_PATH="/php-msf/abseil/lib64:/php-msf/grpc/lib:$LD_LIBRARY_PATH" && \
#  export C_INCLUDE_PATH="/php-msf/abseil/include:/php-msf/grpc/include:$C_INCLUDE_PATH" && \
#  cd /php-msf/SoftwarePackage/grpc/src/php/ext/grpc \
#  && ${PHP_DIR}/bin/phpize && \
#  ./configure --with-php-config=${PHP_DIR}/bin/php-config && \
#  make -j$(nproc) && make install && \
#  echo -e "extension=grpc.so" > ${PHP_DIR}/etc/conf.d/grpc.ini
}

ext_protobuf() {
  # 安装protobuf扩展
  ${PHP_DIR}/bin/pecl install protobuf && \
  echo -e "extension=protobuf.so" > ${PHP_DIR}/etc/conf.d/protobuf.ini \
# 编译安装存在诸多依赖问题
#  cd /tmp/protobuf && \
#      if [ ! -d "third_party/utf8_range" ]; then \
#          git clone https://github.com/protocolbuffers/utf8_range.git third_party/utf8_range; \
#      fi
#  cd /php/ext/google/protobuf && \
#  sed -i 's/static char \*strdup_nolocale_lower(char \*str/static char \*strdup_nolocale_lower(const char \*str/' names.c && \
#      sed -i 's|third_party/utf8_range/utf8_range.h|utf8_range.h|' php-upb.h && \
#  export CFLAGS="-I/tmp/protobuf/third_party/utf8_range -Wno-error" \
#  && export LDFLAGS="-L/tmp/protobuf/third_party/utf8_range" && \
#  ${PHP_DIR}/bin/phpize && \
#  ./configure --with-php-config=${PHP_DIR}/bin/php-config --with-protobuf=/php-msf/protobuf && \
#  make -j$(nproc) && make install && \
#  echo -e "extension=protobuf.so" > ${PHP_DIR}/etc/conf.d/protobuf.ini \
#  && rm -rf protobuf
}

ext_amqp() {
  #安装 AMQP（RabbitMQ）扩展
  cd /tmp \
  && wget https://github.com/php-amqp/php-amqp/archive/refs/tags/v1.11.0.tar.gz -O amqp-1.11.0.tar.gz \
  && tar -zxvf amqp-1.11.0.tar.gz \
  && cd php-amqp-1.11.0 \
  && ${PHP_DIR}/bin/phpize && \
  ./configure --with-php-config=${PHP_DIR}/bin/php-config \
  make -j$(nproc) && make install && \
  echo "extension=amqp.so" > ${PHP_DIR}/etc/conf.d/amqp.ini \
  && rf -rf amqp-* php-amqp-*
}

ext_memcached() {
  # 安装 memcached 扩展
  cd /tmp \
  && git clone --depth 1 https://github.com/php-memcached-dev/php-memcached \
  && cd php-memcached \
  && ${PHP_DIR}/bin/phpize && \
  ./configure --with-php-config=${PHP_DIR}/bin/php-config && \
  make -j$(nproc) && make install && \
  echo "extension=memcached.so" > ${PHP_DIR}/etc/conf.d/memcached.ini \
  && rm -rf php-memcached
}

# 主逻辑
# 遍历并编译每个扩展 如果新加扩展需要定义对应的ext_方法
for EXT in $EXTENSIONS; do
  echo -e "\n=== Installing PHP extension: $EXT ==="
  # 调用固定命名的函数 ext_$EXT，
  if declare -F "ext_$EXT" > /dev/null; then
    "ext_$EXT"
  else
    echo -e "\n=== Function ext_$EXT not found! ===" >&2
    exit 1
  fi
done

rm -rf /tmp/php-*
