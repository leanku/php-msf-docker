#!/bin/sh
# install-php-extensions.sh - 独立版 PHP 扩展安装脚本（PHP8+）
set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# ============== 配置区域 ==============
# PHP 安装目录
PHP_DIR="/php-msf/php"

# 要安装的扩展列表（直接在这里定义，已定义：grpc protobuf swoole redis amqp memcached imagick）
EXTENSIONS="protobuf swoole redis amqp memcached imagick"
# ======================================

# 检查 PHP 环境
check_php_env() {
    echo -e "${YELLOW}检查 PHP 环境...${NC}"
    
    if [ ! -f "${PHP_DIR}/bin/php" ]; then
        echo -e "${RED}错误: 未找到 PHP 可执行文件 (${PHP_DIR}/bin/php)${NC}"
        exit 1
    fi
    
    if [ ! -f "${PHP_DIR}/bin/php-config" ]; then
        echo -e "${RED}错误: 未找到 php-config (${PHP_DIR}/bin/php-config)${NC}"
        exit 1
    fi
    
    if [ ! -f "${PHP_DIR}/bin/phpize" ]; then
        echo -e "${RED}错误: 未找到 phpize (${PHP_DIR}/bin/phpize)${NC}"
        exit 1
    fi
    
    # 获取 PHP 版本
    PHP_VERSION=$(${PHP_DIR}/bin/php -r "echo PHP_VERSION;")
    echo -e "${GREEN}检测到 PHP 版本: ${PHP_VERSION}${NC}"
}

# 获取扩展目录
get_extension_dir() {
    EXT_DIR=$(${PHP_DIR}/bin/php-config --extension-dir)
    echo -e "${GREEN}PHP扩展目录: ${EXT_DIR}${NC}"
    
    mkdir -p ${PHP_DIR}/extensions
    mkdir -p ${PHP_DIR}/etc/conf.d
}

# 检查依赖工具
check_dependencies() {
    echo -e "${YELLOW}检查公共依赖...${NC}"
    
    for cmd in wget tar make gcc g++ autoconf; do
        if ! command -v $cmd >/dev/null 2>&1; then
            echo -e "${YELLOW}安装 $cmd...${NC}"
            apk add --no-cache $cmd
        fi
    done
}

# 通用的源码编译函数
compile_from_source() {
    local ext_name=$1
    local ext_url=$2
    local ext_dir=$3
    local config_opts=$4
    
    cd /tmp
    echo -e "${YELLOW}从源码编译 ${ext_name}...${NC}"
    
    # 下载源码
    if [ -f "${ext_name}.tgz" ]; then
        echo -e "${YELLOW}使用本地缓存: ${ext_name}.tgz${NC}"
    else
        wget -q --show-progress "${ext_url}" -O "${ext_name}.tgz"
    fi
    
    tar -zxvf "${ext_name}.tgz"
    
    # 进入目录
    if [ -n "$ext_dir" ]; then
        cd "$ext_dir"
    else
        cd $(find . -maxdepth 1 -type d -name "${ext_name}*" | head -1)
    fi
    
    # 运行 phpize 和配置
    ${PHP_DIR}/bin/phpize
    ./configure --with-php-config=${PHP_DIR}/bin/php-config ${config_opts}
    
    # 编译安装
    make -j$(nproc)
    make install
    
    # 清理
    cd /tmp
    rm -rf ${ext_name}-* ${ext_name}.tgz
}

# Redis 扩展
ext_redis() {
    echo -e "${GREEN}安装 Redis 扩展...${NC}"
    
    # 尝试多个版本，优先使用最新稳定版
    for version in "6.2.0" "6.0.2" "5.3.7"; do
        if ${PHP_DIR}/bin/pecl list | grep -q redis; then
            break
        fi
        echo -e "${YELLOW}尝试安装 redis-$version...${NC}"
        if echo "yes" | ${PHP_DIR}/bin/pecl install redis-$version 2>/dev/null; then
            echo "extension=redis.so" > ${PHP_DIR}/etc/conf.d/redis.ini
            echo -e "${GREEN}Redis 扩展 $version 安装完成${NC}"
            return 0
        fi
    done
    
    # PECL 失败，源码编译
    compile_from_source "redis" \
        "https://pecl.php.net/get/redis-6.2.0.tgz" \
        "" \
        ""
    
    echo "extension=redis.so" > ${PHP_DIR}/etc/conf.d/redis.ini
    echo -e "${GREEN}Redis 扩展安装完成 (源码编译)${NC}"
}

# Swoole 扩展
ext_swoole() {
    echo -e "${GREEN}安装 Swoole 扩展...${NC}"
    
    # 安装依赖
    apk add --no-cache openssl-dev curl-dev
    
    # 尝试 PECL 安装
    for version in "6.0.1" "5.1.6" "5.1.5"; do
        if ${PHP_DIR}/bin/pecl list | grep -q swoole; then
            break
        fi
        echo -e "${YELLOW}尝试安装 swoole-$version...${NC}"
        if echo "yes" | ${PHP_DIR}/bin/pecl install swoole-$version 2>/dev/null; then
            echo -e "extension=swoole.so\nswoole.use_shortname='Off'" > ${PHP_DIR}/etc/conf.d/swoole.ini
            echo -e "${GREEN}Swoole 扩展 $version 安装完成${NC}"
            return 0
        fi
    done
    
    # 源码编译
    compile_from_source "swoole" \
        "https://github.com/swoole/swoole-src/archive/master.tar.gz" \
        "swoole-src-master" \
        "--enable-openssl --enable-mysqlnd --enable-sockets --enable-http2"
    
    echo -e "extension=swoole.so\nswoole.use_shortname='Off'" > ${PHP_DIR}/etc/conf.d/swoole.ini
    echo -e "${GREEN}Swoole 扩展安装完成 (源码编译)${NC}"
}

# gRPC 扩展
ext_grpc() {
    echo -e "${GREEN}安装 gRPC 扩展...${NC}"
    
    # 检查本地缓存
    LOCAL_PACKAGE="${INSTALL_DIR}/SoftwarePackage/grpc-1.76.0.tgz"
    
    # 安装依赖
    apk add --no-cache openssl-dev pcre-dev zlib-dev linux-headers > /dev/null 2>&1
    
    cd /tmp
    
    # 使用本地缓存或下载
    if [ -f "$LOCAL_PACKAGE" ]; then
        echo -e "${YELLOW}使用本地缓存: grpc-1.76.0.tgz${NC}"
        cp "$LOCAL_PACKAGE" .
    else
        echo -e "${YELLOW}下载 grpc-1.76.0.tgz...${NC}"
        wget -q https://pecl.php.net/get/grpc-1.76.0.tgz
    fi
    
    tar -zxf grpc-1.76.0.tgz
    cd grpc-1.76.0
    
    ${PHP_DIR}/bin/phpize > /dev/null 2>&1
    
    # 静默编译
    echo -e "${YELLOW}编译中（约5-10分钟，请耐心等待）...${NC}"
    {
        export CFLAGS="-DGRPC_POSIX_FORK_ALLOW_PTHREAD_ATFORK=1 -DGRPC_ARES=0 -O2 -w"
        export CXXFLAGS="$CFLAGS"
        
        ./configure --with-php-config=${PHP_DIR}/bin/php-config > configure.log 2>&1
        make -j$(nproc) > make.log 2>&1
        make install > install.log 2>&1
    } || {
        echo -e "${RED}编译失败，查看日志:${NC}"
        tail -20 configure.log make.log install.log
        exit 1
    }
    
    echo "extension=grpc.so" > ${PHP_DIR}/etc/conf.d/grpc.ini
    
    # 清理
    cd /tmp
    rm -rf grpc-1.76.0 grpc-1.76.0.tgz
    
    echo -e "${GREEN}gRPC 扩展安装完成${NC}"
}

# Protobuf 扩展
ext_protobuf() {
    echo -e "${GREEN}安装 Protobuf 扩展...${NC}"
    
    # 根据 PHP 版本选择 Protobuf 版本
    if echo "$PHP_VERSION" | grep -q "^8.[3-9]"; then
        # PHP 8.3+ 使用 4.x 或 5.x
        for version in "5.34.0" "4.33.5" "4.32.1"; do
            if echo "yes" | ${PHP_DIR}/bin/pecl install protobuf-$version 2>/dev/null; then
                echo "extension=protobuf.so" > ${PHP_DIR}/etc/conf.d/protobuf.ini
                echo -e "${GREEN}Protobuf 扩展 $version 安装完成${NC}"
                return 0
            fi
        done
    else
        # PHP 8.0-8.2 使用 3.x
        if echo "yes" | ${PHP_DIR}/bin/pecl install protobuf-3.25.3 2>/dev/null; then
            echo "extension=protobuf.so" > ${PHP_DIR}/etc/conf.d/protobuf.ini
            echo -e "${GREEN}Protobuf 扩展 3.25.3 安装完成${NC}"
            return 0
        fi
    fi
    
    # PECL 失败，尝试 Alpine 包
    if apk add --no-cache php83-pecl-protobuf 2>/dev/null; then
        echo -e "${GREEN}Protobuf 扩展安装完成 (Alpine 包)${NC}"
        return 0
    fi
    
    # 最后尝试源码编译简化版
    echo -e "${YELLOW}尝试源码编译 Protobuf...${NC}"
    cd /tmp
    wget -q https://pecl.php.net/get/protobuf-4.33.5.tgz
    tar -zxvf protobuf-4.33.5.tgz
    cd protobuf-4.33.5
    
    ${PHP_DIR}/bin/phpize
    ./configure --with-php-config=${PHP_DIR}/bin/php-config
    make -j$(nproc)
    make install
    
    echo "extension=protobuf.so" > ${PHP_DIR}/etc/conf.d/protobuf.ini
    
    cd /tmp
    rm -rf protobuf-4.33.5 protobuf-4.33.5.tgz
    
    echo -e "${GREEN}Protobuf 扩展安装完成 (源码编译)${NC}"
}

# AMQP 扩展
ext_amqp() {
    echo -e "${GREEN}安装 AMQP 扩展...${NC}"
    
    apk add --no-cache rabbitmq-c-dev
    
    for version in "2.1.2" "2.1.1" "2.0.1"; do
        if echo "yes" | ${PHP_DIR}/bin/pecl install amqp-$version 2>/dev/null; then
            echo "extension=amqp.so" > ${PHP_DIR}/etc/conf.d/amqp.ini
            echo -e "${GREEN}AMQP 扩展 $version 安装完成${NC}"
            return 0
        fi
    done
    
    compile_from_source "amqp" \
        "https://github.com/php-amqp/php-amqp/archive/refs/tags/v1.11.0.tar.gz" \
        "php-amqp-1.11.0" \
        ""
    
    echo "extension=amqp.so" > ${PHP_DIR}/etc/conf.d/amqp.ini
    echo -e "${GREEN}AMQP 扩展安装完成 (源码编译)${NC}"
}

# Memcached 扩展
ext_memcached() {
    echo -e "${GREEN}安装 Memcached 扩展...${NC}"
    
    apk add --no-cache libmemcached-dev libevent-dev
    
    if echo "yes" | ${PHP_DIR}/bin/pecl install memcached 2>/dev/null; then
        echo "extension=memcached.so" > ${PHP_DIR}/etc/conf.d/memcached.ini
        echo -e "${GREEN}Memcached 扩展安装完成${NC}"
        return 0
    fi
    
    cd /tmp
    git clone --depth 1 https://github.com/php-memcached-dev/php-memcached.git
    cd php-memcached
    
    ${PHP_DIR}/bin/phpize
    ./configure --with-php-config=${PHP_DIR}/bin/php-config \
                --enable-memcached-json \
                --enable-memcached-igbinary
    
    make -j$(nproc)
    make install
    
    echo "extension=memcached.so" > ${PHP_DIR}/etc/conf.d/memcached.ini
    
    cd /tmp
    rm -rf php-memcached
    
    echo -e "${GREEN}Memcached 扩展安装完成 (源码编译)${NC}"
}

# Imagick 扩展
ext_imagick() {
    echo -e "${GREEN}安装 Imagick 扩展...${NC}"
    
    apk add --no-cache imagemagick imagemagick-dev
    
    # 尝试 PECL
    for version in "3.7.0" "3.6.0" "3.5.1"; do
        if echo "yes" | ${PHP_DIR}/bin/pecl install imagick-$version 2>/dev/null; then
            echo "extension=imagick.so" > ${PHP_DIR}/etc/conf.d/imagick.ini
            echo -e "${GREEN}Imagick 扩展 $version 安装完成${NC}"
            return 0
        fi
    done
    
    # 源码编译
    cd /tmp
    git clone --depth 1 https://github.com/Imagick/imagick.git
    cd imagick
    
    ${PHP_DIR}/bin/phpize
    ./configure --with-php-config=${PHP_DIR}/bin/php-config
    make -j$(nproc)
    make install
    
    echo "extension=imagick.so" > ${PHP_DIR}/etc/conf.d/imagick.ini
    
    cd /tmp
    rm -rf imagick
    
    echo -e "${GREEN}Imagick 扩展安装完成 (源码编译)${NC}"
}

# 添加 igbinary 扩展函数
ext_igbinary() {
    echo -e "${GREEN}安装 igbinary 扩展...${NC}"
    
    # 尝试 PECL 安装
    if echo "yes" | ${PHP_DIR}/bin/pecl install igbinary 2>/dev/null; then
        echo "extension=igbinary.so" > ${PHP_DIR}/etc/conf.d/igbinary.ini
        echo -e "${GREEN}igbinary 扩展安装完成 (PECL)${NC}"
        return 0
    fi
    
    # 如果 PECL 失败，从源码编译
    echo -e "${YELLOW}PECL 安装失败，尝试源码编译...${NC}"
    cd /tmp
    git clone --depth 1 https://github.com/igbinary/igbinary.git
    cd igbinary
    
    ${PHP_DIR}/bin/phpize
    ./configure --with-php-config=${PHP_DIR}/bin/php-config
    make -j$(nproc)
    make install
    
    echo "extension=igbinary.so" > ${PHP_DIR}/etc/conf.d/igbinary.ini
    
    # 清理
    cd /tmp
    rm -rf igbinary
    
    echo -e "${GREEN}igbinary 扩展安装完成 (源码编译)${NC}"
}

# 验证安装结果
verify_installation() {
    echo -e "${YELLOW}验证扩展安装结果...${NC}"
    
    local php_bin="${PHP_DIR}/bin/php"
    local installed_exts=$($php_bin -m | grep -v "^\[")
    
    for ext in $EXTENSIONS; do
        if echo "$installed_exts" | grep -q "^$ext$"; then
            echo -e "${GREEN}✓ $ext 安装成功${NC}"
        else
            echo -e "${RED}✗ $ext 安装失败${NC}"
        fi
    done
}

# 清理临时文件
cleanup() {
    echo -e "${YELLOW}清理临时文件...${NC}"
    rm -rf /tmp/pear /tmp/pear-* /tmp/*.tgz /tmp/*.tar.gz /tmp/*.zip 2>/dev/null || true
}

# 主函数
main() {
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}PHP 扩展安装脚本 (独立版)${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo "PHP 安装目录: $PHP_DIR"
    echo "待安装扩展: $EXTENSIONS"
    echo -e "${GREEN}========================================${NC}"
    
    # 执行检查
    check_php_env
    check_dependencies
    get_extension_dir

    ext_igbinary
    
    # 安装扩展
    for EXT in $EXTENSIONS; do
        echo -e "${GREEN}----------------------------------------${NC}"
        echo -e "正在安装扩展: ${YELLOW}$EXT${NC}"
        echo -e "${GREEN}----------------------------------------${NC}"
        
        if command -v "ext_$EXT" >/dev/null 2>&1; then
            "ext_$EXT"
        else
            echo -e "${RED}错误: 未找到扩展 $EXT 的安装函数${NC}"
            exit 1
        fi
    done
    
    # 验证和清理
    verify_installation
    cleanup
    
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}所有扩展安装完成！${NC}"
    echo -e "${GREEN}========================================${NC}"
}

# 执行主函数
main