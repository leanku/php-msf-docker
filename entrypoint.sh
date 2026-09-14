#!/bin/sh
set -eu

# Redis 本身不读取环境变量。这里基于基础配置生成运行时配置，既保留默认
# 单实例行为，也允许每个容器通过环境变量成为 Redis Cluster 的一个节点。
configure_redis() {
    redis_conf="/php-msf/redis/conf/redis.conf"
    runtime_conf="/php-msf/redis/conf/runtime.conf"
    cp "$redis_conf" "$runtime_conf"

    if [ "${REDIS_PASSWORD:-}" != "" ]; then
        case "$REDIS_PASSWORD" in
            *" "*|*"\t"*|*"\""*)
                echo "REDIS_PASSWORD 不能包含空白字符或双引号" >&2
                exit 64
                ;;
        esac
        printf '\nrequirepass %s\nmasterauth %s\n' "$REDIS_PASSWORD" "$REDIS_PASSWORD" >> "$runtime_conf"
    fi

    if [ "${REDIS_CLUSTER_ENABLED:-false}" = "true" ]; then
        cluster_port="${REDIS_CLUSTER_PORT:-6379}"
        bus_port="${REDIS_CLUSTER_BUS_PORT:-16379}"
        printf '\nport %s\ncluster-enabled yes\ncluster-config-file nodes.conf\ncluster-node-timeout 5000\ncluster-require-full-coverage no\ncluster-announce-port %s\ncluster-announce-bus-port %s\n' \
            "$cluster_port" "${REDIS_CLUSTER_ANNOUNCE_PORT:-$cluster_port}" "${REDIS_CLUSTER_ANNOUNCE_BUS_PORT:-$bus_port}" >> "$runtime_conf"

        if [ "${REDIS_CLUSTER_ANNOUNCE_IP:-}" != "" ]; then
            printf 'cluster-announce-ip %s\n' "$REDIS_CLUSTER_ANNOUNCE_IP" >> "$runtime_conf"
        fi
    fi
}

configure_redis

#########################################################################
# START
#########################################################################
# start sshd
/usr/sbin/sshd -D &

if [ "${1}" = "-D" ]; then
#    ./check_install.sh 2>&1 | tee ./check_install.log

    # start supervisord
    exec /usr/bin/supervisord -n -c /etc/supervisord.conf
else
    exec "$@"
fi
