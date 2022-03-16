# http://phusion.github.io/baseimage-docker/
# https://github.com/phusion/baseimage-docker/blob/master/Changelog.md
FROM phusion/baseimage:focal-1.0.0

MAINTAINER Brian Fisher <tbfisher@gmail.com>

RUN locale-gen en_US.UTF-8
ENV LANG       en_US.UTF-8
ENV LC_ALL     en_US.UTF-8
ENV NVM_VERSION v0.39.1
ENV NODE_VERSION 16.14.0
ENV TERMINUS_VERSION 3.0.6
ENV DRUSH_VERSION ^11

# Use baseimage-docker's init system.
CMD ["/sbin/my_init"]

# Upgrade OS
RUN apt-get update && apt-get upgrade -y -o Dpkg::Options::="--force-confold"

# PHP
RUN add-apt-repository ppa:ondrej/php && \
    apt-get update && \
    DEBIAN_FRONTEND="noninteractive" apt-get install --yes \
        php-pear          \
        php8.1-bcmath     \
        php8.1-cli        \
        php8.1-common     \
        php8.1-curl       \
        php8.1-dev        \
        php8.1-fpm        \
        php8.1-gd         \
        php8.1-imagick    \
        php8.1-imap       \
        php8.1-intl       \
        php8.1-ldap       \
        php8.1-mbstring   \
        php8.1-memcache   \
        php8.1-mysql      \
        php8.1-opcache    \
        php8.1-readline   \
        # php8.1-redis      \
        php8.1-sqlite     \
        php8.1-tidy       \
        php8.1-xdebug     \
        php8.1-xml        \
        php8.1-zip        \
        php8.1-soap       \
        gcc               \
        make              \
        autoconf          \
        libc-dev          \
        pkg-config        \
        php8.1-dev        \
        libmcrypt-dev
        # php8.1-xhprof

# phpredis
ENV PHPREDIS_VERSION='5.3.7'
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
COPY ./conf/php/mods-available/redis.ini /etc/php/8.1/mods-available/redis.ini

# NGNIX
RUN apt-get update && \
    DEBIAN_FRONTEND="noninteractive" apt-get install --yes \
        nginx

# SSH (for remote drush)
RUN apt-get update && \
    DEBIAN_FRONTEND="noninteractive" apt-get install --yes \
        openssh-server
RUN dpkg-reconfigure openssh-server

# Install utilitarian packages.
RUN apt -y install curl dirmngr apt-transport-https lsb-release ca-certificates gcc g++ make

RUN curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/$NVM_VERSION/install.sh | bash \
    && echo "\. "/root/.nvm/nvm.sh"" >> /root/.bashrc \
    && echo "\. "/root/.nvm/bash_completion"" >> /root/.bashrc \
    && echo "export PATH=~/.nvm/versions/node/v\$NODE_VERSION/bin:$PATH" >> /root/.bashrc

# Install Node 12.
RUN echo "source /root/.nvm/nvm.sh && \
    nvm install $NODE_VERSION && \
    nvm alias default $NODE_VERSION && \
    nvm use default" | bash
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
    mv composer.phar /usr/local/bin/composer

# Install terminus.
RUN mkdir $HOME/terminus && cd $HOME/terminus && \
    curl -L https://github.com/pantheon-systems/terminus/releases/download/$TERMINUS_VERSION/terminus.phar --output terminus && \
    chmod +x terminus && \
    ./terminus self:update && \
    ln -s $HOME/terminus/terminus /usr/bin/terminus

# Install drush globally.
RUN composer global require drush/drush:$DRUSH_VERSION && \
    ln -s $HOME/.config/composer/vendor/bin/drush /usr/local/bin/drush

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
RUN cp /etc/php/8.1/fpm/php.ini /etc/php/8.1/fpm/php.ini.bak
COPY ./conf/php/fpm/php.ini-development /etc/php/8.1/fpm/php.ini
# COPY /conf/php/fpm/php.ini-production /etc/php/8.1/fpm/php.ini
RUN cp /etc/php/8.1/fpm/pool.d/www.conf /etc/php/8.1/fpm/pool.d/www.conf.bak
COPY /conf/php/fpm/pool.d/www.conf /etc/php/8.1/fpm/pool.d/www.conf
RUN cp /etc/php/8.1/cli/php.ini /etc/php/8.1/cli/php.ini.bak
COPY /conf/php/cli/php.ini-development /etc/php/8.1/cli/php.ini
# COPY /conf/php/cli/php.ini-production /etc/php/8.1/cli/php.ini
# Prevent php warnings
RUN sed -ir 's@^#@//@' /etc/php/8.1/mods-available/*
RUN phpenmod \
    redis  \
    soap
    # xhprof

RUN pecl install mcrypt-1.0.4 -y
RUN echo extension=mcrypt.so >> /etc/php/8.1/fpm/php.ini
RUN echo extension=mcrypt.so >> /etc/php/8.1/cli/php.ini

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
