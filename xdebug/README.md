# Server Installation Steps:

Perform the following commands on the server:

### PHP XDebug module

    sudo pecl install xdebug
    echo -e "zend_extension = \"/usr/lib64/php/modules/xdebug.so\"\nxdebug.remote_enable=1" > /tmp/xdebug.ini
    sudo mv /tmp/xdebug.ini /etc/php.d/xdebug.ini
    sudo /etc/init.d/httpd restart

### PyDBGProxy

    s3cmd get <your s3 bucket>:xdebug/xdebug.tgz /tmp/xdebug.tgz
    tar xzf /tmp/xdebug.tgz -C ~/
    if ! crontab -l; then
    (
        echo SHELL=/bin/bash;
        echo PATH=/usr/kerberos/bin:/usr/local/bin:/bin:/usr/bin
        echo;
        echo '* * * * * ( (ps ax | grep "python .*/pydbgpproxy\$") || ~/xdebug/dbgpproxy/bin/pydbgpproxy) > /dev/null 2>&1 &'
    ) | crontab && EDITOR=touch crontab -e
    else
        ! echo "Cannot replace existing crontab"
    fi
