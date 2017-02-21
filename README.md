# dit4c-fileserver-9pfs

[![Build Status](https://travis-ci.org/dit4c/dit4c-fileserver-9pfs.svg?branch=master)](https://travis-ci.org/dit4c/dit4c-fileserver-9pfs)

A file server for DIT4C, based on 9pfs tunneled via SSH. Authentication is via PGP-based SSH keys, fetched from a configured server.

Used with [dit4c-helper-storage-9pfs](https://github.com/dit4c/dit4c-helper-storage-9pfs/).

## How it works

### Starting the server

The following environment variables must be set when running the ACI:

 * DIT4C_PORTAL - Base URL for fetching PGP keys and instance creator ID

eg. To run using [rkt](https://github.com/coreos/rktgit ):

```
/usr/bin/rkt run \
  --dns=8.8.8.8 \
  --port ssh:2222 \
  --volume data,kind=host,source=/var/lib/fileserver \
  https://github.com/dit4c/dit4c-fileserver-9pfs/releases/download/v0.1.0/dit4c-fileserver-9pfs.linux.amd64.aci \
  --set-env DIT4C_PORTAL=https://dit4c.example
```

### Client interaction

To connect, the client performs an initial connection with the registration user:

```
ssh -i $SSH_PRIVATE_KEY -p $SSH_PORT register@$SSH_HOST $DIT4C_INSTANCE
```

The server accepts any private key for this step. It uses the value of `DIT4C_INSTANCE` (via [SSH_ORIGINAL_COMMAND](http://man.openbsd.org/cgi-bin/man.cgi/OpenBSD-current/man1/ssh.1#ENVIRONMENT)) with `DIT4C_PORTAL` to perform a `GET` request for [application/pgp-keys](https://tools.ietf.org/html/rfc3156#section-7) content. All PGP keys [capable of authentication](https://tools.ietf.org/html/rfc4880#section-5.2.3.21) will be converted to SSH keys and associated with the `DIT4C_INSTANCE` value provided. The server then terminates the session.

The client can then use `socat` to proxy requests via SSH using one of the registered SSH keys:

```
socat \
  TCP-LISTEN:564,bind=127.0.0.1,fork,reuseaddr \
  SYSTEM:"ssh -T -i $SSH_PRIVATE_KEY -o 'ServerAliveInterval 30' -p $SSH_PORT connect@$SSH_HOST"
```

The server uses [u9fs](https://bitbucket.org/plan9-from-bell-labs/u9fs) to serve 9p2000 requests via stdin/stdout.
