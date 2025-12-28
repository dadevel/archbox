FROM docker.io/library/archlinux:base-devel
ARG ARCHBOX_USER=user
ARG ARCHBOX_UID=1000

# add archpkgs repo
COPY ./pacman.conf /etc/
RUN set -euo pipefail && pacman-key --init && curl -sSf https://raw.githubusercontent.com/dadevel/archpkgs/main/signature.gpg | pacman-key --add - && pacman-key --lsign-key admin@archpkgs.net

# install system packages
COPY ./pkgs.txt /tmp/
RUN pacman -Syu --needed --noconfirm $(grep -v -e '^#' /tmp/pkgs.txt) && rm -f /tmp/pkgs.txt

# add user, username must be 'user' and uid should be 1000
RUN useradd --create-home --user-group --groups audio,input,video,wheel --uid "$ARCHBOX_UID" "$ARCHBOX_USER" && mkdir -p /home/"$ARCHBOX_USER"/{.cache,.config,.local/share/containers,.ssh} "/run/$ARCHBOX_USER/$ARCHBOX_UID" && chown -R "$ARCHBOX_USER:$ARCHBOX_USER" "/home/$ARCHBOX_USER" "/run/$ARCHBOX_USER/$ARCHBOX_UID"

# configure sudo
COPY ./sudoers /etc/

# configure nested rootless podman
COPY ./subuid ./subgid /etc/
COPY ./containers.conf ./storage.conf /etc/containers/
# see https://github.com/containers/podman/issues/2788#issuecomment-479923274
RUN setcap cap_setuid=ep /usr/bin/newuidmap && setcap cap_setgid=ep /usr/bin/newgidmap

# work around systemd failing to initialize machine id which results in broken dbus
COPY ./machine-id-setup.service /usr/local/lib/systemd/system/
COPY ./machine-id-setup.sh /usr/local/lib/
RUN systemctl enable machine-id-setup.service

# disable problematic systemd services
RUN systemctl mask systemd-firstboot.service systemd-resolved.service systemd-networkd.service

# use systemd as entrypoint
ENTRYPOINT ["/sbin/init"]
CMD []

# enable native overlayfs in container
VOLUME /var/lib/containers
VOLUME /home/$ARCHBOX_USER/.local/share/containers
