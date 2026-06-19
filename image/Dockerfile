FROM docker.io/library/archlinux:base-devel
ARG ARCHBOX_USER
ARG ARCHBOX_UID
ARG ARCHBOX_SUDO_PASSWORD
ARG ARCHBOX_ROOT_PASSWORD

COPY ./sysroot/etc/pacman.conf /etc/

# add archpkgs repo
RUN set -euo pipefail && pacman-key --init && curl -sSf https://raw.githubusercontent.com/dadevel/archpkgs/main/signature.gpg | pacman-key --add - && pacman-key --lsign-key admin@archpkgs.net
RUN pacman -Syu --noconfirm

# make bootable, '--needed' is omitted on purpose, because 'glibc' must be reinstalled to get missing locales
RUN grep -v -e '^#' << EOF | xargs -r pacman -S --noconfirm
core/base
core/base-devel
core/efibootmgr
core/glibc
core/linux
core/mkinitcpio
extra/pacman-contrib
EOF

# install tools from default arch repositories
# @TODO: adjust to your liking
RUN grep -v -e '^#' << EOF | xargs -r pacman -S --needed --noconfirm
# basic tools
core/bash
core/ca-certificates
core/gnupg
core/less
core/man-db
core/man-pages
core/openssh
core/sudo
core/util-linux
extra/7zip
extra/anewer
extra/bash-completion
extra/bat
extra/borg
extra/dos2unix
extra/eza
extra/fd
extra/fzf
extra/git
extra/git-delta
extra/git-lfs
extra/hexyl
extra/htop
extra/imagemagick
extra/jq
extra/minicom
extra/neovim
extra/parallel
extra/progress
extra/pv
extra/qemu-img
extra/qrencode
extra/rclone
extra/ripgrep
extra/rsync
extra/sshfs
extra/stow
extra/tinyxxd
extra/tmux
extra/tree-sitter
extra/tree-sitter-bash
extra/tree-sitter-c
extra/tree-sitter-cli
extra/tree-sitter-javascript
extra/tree-sitter-lua
extra/tree-sitter-markdown
extra/tree-sitter-python
extra/tree-sitter-query
extra/tree-sitter-rust
extra/tree-sitter-vim
extra/tree-sitter-vimdoc
extra/yq
extra/zbar

# networking tools
core/curl
core/iproute2
core/iptables
extra/bind
extra/dog
extra/nftables
extra/openbsd-netcat
extra/openvpn
extra/tailscale
extra/tcpdump
extra/traceroute
extra/wget
extra/wireguard-tools

# containerization
extra/aardvark-dns
extra/crun
extra/docker
extra/docker-buildx
extra/docker-compose
extra/netavark
extra/passt
extra/podman

# development
# go
extra/go
# python
core/python
extra/pyright
extra/python-pip
extra/python-requests
extra/uv
# java, also needed for burp
extra/jdk-openjdk
# yaml
extra/yaml-language-server

# gui support packages
extra/hunspell-de
extra/hunspell-en_us
extra/noto-fonts
extra/noto-fonts-cjk
extra/noto-fonts-emoji
extra/noto-fonts-extra
extra/pipewire
extra/pipewire-pulse
extra/spice-vdagent
extra/udisks2
extra/wireplumber
extra/xclip
extra/xf86-video-qxl
extra/xorg-xrandr

# kde
# sddm needed because spice-vdagent is broken in a plasma session started directly from tty
extra/breeze
extra/kscreen
extra/plasma-desktop
extra/plasma-x11-session
extra/sddm
extra/spectacle
extra/xdg-desktop-portal-kde

# gui programs
extra/chromium
extra/firefox
extra/geckodriver
extra/gimp
extra/kitty
extra/meld

# pentest cli tools
core/krb5
core/nfs-utils
core/openldap
core/openssl
extra/android-tools
extra/aws-cli
extra/azure-cli
extra/binwalk
extra/curl-impersonate
extra/hashcat
extra/hping
extra/john
extra/kubectl
extra/lftp
extra/mariadb-clients
extra/masscan
extra/medusa
extra/metasploit
extra/net-snmp
extra/nginx
extra/nload
extra/nmap
extra/ntp
extra/perl-image-exiftool
extra/postgresql-libs
extra/proxychains-ng
extra/putty
extra/skopeo
extra/smbclient
extra/socat
extra/sqlmap
extra/swaks
extra/testssl.sh
extra/tftp-hpa
extra/valkey
extra/whois
extra/wpscan

# pentest gui tools
extra/freerdp
extra/ghidra
extra/tigervnc
extra/wireshark-qt
EOF

# install archpkgs tools, work around weird exit code 123 problem
# @TODO: adjust to your liking
RUN while read -r line; do pacman -S --needed --noconfirm "$line"; done << EOF
archpkgs/adidnsdump
archpkgs/asnmap
archpkgs/azurehound
archpkgs/bloodhound-python
archpkgs/bloodyad
archpkgs/certipy
archpkgs/certipy-bloodhound
archpkgs/certipy-merged
archpkgs/coercer
archpkgs/defaultcreds-cheat-sheet
archpkgs/dnsx
archpkgs/donpapi
archpkgs/evil-winrm-py
archpkgs/exrex
archpkgs/feroxbuster
archpkgs/ffuf
archpkgs/getfgpp
archpkgs/goshs
archpkgs/gowitness
archpkgs/httpx
archpkgs/iker
archpkgs/impacket-stable
archpkgs/impacket-unstable
archpkgs/katana
archpkgs/krbjack
archpkgs/krbrelayx
archpkgs/mapcidr
archpkgs/massdns
archpkgs/mitm6
archpkgs/msldap
archpkgs/name-that-hash
archpkgs/nuclei
archpkgs/paru
archpkgs/peas
archpkgs/petitpotam
archpkgs/pkinittools
archpkgs/pretender
archpkgs/prox-ez
archpkgs/puredns
archpkgs/pypykatz
archpkgs/responder
archpkgs/roadtools
archpkgs/roadtools-hybrid
archpkgs/sccmhunter
archpkgs/sccmsecrets
archpkgs/shortscan
archpkgs/shuffledns
archpkgs/smbclient-ng
archpkgs/subfinder
archpkgs/tlsx
archpkgs/unfurl
archpkgs/vulnx
EOF

# clean up in package cache
RUN paccache --remove

# remove default kerberos config
RUN rm /etc/krb5.conf

# generate fstab
RUN cat << EOF > /etc/fstab
# managed by administrator
project /home/$ARCHBOX_USER/project virtiofs nofail,nodev,nosuid 0 0
share /home/$ARCHBOX_USER/share virtiofs nofail,nodev,nosuid 0 0
EOF

# copy over config files from sysroot dir
COPY ./sysroot/. /
RUN chmod 0440 /etc/sudoers

# place bootloader in boot partition
RUN cp /usr/lib/systemd/boot/efi/systemd-bootx64.efi /boot/EFI/BOOT/BOOTX64.efi && cp /usr/lib/systemd/boot/efi/systemd-bootx64.efi /boot/EFI/systemd/systemd-bootx64.efi

# reenable pacman sandbox, must be disabled inside podman
RUN sed -i 's|^DisableSandbox|#DisableSandbox|' /etc/pacman.conf

# regenerate locales
RUN locale-gen

# enable systemd services
RUN systemctl enable docker.socket sddm.service systemd-networkd.service systemd-resolved.service systemd-timesyncd.service

# set capabilities for rootless usage
RUN for file in /usr/bin/nmap /usr/bin/hping3 /usr/bin/masscan; do if [[ -f "$file" ]]; then setcap CAP_NET_RAW=ep "$file"; fi; done

# configure authentication for root
RUN echo "root:$ARCHBOX_ROOT_PASSWORD" | chpasswd -e
COPY ./archbox.pub /root/.ssh/authorized_keys

# add regular user
RUN useradd --create-home --user-group --groups audio,input,video,wheel --uid "$ARCHBOX_UID" --shell /bin/bash --password "$ARCHBOX_SUDO_PASSWORD" "$ARCHBOX_USER"
COPY ./archbox.pub /home/$ARCHBOX_USER/.ssh/authorized_keys
RUN mkdir "/home/$ARCHBOX_USER/project" "/home/$ARCHBOX_USER/share" && chown -R "$ARCHBOX_USER:$ARCHBOX_USER" "/home/$ARCHBOX_USER"

# enable persistent systemd user session
RUN mkdir -p /var/lib/systemd/linger && touch "/var/lib/systemd/linger/$ARCHBOX_USER"

# change context from root to regular user for remaining build process
USER $ARCHBOX_USER
WORKDIR /home/$ARCHBOX_USER

# install python tools missing in archpkgs
# @TODO: adjust to your liking
RUN uv tool install git+https://github.com/cogiceo/gpohound.git && \
uv tool install git+https://github.com/dadevel/bloodhoundcli.git && \
uv tool install git+https://github.com/dadevel/chrome-remote.git && \
uv tool install git+https://github.com/dadevel/http-ping.git && \
uv tool install git+https://github.com/dadevel/http-spray.git && \
uv tool install git+https://github.com/dadevel/jenkins-decryptor.git && \
uv tool install git+https://github.com/dadevel/krb-spray.git && \
uv tool install git+https://github.com/dadevel/mssql-spider.git && \
uv tool install git+https://github.com/dadevel/nmap2json.git && \
uv tool install git+https://github.com/dadevel/prtg-decryptor.git && \
uv tool install git+https://github.com/dadevel/servicedetector.git && \
uv tool install git+https://github.com/dadevel/shells.git && \
uv tool install git+https://github.com/redbyte1337/graphspy.git && \
uv tool install git+https://github.com/rhinosecuritylabs/pacu.git && \
uv tool install git+https://github.com/synacktiv/ntdissector.git && \
uv tool install --python cpython-3.12.13-linux-x86_64-gnu git+https://github.com/pennyw0rth/netexec.git@v1.5.1

# install private tools
# @TODO: adjust to your liking
RUN --mount=from=work,target=/work \
uv tool install /work/tool1 && \
uv tool install /work/tool2 && \
uv tool install /work/tool3

# enable podman user socket
RUN mkdir -p ~/.config/systemd/user/sockets.target.wants && \
ln -s /usr/lib/systemd/user/podman.socket ~/.config/systemd/user/sockets.target.wants/podman.socket

# somehow required to get dynamic resolution working
RUN cat << EOF > .xsession && chmod +x .xsession
#!/bin/sh
# managed by administrator

sleep 5 && xrandr --output Virtual-1 --auto &
EOF

# disable lockscreen
RUN cat << EOF > .config/kscreenlockerrc
# managed by administrator

[Daemon]
Autolock=false
LockOnResume=false
Timeout=0
EOF

# add dotfiles
# @TODO: adjust to your environment
COPY --from=dotfiles --chown=$ARCHBOX_USER bash/.bashrc .
COPY --from=dotfiles --chown=$ARCHBOX_USER bash/.local/share/impacket-shell-integration/ .local/share/impacket-shell-integration/
COPY --from=dotfiles --chown=$ARCHBOX_USER bash/.inputrc .
COPY --from=dotfiles --chown=$ARCHBOX_USER tmux/.tmux.conf .
COPY --from=dotfiles --chown=$ARCHBOX_USER git/.config/git/config .config/git/
COPY --from=dotfiles --chown=$ARCHBOX_USER kitty/.config/kitty/ .config/kitty/
COPY --from=dotfiles --chown=$ARCHBOX_USER nvim/.config/nvim/ .config/nvim/

# install neovim packages
RUN nvim --headless '+Lazy! sync' +qa
