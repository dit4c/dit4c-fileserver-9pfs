#!/bin/sh

set -ex

# Configure DNS
rm /etc/resolv.conf
echo nameserver 8.8.8.8 > /etc/resolv.conf

# Install packages
apk update
apk add curl gnupg openssh s6
rm -rf /var/cache/apk/*

# Correct file ownerships
chown -R root:root /etc/confd /usr/local/bin/* /start.sh

# Create SSH users
addgroup -g 2000 fileserver
adduser -u 2001 -D connect -G fileserver -s /bin/sh && passwd -u connect
adduser -u 2002 -D register -G fileserver -s /bin/sh && passwd -u register

# register user will be using GPG - ensure base files exists
su - register -c 'gpg2 --list-keys'

# Cleanup DNS config
rm -f /etc/resolv.conf
