# Trustanchor container

This folder holds a trustanchor container which populates volumes
that can be mounted in the other services such to establish a trust 
framework based on X.509 server/user certificates created on-the-fly.

VOMS proxies are also created.

In partular, it populates the following volumes

* `/trust-anchors`: contains the `igi-test-ca` certificate (created
  on-the-fly), which is usually mounted in `/etc/grid-security/certificates`
* `/etc/pki/tls/certs`: it is the bundle for system certificates plus
  the `igi-test-ca` one
* `/vomsdir`: contains the LSC files used to validate the proxy attributes,
  generally mounted in 
  `/etc/grid-security/vomsdir`
* `/certs`: contains server/user X.509 certificates, emitted by the
  `igi-test-ca`. Also VOMS proxies are present here.

**Tip:** Some docker versions use a buildx image which caches some layer of the build image to speedup the container start time. This is in conflict with the creation with on-the-fly certificates. To disable this behavior, first
stop the container

```bash
$ docker ps
CONTAINER ID   IMAGE                           COMMAND                  CREATED             STATUS                         PORTS     NAMES
<container-id>   moby/buildkit:buildx-stable-1   "buildkitd"              2 weeks ago         Up 7 days                                buildx_buildkit_practical_dewdney0
$ docker stop <container-id>
$ docker rm <container-id>
```

and also the volume created by buildx

```bash
$ docker volume ls
DRIVER    VOLUME NAME
local     buildx_buildkit_practical_dewdney0_state
$ docker volume rm buildx_buildkit_practical_dewdney0_state
buildx_buildkit_practical_dewdney0_state
```

Then set

```bash
export DOCKER_BUILDKIT=0
```

(may be that you have to add it to your `~/.bashrc`).