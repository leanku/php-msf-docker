#!/bin/bash

# 设置遇到错误时退出脚本
set -e

# 定义颜色代码
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 打印错误消息并退出
function error_exit {
    echo -e "${RED}[ERROR] $1${NC}" >&2
    exit 1
}

# 打印警告消息
function warning {
    echo -e "${YELLOW}[WARNING] $1${NC}" >&2
}

# 打印成功消息
function success {
    echo -e "${GREEN}[SUCCESS] $1${NC}"
}

# 检查命令是否存在
function check_command {
    if ! command -v $1 &> /dev/null; then
        error_exit "命令 $1 未找到，请先安装"
    fi
}

# 检查Docker是否运行
function check_docker {
    if ! docker info &> /dev/null; then
        error_exit "Docker引擎未运行，请先启动Docker"
    fi
}

# 主函数
function main {
    echo -e "\n=== 开始构建PHP Docker镜像 ==="
    
    # 检查必要命令
    check_command docker
    check_command wget
    check_command tar
    
    # 检查Docker状态
    check_docker

    # 加载.env文件
    if [ -f .env ]; then
        echo "加载.env文件配置..."
        export $(grep -v '^#' .env | xargs)
    else
        warning "未找到.env文件，将使用默认配置"
    fi

    # 设置默认参数
    PHP_VERSION=${PHP_VERSION:-8.3.8}
    NGINX_VERSION=${NGINX_VERSION:-1.25.4}
    REDIS_VERSION=${REDIS_VERSION:-7.2.4}
    IMAGE_TAG=${IMAGE_TAG:-"leanku/php-msf-docker:latest"}
    PUSH_IMAGE=${PUSH_IMAGE:-false}
    PHP_EXTENSIONS=${PHP_EXTENSIONS:-"swoole grpc amqp memcached"}

    echo "配置参数为:"
    echo "  PHP版本: $PHP_VERSION"
    echo "  Nginx版本: $NGINX_VERSION"
    echo "  Redis版本: $REDIS_VERSION"
    echo "  镜像标签: $IMAGE_TAG"
    echo "  PHP扩展: $PHP_EXTENSIONS"

    # 构建镜像
    echo -e "\n开始构建Docker镜像..."
    if ! docker build \
        --build-arg PHP_VERSION=$PHP_VERSION \
        --build-arg NGINX_VERSION=$NGINX_VERSION \
        --build-arg REDIS_VERSION=$REDIS_VERSION \
        --build-arg PHP_EXTENSIONS="$PHP_EXTENSIONS" \
        -t $IMAGE_TAG .; then
        error_exit "Docker镜像构建失败"
    fi

    # 推送镜像
    if [ "$PUSH_IMAGE" = "true" ]; then
        echo -e "\n推送镜像到仓库..."
        if ! docker push $IMAGE_TAG; then
            error_exit "镜像推送失败"
        fi
        success "✅ 镜像推送完成: $IMAGE_TAG"
    fi

    success "✅ 镜像构建完成: $IMAGE_TAG"
    echo -e "\n运行命令测试镜像:"
    echo "docker run -it --rm $IMAGE_TAG php -v"
}

# 执行主函数
main