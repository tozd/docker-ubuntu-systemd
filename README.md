docker-ubuntu-systemd
=====================

***ubuntu-systemd*** is a minimal [*Ubuntu*](http://www.ubuntu.com/) system with *systemd* designed for running in unprivileged [*Docker*](http://www.docker.com/) containers. Main philosophy:

- simple to use and maintain, same system management experience
- transparent build process, unlike "official" *Ubuntu* images
- treat containers as VMs, multiple processes inside a single container

You can use it as a base for your own *Docker* images. Just pull it from [the *Docker registry*](http://registry.hub.docker.com/u/tozd/ubuntu-systemd/)!


Usage
=====

To run *systemd* in an unprivileged container a few manual tweaks are currently necessary. Remember to replace `/tmp` in following commands to a non-world-readable directory.

First it depends on the *cgroups* directory, at least it needs read-only access to `cgroup name=systemd` hierarchy (in `/sys/fs/cgroup/systemd`). Lets prepare **one for all** *ubuntu-systemd* containers:

```bash
$ mkdir /tmp/cgroup /tmp/cgroup/systemd && mount --bind /sys/fs/cgroup/systemd /tmp/cgroup/systemd
```

Next it needs *tmpfs* mount points in `/run` and `/run/lock`. This needs to be prepared **separately for each** *ubuntu-systemd* container:

```bash
$ mkdir /tmp/run && mount -t tmpfs tmpfs /tmp/run
$ mkdir /tmp/run/lock && mount -t tmpfs tmpfs /tmp/run/lock
```

You could also add all mount points permanently to your `/etc/fstab`:

```
/sys/fs/cgroup/systemd  /tmp/cgroup/systemd  none  bind
tmpfs  /tmp/run  tmpfs  nodev,nosuid,mode=755,size=65536k
tmpfs  /tmp/run/lock  tmpfs  nodev,nosuid,mode=755,size=65536k
```

Then you are **ready to use** your *Docker* container:

```bash
$ docker run -d --name xxx -v /tmp/cgroup:/sys/fs/cgroup:ro -v /tmp/run:/run:rw tozd/ubuntu-systemd
$ docker exec -it xxx /bin/bash
```

Please note that **graceful stopping** and removal of the *Docker* container looks a little different now:

```bash
$ docker kill --signal SIGPWR xxx && docker stop xxx

$ docker rm -f xxx
$ umount /tmp/run/lock /tmp/run && rmdir /tmp/run
$ umount /tmp/cgroup/systemd && rmdir /tmp/cgroup/systemd /tmp/cgroup
```


Build
=====

Build `ubuntu-systemd`
----------------------

All instructions from scratch are included in the `Dockerfile`. To build it you just need to run:

```bash
$ git clone http://github.com/tozd/docker-ubuntu-systemd.git
$ docker build -t ubuntu-systemd ./docker-ubuntu-systemd
```


Build `debootstrap-minbase.tgz`
-------------------------------

The standard *debootstrap* tool is used to generate the initial minimal *Ubuntu* system. As we are using *Docker*, we can build the base image there without installing anything on the host:

```bash
$ mkdir /tmp/ubuntu-systemd
$ docker run -it --rm --privileged -v /tmp/ubuntu-systemd:/mnt ubuntu /bin/bash

$ cd /mnt
$ apt-get update && apt-get install -y debootstrap

$ debootstrap --variant=minbase --components=main vivid ./rootfs
$ rm -f ./rootfs/var/cache/apt/archives/*.deb ./rootfs/var/cache/apt/archives/partial/*.deb ./rootfs/var/cache/apt/*.bin

$ tar --numeric-owner -zcf "debootstrap-minbase.tgz" -C "./rootfs" . && rm -rf "./rootfs"
$ exit
```


Feedback
========

If you encounter any bugs or have feature requests, please file them in the [issue tracker](http://github.com/tozd/docker-ubuntu-systemd/issues/) or even develop it yourself and submit a pull request over [GitHub](http://github.com/tozd/docker-ubuntu-systemd/).


License
=======

Copyright &copy; 2015 *gw0* [<http://gw.tnode.com/>] &lt;<gw.2015@tnode.com>&gt;

This library is licensed under the [GNU Affero General Public License 3.0+](LICENSE_AGPL-3.0.txt) (AGPL-3.0+). Note that it is mandatory to make all modifications and complete source code of this library publicly available to any user.


Related
-------

- <http://github.com/docker/docker/pull/13525>
- <http://github.com/maci0/docker-systemd-unpriv/blob/master/Dockerfile>
- <http://github.com/lxc/lxc/blob/master/templates/lxc-debian.in>
- <http://github.com/docker/docker/blob/master/contrib/mkimage/debootstrap>
- <http://github.com/tianon/docker-brew-ubuntu-core/blob/67accc07b2f77dbf00dc4e2d5b90c00abc225ec6/vivid/Dockerfile>
