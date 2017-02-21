# dit4c-routing-server

[![Build Status](https://travis-ci.org/dit4c/dit4c-routingserver-ssh.svg?branch=master)](https://travis-ci.org/dit4c/dit4c-routingserver-ssh)

A routing server for DIT4C, based on SSH. It uses [NGINX](https://nginx.org/) to proxy requests, and reverse port forwarding over unix domain sockets to expose instances. Authentication is via PGP-based SSH keys, fetched from a configured server.

Used with [dit4c-helper-listener-ssh](https://github.com/dit4c/dit4c-helper-listener-ssh/). It can also be used stand-alone against any repository of PGP keys.

(It would also be trivial to rewrite `etc/confd/templates/register-login` to work with GitHub's SSH key API using `curl` + `jq`, as this was used during initial PoC testing.)

## How it works

### Starting the server

The following environment variables must be set when running the ACI:

 * ROUTING_SCHEME - "http" or "https". Used for calculating end-user URL.
 * ROUTING_DOMAIN - base domain, where end-user subdomains are `<REMOTE_USER>.<ROUTING_DOMAIN>`
 * PGP_LOOKUPURL - URL template for looking up PGP keys, where `<REMOTE_USER>` is the identity provided during registration. eg. `https://dit4c.net/instances/<REMOTE_USER>/pgp-keys`

Optionally, `TLS_KEY` and `TLS_CERT` can be provided to allow the ACI do expose HTTPS.

eg. To run via HTTP using [rkt](https://github.com/coreos/rktgit ):

```
/usr/bin/rkt run \
  --dns=8.8.8.8 \
  --port http:80 \
  --port ssh:2222 \
  https://github.com/dit4c/dit4c-routingserver-ssh/releases/download/v0.1.2/dit4c-routingserver-ssh.linux.amd64.aci \
  --set-env ROUTING_SCHEME=http \
  --set-env ROUTING_DOMAIN=routing-domain.example \
  --set-env PGP_LOOKUPURL='https://dit4c-server.example/instances/<REMOTE_USER>/pgp-keys'
```

### Client interaction

To connect, the client performs an initial connection with the registration user:

```
ssh -i $SSH_PRIVATE_KEY -p $SSH_PORT register@$SSH_HOST $REMOTE_USER
```

The server accepts any private key for this step. It uses the value of `REMOTE_USER` (via [SSH_ORIGINAL_COMMAND](http://man.openbsd.org/cgi-bin/man.cgi/OpenBSD-current/man1/ssh.1#ENVIRONMENT)) with `PGP_LOOKUPURL` to perform a `GET` request for [application/pgp-keys](https://tools.ietf.org/html/rfc3156#section-7) content. All PGP keys [capable of authentication](https://tools.ietf.org/html/rfc4880#section-5.2.3.21) will be converted to SSH keys and associated with the `REMOTE_USER` value provided. The server then terminates the session.

The client then reconnects for listening using one of the registered SSH keys:

```
ssh -i $SSH_PRIVATE_KEY \
    -o "ServerAliveInterval 30" \
    -R $SOCKET:$TARGET_HOST:$TARGET_PORT \
    -p $SSH_PORT \
    listen@$SSH_HOST $SOCKET
```

The filepath picked for `SOCKET` (the [UNIX domain socket](https://en.wikipedia.org/wiki/Unix_file_types#Socket) on the server) should generally start with `/tmp/`, and for security reasons should not be easily guessable. On connection, the server uses the client private key to look up the `REMOTE_USER`, and creates a symlink so NGINX can reverse-proxy traffic to the provided UNIX socket.
