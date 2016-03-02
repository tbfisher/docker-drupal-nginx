# http://phusion.github.io/baseimage-docker/
# https://github.com/phusion/baseimage-docker/blob/master/Changelog.md
FROM phusion/baseimage:0.9.18

MAINTAINER Brian Fisher <tbfisher@gmail.com>

RUN locale-gen en_US.UTF-8
ENV LANG       en_US.UTF-8
ENV LC_ALL     en_US.UTF-8

# Use baseimage-docker's init system.
CMD ["/sbin/my_init"]

# PHP
RUN add-apt-repository ppa:ondrej/php && \
    apt-get update && \
    DEBIAN_FRONTEND="noninteractive" apt-get install --yes \
        php-cli             \
        php-common          \
        php-curl            \
        php-dev             \
        php-fpm             \
        php-gd              \
        php-imagick         \
        php-imap            \
        php-intl            \
        php-ldap            \
        php-mcrypt          \
        php-memcache        \
        php-mysql           \
        php-redis           \
        php-sqlite3         \
        php-tidy            \
        php-uploadprogress  \
        php-xml
        # php-xhprof

RUN apt-get update && \
    DEBIAN_FRONTEND="noninteractive" apt-get install --yes \
        git

# Xdebug
ENV XDEBUG_VERSION='XDEBUG_2_4_0RC4'
RUN git clone -b $XDEBUG_VERSION --depth 1 https://github.com/xdebug/xdebug.git /usr/local/src/xdebug
RUN cd /usr/local/src/xdebug && \
    phpize      && \
    ./configure && \
    make clean  && \
    make        && \
    make install
COPY ./conf/php/mods-available/xdebug.ini /etc/php/7.0/mods-available/xdebug.ini

# NGNIX
RUN apt-get update && \
    DEBIAN_FRONTEND="noninteractive" apt-get install --yes \
        nginx    \
        ssl-cert
RUN service nginx stop

# SSH
RUN apt-get update && \
    DEBIAN_FRONTEND="noninteractive" apt-get install --yes \
        openssh-server
RUN dpkg-reconfigure openssh-server

# sSMTP
# note php is configured to use ssmtp, which is configured to send to mail:1025,
# which is standard configuration for a mailhog/mailhog image with hostname mail.
RUN apt-get update && \
    DEBIAN_FRONTEND="noninteractive" apt-get install --yes \
        ssmtp

# Configure
RUN mkdir /var/www_files && \
    chgrp www-data /var/www_files && \
    chmod 775 /var/www_files
COPY ./conf/php/fpm/php.ini /etc/php/7.0/fpm/php.ini
COPY ./conf/php/fpm/pool.d/www.conf /etc/php/7.0/fpm/pool.d/www.conf
COPY ./conf/php/cli/php.ini /etc/php/7.0/cli/php.ini
COPY ./conf/nginx/default /etc/nginx/sites-available/default
COPY ./conf/nginx/nginx.conf /etc/nginx/nginx.conf
COPY ./conf/ssh/sshd_config /etc/ssh/sshd_config
COPY ./conf/ssmtp/ssmtp.conf /etc/ssmtp/ssmtp.conf
RUN phpenmod \
    # fpm    \
    mcrypt \
    xdebug
    # xhprof

# Use baseimage-docker's init system.
ADD init/ /etc/my_init.d/
ADD services/ /etc/service/
RUN chmod -v +x /etc/service/*/run
RUN chmod -v +x /etc/my_init.d/*.sh

EXPOSE 80 443 22

# Clean up
RUN apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*
