This is a patched version of u9fs, for use with Alpine Linux.

It removes the default `rhosts` authtype, which requires `ruserok(3)`. By removing it, we lose nothing (we're using the `none` authtype) and it simplifies compilation considerably.

The binary was compiled from commit [f900662fbd6162baeb12ec53faf913ea1e2058be](https://bitbucket.org/plan9-from-bell-labs/u9fs/commits/f900662fbd6162baeb12ec53faf913ea1e2058be) which can be downloaded from:
<https://bitbucket.org/plan9-from-bell-labs/u9fs/get/f900662fbd61.zip>
