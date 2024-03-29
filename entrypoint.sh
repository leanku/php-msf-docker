#!/bin/sh
#########################################################################
# START
#########################################################################

install_tools() {
    yum update -y
    yum install -y gcc \
        g++ \
        autoconf \
        automake \
        make \
        cmake
}

clear_tools() {
    yum remove -y gcc \
        g++ \
        autoconf \
        automake \
        make \
        cmake
    yum autoremove -y
    yum autoclean -y
    yum clean -y
}

# Add PHP Extension
install_extensions() {
    if [ -f "/home/extension.sh" ] && [ ! -f /home/.installed ]; then
        pushd /home > /dev/null
            install_tools

            bash extension.sh
            echo $(date "+%F %T") >> /home/.installed

            #clear_tools
        popd > /dev/null
    fi
}

# start sshd
/usr/sbin/sshd -D &

if [ "${1}" = "-D" ]; then
    install_extensions 2>&1 | tee ./install.log 
    
    # start supervisord
    exec /usr/bin/supervisord -n -c /etc/supervisord.conf
else
    exec "$@"
fi
