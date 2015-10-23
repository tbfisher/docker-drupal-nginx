# http://phusion.github.io/baseimage-docker/
# https://github.com/phusion/baseimage-docker/blob/master/Changelog.md
FROM phusion/baseimage:0.9.17

MAINTAINER Brian Fisher <tbfisher@gmail.com>

RUN locale-gen en_US.UTF-8
ENV LANG       en_US.UTF-8
ENV LC_ALL     en_US.UTF-8

# Use baseimage-docker's init system.
CMD ["/sbin/my_init"]

# PHP cli/fpm
RUN add-apt-repository ppa:ondrej/php5-5.6 && \
    apt-get update && \
    DEBIAN_FRONTEND="noninteractive" apt-get install --yes \
        php-pear        \
        php5-cli        \
        php5-common     \
        php5-curl       \
        php5-fpm        \
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
        php5-tidy       \
        php5-xdebug
RUN php5enmod mcrypt

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

# Drush
ENV DRUSH_VERSION='7.1.0'
RUN apt-get update && \
    DEBIAN_FRONTEND="noninteractive" apt-get install --yes \
        mysql-client    \
        git
RUN curl -sS https://getcomposer.org/installer | \
    php -- --install-dir=/usr/local/bin --filename=composer
RUN git clone -b $DRUSH_VERSION --depth 1 https://github.com/drush-ops/drush.git /usr/local/src/drush
RUN cd /usr/local/src/drush && composer install
RUN ln -s /usr/local/src/drush/drush /usr/local/bin/drush
RUN drush -y dl --destination=/usr/local/src/drush/commands registry_rebuild
COPY ./conf/drush/drush-remote.sh /usr/local/bin/drush-remote
RUN chmod +x /usr/local/bin/drush-remote

# Configure
RUN mkdir /var/www_files && \
    chgrp www-data /var/www_files && \
    chmod 775 /var/www_files
COPY ./conf/php5/fpm/php.ini /etc/php5/fpm/php.ini
COPY ./conf/php5/cli/php.ini /etc/php5/cli/php.ini
COPY ./conf/nginx/default /etc/nginx/sites-available/default
COPY ./conf/nginx/nginx.conf /etc/nginx/nginx.conf
COPY ./conf/ssh/sshd_config /etc/ssh/sshd_config

# Use baseimage-docker's init system.
ADD init/ /etc/my_init.d/
ADD services/ /etc/service/
RUN chmod -v +x /etc/service/*/run
RUN chmod -v +x /etc/my_init.d/*.sh

EXPOSE 80 443 22

# Clean up
RUN apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*
