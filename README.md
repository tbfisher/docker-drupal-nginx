# Docker Nginx for Drupal

Nginx and PHP-fpm configured for Drupal, with

-   [Drush](https://github.com/drush-ops/drush)
-   [Drupal Console](https://drupalconsole.com/)
-   [Xdebug](https://xdebug.org/)
-   [Mailhog](https://github.com/mailhog/MailHog) support

Tags:

-   latest, php-7.1.x - Latest 7.1 from ppa:ondrej
-   php-7.0.x         - Latest 7.0 from ppa:ondrej
-   php-5.6.x         - Latest 5.6 from ppa:ondrej
-   php-5.5.x         - Latest 5.5 from ppa:ondrej

See [Drupal Development with Docker Compose | Chapter Three](https://www.chapterthree.com/blog/drupal-development-docker-compose).

## Build

Extend this container as needed, with a `Dockerfile`

```dockerfile
FROM tbfisher/drupal-nginx:php-5.6.x

# Configure files directory.
RUN mkdir -p /var/www_files/public && \
    mkdir -p /var/www_files/private && \
    chown -R www-data:www-data /var/www_files
```

Use docker compose:

```yaml
version: '2'
services:

  database:
    image: mariadb:5.5
    networks:
      - backend

  mail:
    image: mailhog/mailhog
    networks:
      - backend

  web:
    build: ../my-drupal-nginx
    ports:
      - "22"
    volumes:
      - "./code:/var/www:rw"
      - "files_public:/var/www_files/public:rw"
      - "files_private:/var/www_files/private:rw"
      - "ssh:/root/.ssh:rw"
    networks:
      - backend

networks:
  backend:
    driver: bridge

volumes:
  database:
    driver: local
  files_public:
    driver: local
  files_private:
    driver: local
  ssh:
    driver: local
```

Note PHP in this build is configured to send mail to a mailhog container, which captures any outgoing mail and exposes a UI on port 8025.
