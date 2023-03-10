#!/bin/bash

install_fileinfo() {
    PHP_VER=$(php-config --version)
    [ ! -d "php-${PHP_VER}" ] && curl -Lk https://secure.php.net/distributions/php-${PHP_VER}.tar.gz | gunzip | tar x
    cd "php-${PHP_VER}/ext/fileinfo"

    phpize
    ./configure --with-php-config=/usr/local/php/bin/php-config
    make && make install

    EXTENSION_DIR=$(php-config --extension-dir)
    if [ -f "${EXTENSION_DIR}/fileinfo.so" ]; then
        echo 'extension=fileinfo.so' > /usr/local/php/etc/php.d/04-fileinfo.ini
    fi
}

[ ! -d "/tmp/extension" ] &&  mkdir /tmp/extension

pushd /tmp/extension

    UNINSTALLED=$(php --ri fileinfo | grep 'not present')
    if [ "${UNINSTALLED}"x != ""x ] ; then 
        install_fileinfo
    fi

popd
