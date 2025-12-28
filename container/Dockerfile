FROM docker.io/library/archlinux:base-devel
ARG ARCHBOX_USER=user
ARG ARCHBOX_UID=1000

# add user, username must be 'user' and uid should be 1000
RUN useradd --create-home --user-group --groups audio,input,video,wheel --uid "$ARCHBOX_UID" "$ARCHBOX_USER" && mkdir -p /home/"$ARCHBOX_USER"/{.cache,.config,.local/share/containers,.ssh,project} "/run/$ARCHBOX_USER/$ARCHBOX_UID" && chown -R "$ARCHBOX_USER:$ARCHBOX_USER" "/home/$ARCHBOX_USER" "/run/$ARCHBOX_USER/$ARCHBOX_UID"

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

# add archpkgs repo
COPY ./pacman.conf /etc/
RUN set -euo pipefail && pacman-key --init && curl -sSf https://raw.githubusercontent.com/dadevel/archpkgs/main/signature.gpg | pacman-key --add - && pacman-key --lsign-key admin@archpkgs.net
RUN pacman -Syu --noconfirm

# install basic tools
RUN xargs -r pacman -S --needed --noconfirm << EOF
core/base
core/base-devel
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
extra/dos2unix
extra/eza
extra/fd
extra/fzf
extra/git
extra/git-delta
extra/git-lfs
extra/hexyl
extra/htop
extra/jq
extra/minicom
extra/neovim
extra/parallel
extra/progress
extra/pv
extra/qrencode
extra/rclone
extra/ripgrep
extra/rsync
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
EOF

# install networking tools
RUN xargs -r pacman -S --needed --noconfirm << EOF
core/curl
core/iproute2
core/iptables
extra/bind
extra/dog
extra/nftables
extra/openbsd-netcat
extra/tcpdump
extra/traceroute
extra/wget
EOF

# install podman
RUN xargs -r pacman -S --needed --noconfirm << EOF
extra/aardvark-dns
extra/crun
extra/docker-buildx
extra/docker-compose
extra/netavark
extra/passt
extra/podman
EOF

# install programming languages
RUN grep -v -e '^#' << EOF | xargs -r pacman -S --needed --noconfirm
# c/c++
extra/bear
extra/clang
extra/gdb
extra/lldb
extra/ltrace
extra/mingw-w64
extra/strace
# rust
extra/rustup
# go
extra/go
extra/gopls
# python
core/python
extra/pyright
extra/python-pip
extra/python-pipx
extra/python-requests
extra/uv
# ruby
extra/ruby
extra/ruby-bundler
# php
extra/php
extra/composer
# java
extra/jdk-openjdk
# nodejs
extra/nodejs
extra/npm
# terraform
extra/opentofu
# yaml
extra/yaml-language-server
EOF

# install gui support packages
RUN xargs -r pacman -S --needed --noconfirm << EOF
extra/noto-fonts
extra/noto-fonts-cjk
extra/noto-fonts-emoji
extra/noto-fonts-extra
extra/wl-clipboard
extra/xclip
EOF

# install gui programs
RUN xargs -r pacman -S --needed --noconfirm << EOF
extra/chromium
extra/firefox
extra/geckodriver
extra/gimp
extra/kitty
extra/meld
extra/zathura
extra/zathura-pdf-poppler
EOF

# install pentest cli tools
RUN xargs -r pacman -S --needed --noconfirm << EOF
core/krb5
core/nfs-utils
core/openldap
core/openssl
extra/aws-cli
extra/azure-cli
extra/binwalk
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
EOF

# install pentest gui tools
RUN xargs -r pacman -S --needed --noconfirm << EOF
extra/freerdp
extra/ghidra
extra/tigervnc
extra/wireshark-qt
EOF

# install archpkgs tools
# work around weird exit code 123 problem
#RUN xargs -r -n1 pacman -S --needed --noconfirm << EOF
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

# set capabilities for rootless usage
RUN for file in /usr/bin/nmap /usr/bin/hping3 /usr/bin/masscan; do setcap CAP_NET_RAW=ep "$file"; done

# unpackaged python tools
USER $ARCHBOX_USER
RUN export PATH="/home/$ARCHBOX_USER/.local/bin:$PATH" && \
uv tool install --python cpython-3.12.13-linux-x86_64-gnu git+https://github.com/pennyw0rth/netexec.git@v1.5.1 && \
uv tool install git+https://github.com/cogiceo/gpohound.git && \
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
uv tool install git+https://github.com/synacktiv/ntdissector.git

# use systemd as entrypoint
USER root
ENTRYPOINT ["/sbin/init"]
CMD []

# enable native overlayfs in container
VOLUME /var/lib/containers
VOLUME /home/$ARCHBOX_USER/.local/share/containers
