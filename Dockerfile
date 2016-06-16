FROM scratch

ENV container docker
ENV DEBIAN_FRONTEND noninteractive

# debootstrap --variant=minbase --components=main vivid ./rootfs
ADD debootstrap-minbase.tgz /
ADD etc/apt/sources.list /etc/apt/sources.list

# setup locale and timezone
RUN locale-gen en_US.UTF-8 \
 && update-locale LANG=en_US.UTF-8 \
 \
 && echo "UTC" > /etc/timezone \
 && dpkg-reconfigure tzdata

# tweaks for docker from mkimage.sh
# https://github.com/docker/docker/blob/master/contrib/mkimage/debootstrap
RUN rm -f /etc/apt/apt.conf.d/01autoremove-kernels \
 \
 #&& echo '#!/bin/sh' > /usr/sbin/policy-rc.d \
 #&& echo 'exit 101' >> /usr/sbin/policy-rc.d \
 #&& chmod +x /usr/sbin/policy-rc.d \
 #\
 #&& dpkg-divert --local --rename --add /sbin/initctl \
 #&& cp -a /usr/sbin/policy-rc.d /sbin/initctl \
 #&& sed -i 's/^exit.*/exit 0/' /sbin/initctl \
 #\
 #&& echo 'force-unsafe-io' > /etc/dpkg/dpkg.cfg.d/docker-apt-speedup \
 \
 && echo 'DPkg::Post-Invoke { "rm -f /var/cache/apt/archives/*.deb /var/cache/apt/archives/partial/*.deb /var/cache/apt/*.bin || true"; };' > /etc/apt/apt.conf.d/docker-clean \
 && echo 'APT::Update::Post-Invoke { "rm -f /var/cache/apt/archives/*.deb /var/cache/apt/archives/partial/*.deb /var/cache/apt/*.bin || true"; };' >> /etc/apt/apt.conf.d/docker-clean \
 && echo 'Dir::Cache::pkgcache "";' >> /etc/apt/apt.conf.d/docker-clean \
 && echo 'Dir::Cache::srcpkgcache "";' >> /etc/apt/apt.conf.d/docker-clean \
 \
 && echo 'Acquire::Languages "none";' > /etc/apt/apt.conf.d/docker-no-languages \
 \
 && echo 'Acquire::GzipIndexes "true";' > /etc/apt/apt.conf.d/docker-gzip-indexes \
 && echo 'Acquire::CompressionTypes::Order:: "gz";' > /etc/apt/apt.conf.d/docker-gzip-indexes \
 \
 && echo 'Apt::AutoRemove::SuggestsImportant "false";' > /etc/apt/apt.conf.d/docker-autoremove-suggests

# tweaks for systemd
RUN systemctl mask -- \
    -.mount \
    dev-mqueue.mount \
    dev-hugepages.mount \
    etc-hosts.mount \
    etc-hostname.mount \
    etc-resolv.conf.mount \
    proc-bus.mount \
    proc-irq.mount \
    proc-kcore.mount \
    proc-sys-fs-binfmt_misc.mount \
    proc-sysrq\\\\x2dtrigger.mount \
    sys-fs-fuse-connections.mount \
    sys-kernel-config.mount \
    sys-kernel-debug.mount \
    tmp.mount \
 \
 && systemctl mask -- \
    console-getty.service \
    display-manager.service \
    getty-static.service \
    getty\@tty1.service \
    hwclock-save.service \
    ondemand.service \
    systemd-logind.service \
    systemd-remount-fs.service \
 \
 && ln -sf /lib/systemd/system/multi-user.target /etc/systemd/system/default.target \
 \
 && ln -sf /lib/systemd/system/halt.target /etc/systemd/system/sigpwr.target

# workarounds for common problems
RUN echo "resolvconf resolvconf/linkify-resolvconf boolean false" | debconf-set-selections

# upgrade OS
RUN apt-get update -qq \
 && apt-get upgrade --yes --force-yes

# system packages
RUN apt-get update -qq \
 && apt-get install -y \
    rsyslog \
    systemd \
    systemd-cron \
 \
 && sed -i 's/^\($ModLoad imklog\)/#\1/' /etc/rsyslog.conf

ADD etc/rsyslog.d/50-default.conf /etc/rsyslog.d/50-default.conf

# mount read-only `cgroup name=systemd` (see `README`.md)
VOLUME ["/sys/fs/cgroup"]

# mount tmpfs in `/run` and `/run/lock` (see `README.md`)
VOLUME ["/run"]

# run: docker run -d --name xxx -v /tmp/cgroup:/sys/fs/cgroup:ro -v /tmp/run:/run:rw ubuntu-systemd
# stop: docker kill --signal SIGPWR xxx && docker stop xxx

CMD ["/sbin/init"]
