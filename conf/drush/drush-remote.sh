#!/bin/bash

# sudo -u www-data -- drush $@
# https://github.com/phusion/baseimage-docker
/sbin/setuser www-data drush $@
