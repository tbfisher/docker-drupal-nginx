# http://phusion.github.io/baseimage-docker/
# https://github.com/phusion/baseimage-docker/blob/master/Changelog.md
FROM phusion/baseimage:0.9.19

MAINTAINER Brian Fisher <tbfisher@gmail.com>

RUN locale-gen en_US.UTF-8
ENV LANG       en_US.UTF-8
ENV LC_ALL     en_US.UTF-8

# Use baseimage-docker's init system.
CMD ["/sbin/my_init"]

# Upgrade OS
RUN apt-get update && apt-get upgrade -y -o Dpkg::Options::="--force-confold"

# PHP
RUN add-apt-repository ppa:ondrej/php && \
    apt-get update && \
    DEBIAN_FRONTEND="noninteractive" apt-get install --yes \
        php-pear          \
        php7.2-bcmath     \
        php7.2-cli        \
        php7.2-common     \
        php7.2-curl       \
        php7.2-dev        \
        php7.2-fpm        \
        php7.2-gd         \
        php7.2-imagick    \
        php7.2-imap       \
        php7.2-intl       \
        php7.2-json       \
        php7.2-ldap       \
        php7.2-mbstring   \
        php7.2-memcache   \
        php7.2-mysql      \
        php7.2-opcache    \
        php7.2-readline   \
        # php7.2-redis      \
        php7.2-sqlite     \
        php7.2-tidy       \
        php7.2-xdebug     \
        php7.2-xml        \
        php7.2-zip        \
        php7.2-soap       \
        gcc               \
        make              \
        autoconf          \
        libc-dev          \
        pkg-config        \
        php7.2-dev        \
        libmcrypt-dev
        # php7.2-xhprof

# phpredis
ENV PHPREDIS_VERSION='3.0.0'
RUN apt-get update && \
    DEBIAN_FRONTEND="noninteractive" apt-get install --yes \
        git
RUN git clone -b $PHPREDIS_VERSION --depth 1 https://github.com/phpredis/phpredis.git /usr/local/src/phpredis
RUN cd /usr/local/src/phpredis && \
    phpize      && \
    ./configure && \
    make clean  && \
    make        && \
    make install
COPY ./conf/php/mods-available/redis.ini /etc/php/7.2/mods-available/redis.ini

# NGNIX
RUN apt-get update && \
    DEBIAN_FRONTEND="noninteractive" apt-get install --yes \
        nginx

# SSH (for remote drush)
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

# Install composer.
RUN php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');" && \
    php -r "copy('https://composer.github.io/installer.sig', 'composer-setup.sig');" && \
    php -r "if (hash_file('SHA384', 'composer-setup.php') === trim(file_get_contents('composer-setup.sig'))) { echo 'Installer verified'; } else { echo 'Installer corrupt'; unlink('composer-setup.php'); } echo PHP_EOL;" && \
    php composer-setup.php && \
    php -r "unlink('composer-setup.php');" && \
    mv composer.phar /usr/bin/composer

# Install drush globally.
RUN composer global require drush/drush:^8 && \
    ln -s $HOME/.composer/vendor/bin/drush /usr/local/bin/drush

# Install Drupal Console.
RUN cd /usr/local/bin/ && \
    curl https://drupalconsole.com/installer -L -o drupal && \
    chmod +x drupal

# Required for drush, convenience utilities, etc.
RUN apt-get update && \
    DEBIAN_FRONTEND="noninteractive" apt-get install --yes \
        git                 \
        mysql-client        \
        screen

# Configure PHP
RUN mkdir /run/php
RUN cp /etc/php/7.2/fpm/php.ini /etc/php/7.2/fpm/php.ini.bak
COPY ./conf/php/fpm/php.ini-development /etc/php/7.2/fpm/php.ini
# COPY /conf/php/fpm/php.ini-production /etc/php/7.2/fpm/php.ini
RUN cp /etc/php/7.2/fpm/pool.d/www.conf /etc/php/7.2/fpm/pool.d/www.conf.bak
COPY /conf/php/fpm/pool.d/www.conf /etc/php/7.2/fpm/pool.d/www.conf
RUN cp /etc/php/7.2/cli/php.ini /etc/php/7.2/cli/php.ini.bak
COPY /conf/php/cli/php.ini-development /etc/php/7.2/cli/php.ini
# COPY /conf/php/cli/php.ini-production /etc/php/7.2/cli/php.ini
# Prevent php warnings
RUN sed -ir 's@^#@//@' /etc/php/7.2/mods-available/*
RUN phpenmod \
    redis  \
    soap
    # xhprof

RUN pecl install mcrypt-1.0.1 -y
RUN echo extension=mcrypt.so >> /etc/php/7.2/fpm/php.ini
RUN echo extension=mcrypt.so >> /etc/php/7.2/cli/php.ini

# Configure NGINX
RUN cp -r /etc/nginx/sites-available/default /etc/nginx/sites-available/default.bak
COPY ./conf/nginx/default-development /etc/nginx/sites-available/default
# COPY ./conf/nginx/default-production /etc/nginx/sites-available/default
RUN cp /etc/nginx/nginx.conf /etc/nginx/nginx.conf.bak
COPY ./conf/nginx/nginx.conf /etc/nginx/nginx.conf

# Configure sshd
RUN cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak
COPY ./conf/ssh/sshd_config /etc/ssh/sshd_config
RUN cp /etc/ssmtp/ssmtp.conf /etc/ssmtp/ssmtp.conf.bak
COPY ./conf/ssmtp/ssmtp.conf /etc/ssmtp/ssmtp.conf

# Configure directories for drupal.
RUN mkdir /var/www_files && \
    mkdir -p /var/www_files/public && \
    mkdir -p /var/www_files/private && \
    chown -R www-data:www-data /var/www_files
VOLUME /var/www_files
# Virtualhost is configured to serve from /var/www/web.
RUN mkdir -p /var/www/web && \
    echo '<?php phpinfo();' > /var/www/web/index.php && \
    chgrp www-data /var/www_files && \
    chmod 775 /var/www_files

# https://github.com/phusion/baseimage-docker/pull/339
# https://github.com/phusion/baseimage-docker/pull/341
RUN sed -i 's/syslog/adm/g' /etc/logrotate.conf

# Use baseimage-docker's init system.
ADD init/ /etc/my_init.d/
RUN chmod -v +x /etc/my_init.d/*.sh
ADD services/ /etc/service/
RUN chmod -v +x /etc/service/*/run

EXPOSE 80 22

# Clean up
RUN apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*
