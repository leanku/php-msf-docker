#!/bin/bash

install_libmemcached() {

    curl -Lk https://launchpad.net/libmemcached/1.0/1.0.18/+download/libmemcached-1.0.18.tar.gz | gunzip | tar x

    cd libmemcached-1.0.18
    ./configure --prefix=/usr/local/libmemcached-1.0.18 --with-memcached
    make && make install

    EXTENSION_DIR=$(php-config --extension-dir)
    if [ -f "${EXTENSION_DIR}/memcached.so" ]; then
        echo 'extension=memcached.so' > /usr/local/php/etc/php.d/memcached.ini
    fi

    cd ..
}

install_pecl_memcache() {
    curl -Lkhttps://pecl.php.net/get/memcached-3.2.0.tgz | gunzip | tar x

    cd memcached-3.2.0
    phpize
    ./configure --enable-memcached --with-php-config=/usr/local/php/bin/php-config --with-libmemcached-dir=/usr/local/libmemcached-1.0.18 --disable-memcached-sasl
    make && make install

    EXTENSION_DIR=$(php-config --extension-dir)
    if [ -f "${EXTENSION_DIR}/memcache.so" ]; then
        echo 'extension=memcache.so' > /usr/local/php/etc/php.d/memcache.ini
    fi

    cd ..
}

[ ! -d "/tmp/extension" ] &&  mkdir /tmp/extension

pushd /tmp/extension
    
    UNINSTALLED=$(php --ri memcached | grep 'not present')
    if [ "${UNINSTALLED}"x != ""x ] ; then 
        install_libmemcached
        install_pecl_memcached
    fi

popd
