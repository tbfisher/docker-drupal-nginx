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
RUN add-apt-repository ppa:ondrej/php5-5.6 && \
    apt-get update && \
    DEBIAN_FRONTEND="noninteractive" apt-get install --yes \
        php-pear        \
        php5-cli        \
        php5-common     \
        php5-curl       \
        php5-gd         \
        php5-imagick    \
        php5-imap       \
        php5-intl       \
        php5-json       \
        php5-ldap       \
        php5-mcrypt     \
        php5-memcache   \
        php5-mysql      \
        php5-redis      \
        php5-sqlite     \
        php5-tidy
        # php5-xhprof
RUN php5enmod \
    mcrypt
    # xhprof
RUN sed -ir 's@^#@//@' /etc/php5/mods-available/*

RUN apt-get update && \
    DEBIAN_FRONTEND="noninteractive" apt-get install --yes \
        git         \
        php5-dev

# Xdebug
ENV XDEBUG_VERSION='XDEBUG_2_3_3'
RUN git clone -b $XDEBUG_VERSION --depth 1 https://github.com/xdebug/xdebug.git /usr/local/src/xdebug
RUN cd /usr/local/src/xdebug && \
    phpize      && \
    ./configure && \
    make clean  && \
    make        && \
    make install
COPY ./conf/php5/mods-available/xdebug.ini /etc/php5/mods-available/xdebug.ini
RUN php5enmod xdebug

# PHP-FPM
RUN apt-get update && \
    DEBIAN_FRONTEND="noninteractive" apt-get install --yes \
        php5-fpm
RUN php5enmod -s fpm \
    mcrypt \
    xhprof \
    xdebug

# NGNIX
RUN apt-get update && \
    DEBIAN_FRONTEND="noninteractive" apt-get install --yes \
        nginx    \
        ssl-cert
RUN service nginx stop

# SSH (for remote drush)
RUN apt-get update && \
    DEBIAN_FRONTEND="noninteractive" apt-get install --yes \
        openssh-server
RUN dpkg-reconfigure openssh-server

# Drush
RUN apt-get update && \
    DEBIAN_FRONTEND="noninteractive" apt-get install --yes \
        mysql-client
RUN curl -sS https://getcomposer.org/installer | \
    php -- --install-dir=/usr/local/bin --filename=composer
ENV DRUSH_VERSION='8.0.3'
RUN git clone -b $DRUSH_VERSION --depth 1 https://github.com/drush-ops/drush.git /usr/local/src/drush
RUN cd /usr/local/src/drush && composer install
RUN ln -s /usr/local/src/drush/drush /usr/local/bin/drush
COPY ./conf/drush/drush-remote.sh /usr/local/bin/drush-remote
RUN chmod +x /usr/local/bin/drush-remote

# Drupal Console.
ENV DRUPALCONSOLE_VERSION='0.10.9'
RUN git clone -b $DRUPALCONSOLE_VERSION --depth 1 https://github.com/hechoendrupal/DrupalConsole.git /usr/local/src/drupalconsole
RUN cd /usr/local/src/drupalconsole && composer install
RUN ln -s /usr/local/src/drupalconsole/bin/console /usr/local/bin/drupal

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
COPY ./conf/php5/fpm/php.ini /etc/php5/fpm/php.ini
COPY ./conf/php5/fpm/pool.d/www.conf /etc/php5/fpm/pool.d/www.conf
COPY ./conf/php5/cli/php.ini /etc/php5/cli/php.ini
COPY ./conf/nginx/default /etc/nginx/sites-available/default
COPY ./conf/nginx/nginx.conf /etc/nginx/nginx.conf
COPY ./conf/ssh/sshd_config /etc/ssh/sshd_config
COPY ./conf/ssmtp/ssmtp.conf /etc/ssmtp/ssmtp.conf

# Use baseimage-docker's init system.
ADD init/ /etc/my_init.d/
ADD services/ /etc/service/
RUN chmod -v +x /etc/service/*/run
RUN chmod -v +x /etc/my_init.d/*.sh

EXPOSE 80 443 22

# Clean up
RUN apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*
