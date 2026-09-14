#!/usr/bin/env sh
set -eu

# 用法：cp .env.example .env；编辑后执行 ./build.sh build|tag|push|test
if [ -f .env ]; then
    set -a
    . ./.env
    set +a
fi

ACTION=${1:-build}
IMAGE_NAME=${IMAGE_NAME:-php-msf}
IMAGE_TAG=${IMAGE_TAG:-alpine-php8.5}
PLATFORM=${PLATFORM:-linux/amd64}
BUILD_TARGET=${BUILD_TARGET:-runtime}
LOCAL_IMAGE="${IMAGE_NAME}:${IMAGE_TAG}"

build() {
    docker buildx build --load --platform "$PLATFORM" --target "$BUILD_TARGET" -t "$LOCAL_IMAGE" .
}

case "$ACTION" in
    build) build ;;
    tag)
        : "${REGISTRY_IMAGE:?请在 .env 中设置 REGISTRY_IMAGE，例如 registry.example.com/team/php-msf}"
        docker tag "$LOCAL_IMAGE" "${REGISTRY_IMAGE}:${IMAGE_TAG}"
        ;;
    push)
        : "${REGISTRY_IMAGE:?请在 .env 中设置 REGISTRY_IMAGE}"
        docker buildx build --platform "$PLATFORM" --target "$BUILD_TARGET" -t "${REGISTRY_IMAGE}:${IMAGE_TAG}" --push .
        ;;
    test)
        docker run --rm --entrypoint /bin/sh "$LOCAL_IMAGE" -ec 'php -m; nginx -t; redis-server --version; node --version; npm --version'
        ;;
    *) echo "用法: $0 {build|tag|push|test}" >&2; exit 64 ;;
esac
