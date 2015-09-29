# http://phusion.github.io/baseimage-docker/
# https://github.com/phusion/baseimage-docker/blob/master/Changelog.md
#FROM phusion/baseimage:<VERSION>
FROM phusion/baseimage

RUN locale-gen en_US.UTF-8
ENV LANG       en_US.UTF-8
ENV LC_ALL     en_US.UTF-8

# Use baseimage-docker's init system.
CMD ["/sbin/my_init"]

# PHP cli/fpm
RUN apt-get update && \
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
RUN curl -sS https://getcomposer.org/installer | \
    php -- --install-dir=/usr/local/bin --filename=composer
RUN composer global require drush/drush:7 --prefer-dist
RUN ln -sf /root/.composer/vendor/bin/drush.php /usr/local/bin/drush

# Configure
COPY ./conf/php5/fpm/php.ini /etc/php5/fpm/php.ini
COPY ./conf/php5/cli/php.ini /etc/php5/cli/php.ini
COPY ./conf/nginx/default /etc/nginx/sites-available/default
COPY ./conf/nginx/nginx.conf /etc/nginx/nginx.conf
COPY ./conf/ssh/sshd_config /etc/ssh/sshd_config
COPY ./conf/ssh/id_rsa.pub /root/.ssh/authorized_keys

# Use baseimage-docker's init system.
ADD init/ /etc/my_init.d/
ADD services/ /etc/service/
RUN chmod -v +x /etc/service/*/run
RUN chmod -v +x /etc/my_init.d/*.sh

EXPOSE 80 443 22

# Clenn up
RUN apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*
