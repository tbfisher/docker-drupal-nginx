# Docker Nginx for Drupal

Nginx and PHP-fpm configured for Drupal, with

-   [Xdebug](https://xdebug.org/)
-   [Mailhog](https://github.com/mailhog/MailHog) support

Tags:

-   latest, php-5.5 - Ubuntu default
-   php-5.5.x       - Latest 5.5 from ppa:ondrej
-   php-5.6.x       - Latest 5.6 from ppa:ondrej
-   php-7.0.x       - Latest 7.0 from ppa:ondrej

See [Drupal Development with Docker Compose | Chapter Three](https://www.chapterthree.com/blog/drupal-development-docker-compose).

## Build

Extend this container as needed, with a `Dockerfile`

```dockerfile
FROM tbfisher/drupal-nginx:php-5.6.x

# Configure files directory.
RUN mkdir -p /var/www_files/public && \
    mkdir -p /var/www_files/private && \
    chown -R www-data:www-data /var/www_files

# Direct ssh access to container.
COPY ./conf/ssh/authorized_keys /root/.ssh/authorized_keys
```

Use docker compose:

```yaml
mysql:
  # https://github.com/docker-library/docs/blob/master/mysql/README.md
  image: mysql:5.5
  environment:
    MYSQL_ROOT_PASSWORD: drupal-password
    MYSQL_DATABASE: drupal
  ports:
    - "3306"

mail:
  # https://hub.docker.com/r/mailhog/mailhog/
  image: mailhog/mailhog
  ports:
   - "1025"
   - "8025"

web:
  # this references the dockerfile above
  build: ../../build/drupal-nginx-php56x
  ports:
   - "80"
   - "443"
   - "22"
  volumes:
   - /path/to/drupal/codebase:/var/www
  links:
   - mysql
   - mail
```

Note PHP in this build is configured to send mail to a mailhog container, which captures any outgoing mail and exposes a UI on port 8025.
