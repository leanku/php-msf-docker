#!/usr/bin/env bash

####### Build Script #######

show_errmsg() {
    printf "\e[1;31m%s \e[0m\n" "${1}"
    exit 1
}

version_split() {
    tag_full_ver="${1}"
    tag_pre_ver=${tag_full_ver:0:3}

    ver1=${tag_full_ver:4:2}
    if [[ ${ver1} < 10 ]]; then
        php_ver=${tag_pre_ver}.${ver1:1:1}
    else
        php_ver=${tag_pre_ver}.${ver1}
    fi

    printf "\n%s\n%s\n%s\n\n" $tag_full_ver $tag_pre_ver $php_ver
}

# docker buildx
docker_buildx() {
    printf "TAGS:\n${prefix}php-msf-docker:${tag_full_ver}\n${prefix}php-msf-docker:${tag_pre_ver}\n\n"
    if [[ "${tag_pre_ver}" = "8.2" ]]; then 
        # docker buildx build --platform linux/amd64 ,linux/arm64 \
        docker buildx build --platform "${D_PLATFORM}" \
        --output "type=image,push=${D_PUSH}" \
        --tag "${prefix}php-msf-docker:${tag_full_ver}" \
        --tag "${prefix}php-msf-docker:${tag_pre_ver}" \
        --tag "${prefix}php-msf-docker:latest" \
        --build-arg PHP_VERSION="${php_ver}" \
        --build-arg NGINX_VERSION="${NGINX_VERSION}" \
        --build-arg GH_MIRROR_URL="${GH_MIRROR_URL}" \
        --file ./Dockerfile \
        --progress plain \
        .   
    else
        # docker buildx build --platform linux/amd64,linux/arm64 \
        docker buildx build --platform "${D_PLATFORM}" \
        --output "type=image,push=${D_PUSH}" \
        --tag "${prefix}php-msf-docker:${tag_full_ver}" \
        --tag "${prefix}php-msf-docker:${tag_pre_ver}" \
        --build-arg PHP_VERSION="${php_ver}" \
        --build-arg NGINX_VERSION="${NGINX_VERSION}" \
        --build-arg GH_MIRROR_URL="${GH_MIRROR_URL}" \
        --file ./Dockerfile \
        --progress plain \
        .
    fi 
}

# 只当前构架，不使用 QEMU
docker_build() {
    # 构建
    docker_tag

    # 推送
    if [[ "${D_PUSH}" = "true" ]]; then
        docker_push
    fi
}

# 构建与生成 TAG
docker_tag() {
    docker build --build-arg PHP_VERSION="${php_ver}" \
      --build-arg NGINX_VERSION="${NGINX_VERSION}" \
      --build-arg GH_MIRROR_URL="${GH_MIRROR_URL}" \
      -t ${prefix}php-msf-docker:${tag_full_ver} \
      -f ./Dockerfile . \
    || show_errmsg "docker build failed"

    image_id=$(docker images | grep ${prefix}php-msf-docker | grep ${tag_full_ver} | awk '{print $3}')

    docker tag ${image_id} ${prefix}php-msf-docker:${tag_pre_ver} || show_errmsg "docker tag failed"

    if [[ "${tag_pre_ver}" = "8.2" ]]; then 
        docker tag ${image_id} ${prefix}php-msf-docker:latest
    fi
}

# 推送
docker_push() {
    docker push ${prefix}php-msf-docker:${tag_full_ver}
    docker push ${prefix}php-msf-docker:${tag_pre_ver}

    if [[ "${tag_pre_ver}" = "8.2" ]]; then 
        docker push ${prefix}php-msf-docker:latest
    fi
}

build() {
    version_split "${1}"

    rm -rf ./logoutput.log
    if [[ -z "${BUILDX_ENABLE}" ]]; then
        # 不使用 buildx，只编译 amd64
        docker_build 2>&1 | tee ./logoutput.log 
    else
        # 使用 docker buildx
        docker_buildx 2>&1 | tee ./logoutput.log 
    fi

}

main() {
    set -e

    if [[ -z "${1}" ]]; then
        prefix="leanku/"
    else
        prefix="${1}/"
    fi    

    if [[ -z "${D_PUSH}" ]]; then
        D_PUSH="false" # 是否推送
    fi  

    if [[ -z "${D_PLATFORM}" ]]; then
        D_PLATFORM="linux/amd64,linux/arm64" # 构建环境
    fi  

    # locale env
    if [[ "${2}" = "env" ]]; then
        CRTDIR=$(pwd)
        # printf "${CRTDIR}/.env"
        source "${CRTDIR}/.env"
    fi

    # 架构大于 1 则使用 buildx
    platforms=(${D_PLATFORM//\,/ }) 
    if [[ ${#platforms[@]} -gt 1 ]]; then
        BUILDX_ENABLE="yes"
    fi

    build_time=$(date "+%F %T")
    printf "\n****** [ BUILD START ] ******\nbuild time: %s\ndocker push: %s\nbuild platform: %s\nphp version: %s\nprefix: %s\ngh_proxy: %s\n" "${build_time}" $(echo ${D_PUSH} | tr '[:lower:]' '[:upper:]' ) $(echo ${D_PLATFORM} | tr '[:lower:]' '[:upper:]' ) "${IMAGE_VERSION}" "${prefix}" "${GH_MIRROR_URL}"

    string="${IMAGE_VERSION}"
    array=(${string//,/ }) 

    for var in ${array[@]}
    do
        echo "${var}"
       build "${var}"
    done

}

main "$@" || exit 1

# ./build.sh leanku env