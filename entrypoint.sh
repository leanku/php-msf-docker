#!/bin/sh
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