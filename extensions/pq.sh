#!/bin/bash

install_pecl_raphf() {
    curl -Lk https://pecl.php.net/get/raphf-2.0.1.tgz | gunzip | tar x

    cd raphf-2.0.1
    phpize
    ./configure --with-php-config=/usr/local/php/bin/php-config
    make && make install

    EXTENSION_DIR=$(php-config --extension-dir)
    if [ -f "${EXTENSION_DIR}/raphf.so" ]; then
        echo 'extension=raphf.so' > /usr/local/php/etc/php.d/05-raphf.ini
    fi

    cd ..
}

install_pecl_pq() {
    curl -Lk https://pecl.php.net/get/pq-2.2.0.tgz | gunzip | tar x 

    cd pq-2.2.0
    phpize
    ./configure --with-php-config=/usr/local/php/bin/php-config
    make && make install

    EXTENSION_DIR=$(php-config --extension-dir)
    if [ -f "${EXTENSION_DIR}/pq.so" ]; then
        echo 'extension=pq.so' > /usr/local/php/etc/php.d/02-pq.ini
    fi

    cd ..
}

[ ! -d "/tmp/extension" ] &&  mkdir /tmp/extension

pushd /tmp/extension

    UNINSTALLED=$(php --ri raphf | grep 'not present')
    if [ "${UNINSTALLED}"x != ""x ] ; then 
        install_pecl_raphf
    fi

    INSTALLED_raphf=$(php --ri raphf | grep 'not present')
    INSTALLED_pq=$(php --ri pq | grep 'not present')
    if [ "${INSTALLED_pq}"x != ""x ] && [ "${INSTALLED_raphf}"x = ""x ]; then 
        install_pecl_pq
    fi

popd
