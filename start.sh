#!/bin/sh
set -e

# Enforce assumption that /dev/shm is not sticky
chmod 0755 /dev/shm

export SSH_KEYDIR=${SSH_KEYDIR:-/dev/shm/ssh_host_keys}
export PGP_CACHEDIR=${PGP_CACHEDIR:-/dev/shm/connect_keys}
export STORAGE_ROOT=${STORAGE_ROOT:-/data}

# Create host key if necessary
mkdir -p $SSH_KEYDIR
test -e $SSH_KEYDIR/ssh_host_rsa_key || ssh-keygen -q -t rsa -N '' -f $SSH_KEYDIR/ssh_host_rsa_key

# Create directory for connect account keys
mkdir -p $PGP_CACHEDIR
chown register $PGP_CACHEDIR

# Permissions on data
mkdir -p "${STORAGE_ROOT}/instances"
mkdir -p "${STORAGE_ROOT}/users"
chown register:fileserver "${STORAGE_ROOT}/instances" "${STORAGE_ROOT}/users"

mkdir -p /dev/shm/bin
# Generate nginx config & register-login
confd -onetime -backend env

# Check configs (fail fast)
/usr/sbin/sshd -t -f /dev/shm/sshd_config

# Start services
exec /bin/s6-svscan /etc/services.d
