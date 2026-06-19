#!/usr/bin/env bash
set -euo pipefail
PS4='>> '

# configuration {{{

# constants, don't touch
declare -r ARCHBOX_USER="${USER:-user}"
declare -r ARCHBOX_BUILD_DIR="$(dirname "$(realpath "$0")")"
declare -r ARCHBOX_BUILD_CONTEXT="$ARCHBOX_BUILD_DIR/image"
declare -r ARCHBOX_IMAGE='localhost/archbox:latest'
declare -r ARCHBOX_STATE_DIR="$HOME/.local/share/archbox"
declare -r ARCHBOX_RUN_DIR="${XDG_RUNTIME_DIR:-"/run/user/$UID"}/archbox"

# build options
declare -ra ARCHBOX_BUILD_ARGS=(
    --build-arg ARCHBOX_USER="$ARCHBOX_USER"
    --build-arg ARCHBOX_UID=1000
    # @TODO: generate your own hash with 'openssl passwd -6'
    --build-arg ARCHBOX_SUDO_PASSWORD='$6$RXWXL7w7c.G.3WoK$GaZkZkt6fKKopyWHmZvjsEFYtCpblzVIqglqD3heKN8pwBd1RHQ5orOqzzgzrgx/gxFApqpsBNx5S/DFHya3r1'
    # @TODO: root login disabled, set password hash to enable
    --build-arg ARCHBOX_ROOT_PASSWORD='!'
    # @TODO: path to your dotfiles, adjust as needed
    --build-context dotfiles="$HOME/dotfiles"
    # @TODO: path to internal tools, adjust as well
    --build-context work="$HOME/projects/work"
)
# size of virtual VM disk, build requires size times three free space
declare -r ARCHBOX_DISK_SIZE=32G
# directory shared between all vms
declare -r ARCHBOX_SHARE_DIR="$HOME/share"

# runtime options
# @TODO: name of the bridge interface for bridge mode
declare -r ARCHBOX_EXTERNAL_BRIDGE='br-ext'
# @TODO: name of the bridge interface for nat mode
declare -r ARCHBOX_NAT_BRIDGE='br-nat'
# custom qemu command line options
declare -ra ARCHBOX_BOOT_ARGS=()
# paths to certain files
declare -r ARCHBOX_VIRTIOFSD='/usr/lib/virtiofsd'
declare -r ARCHBOX_OVMF_CODE='/usr/share/edk2-ovmf/x64/OVMF_CODE.4m.fd'
declare -r ARCHBOX_OVMF_VARS='/usr/share/edk2-ovmf/x64/OVMF_VARS.4m.fd'

# }}}

main() {
    case "${1:-}" in
        help|list|build|up|down|destroy)
            command_"$1" "${@:2}"
            exit 0
            ;;
        *)
            command_help
            exit 1
            ;;
    esac
}

command_help() {
    echo 'usage: archbox COMMAND ...'
    echo ''
    echo 'commands:'
    echo '  help'
    echo '    Show this help'
    echo '  list'
    echo '    Show projects'
    echo '  build'
    echo '    Rebuild template'
    echo '  up [PROJECT_ROOT] [--no-gui] [--foreground] [--network nat|bridge]'
    echo '    Boot VM'
    echo '  down [PROJECT_ROOT]'
    echo '    Shutdown VM'
    echo '  destroy'
    echo '    Delete VM(s)'
    echo '  logs [JOURNALCTL_OPTS]...'
    echo '    Show logs'
}

command_list() {
    # FIXME: add up/down indicator
    find "$ARCHBOX_STATE_DIR" -mindepth 1 -maxdepth 1 -type d -exec basename '{}' ';'
}

command_build() {
    set -x
    sudo -v

    if [[ ! -f ~/.ssh/archbox ]]; then
        ssh-keygen -t ed25519 -C 'root@archbox' -f ~/.ssh/archbox
    fi
    cp ~/.ssh/archbox.pub "$ARCHBOX_BUILD_DIR/image/"

    declare -a podman_args=(
        --pull=always
        --network host
        --no-hosts
        --volume "$ARCHBOX_BUILD_DIR/cache:/var/cache/pacman:rw"
        --squash-all
        -t "$ARCHBOX_IMAGE"
    )
    # reuse pacman cache from host
    mkdir -p "$ARCHBOX_BUILD_DIR/cache/pkg"
    rsync --exclude 'download-*/' /var/cache/pacman/pkg/ "$ARCHBOX_BUILD_DIR/cache/pkg"
    podman build "${podman_args[@]}" "${ARCHBOX_BUILD_ARGS[@]}" "$ARCHBOX_BUILD_CONTEXT"

    teardown() {
        rm -rf "$ARCHBOX_BUILD_DIR/tmp"

        if mountpoint -q "$ARCHBOX_BUILD_DIR/mnt"; then
            sudo umount -R "$ARCHBOX_BUILD_DIR/mnt"
            rmdir "$ARCHBOX_BUILD_DIR/mnt"
        fi

        if [[ -e /dev/loop0 ]]; then
            sudo losetup /dev/loop0 --detach-all
            sudo losetup /dev/loop0 --remove
        fi
    }
    trap teardown EXIT

    # backup previous disk image
    if [[ -f "$ARCHBOX_BUILD_DIR/disk.raw" ]]; then
        cp "$ARCHBOX_BUILD_DIR/disk.raw" "$ARCHBOX_BUILD_DIR/disk.raw.bak"
    fi
    # create empty disk image
    rm -f "$ARCHBOX_BUILD_DIR/disk.raw"
    truncate -s "$ARCHBOX_DISK_SIZE" "$ARCHBOX_BUILD_DIR/disk.raw"

    # create partitions
    sgdisk --zap-all "$ARCHBOX_BUILD_DIR/disk.raw"
    sgdisk --new=0:0:+512M --typecode=0:ef00 --change-name=0:efi "$ARCHBOX_BUILD_DIR/disk.raw"
    sgdisk --new=0:0:0 --typecode=0:8304 --change-name=0:system "$ARCHBOX_BUILD_DIR/disk.raw"
    sgdisk --sort --print "$ARCHBOX_BUILD_DIR/disk.raw"

    # mount disk
    sudo losetup --partscan /dev/loop0 "$ARCHBOX_BUILD_DIR/disk.raw"

    # create filesystems
    sudo mkfs.fat -F 32 -n boot /dev/loop0p1
    sudo mkfs.ext4 -L root /dev/loop0p2

    # mount partitions
    mkdir "$ARCHBOX_BUILD_DIR/mnt"
    sudo mount /dev/loop0p2 "$ARCHBOX_BUILD_DIR/mnt"
    sudo mkdir -p "$ARCHBOX_BUILD_DIR/mnt/boot"
    sudo mount /dev/loop0p1 "$ARCHBOX_BUILD_DIR/mnt/boot"

    # copy container filesystem to disk
    rm -rf "$ARCHBOX_BUILD_DIR/tmp"
    mkdir "$ARCHBOX_BUILD_DIR/tmp"

    # 'podman build --output type=tar,dest=./sysroot.tar' does not preserve SUID/SGID bits, see https://github.com/podman-container-tools/buildah/issues/4463
    podman image save "$ARCHBOX_IMAGE" | tar -xf- -C "$ARCHBOX_BUILD_DIR/tmp"
    sudo tar -xf "$ARCHBOX_BUILD_DIR/tmp/"????????????????????????????????????????????????????????????????.tar -C "$ARCHBOX_BUILD_DIR/mnt"

    trap - EXIT
    teardown
}

command_up() {
    declare project_root=''
    declare network='nat'
    declare -i gui=1
    declare -i foreground=0
    while (( $# )); do
        case "$1" in
            --network)
                if (( $# < 2 )) || [[ "$2" != nat && "$2" != bridge ]]; then
                    echo bad args >&2
                    return 1
                fi
                network="$2"
                shift
                ;;
            --no-gui)
                gui=0
                ;;
            --foreground)
                foreground=1
                ;;
            -*)
                echo bad args >&2
                return 1
                ;;
            *)
                if (( $# < 2 )) || [[ -n "${project_root}" ]]; then
                    echo bad args >&2
                    return 1
                fi
                project_root="$2"
                shift
                ;;
        esac
        shift
    done
    if [[ -z "${project_root}" ]]; then
        project_root="$(git rev-parse --show-toplevel 2> /dev/null || echo "$PWD")"
    fi
    declare -r project_slug="$(basename "${project_root}")"
    declare project_name="${project_root##/}"
    declare -r project_name="${project_name//\//-}"
    #declare -r workdir="/home/user/project/$(realpath --relative-to="${project_root}" "$PWD")"
    declare -gr run_dir="$ARCHBOX_RUN_DIR/${project_name}"
    declare -r state_dir="$ARCHBOX_STATE_DIR/${project_name}"

    mkdir -p "${run_dir}" "${state_dir}"

    if [[ ! -f "${state_dir}/disk.raw" ]]; then
        rsync "$ARCHBOX_BUILD_DIR/disk.raw" "${state_dir}/disk.raw"
    fi
    if [[ ! -f "${state_dir}/efi.raw" ]]; then
        rsync "$ARCHBOX_OVMF_VARS" "${state_dir}/efi.raw"
    fi

    if [[ -f "${state_dir}/id.txt" ]]; then
        declare -r project_id="$(< "${state_dir}/id.txt")"
    else
        declare -r project_id="$(openssl rand -hex 3 | tee "${state_dir}/id.txt")"
    fi
    declare -r hostname="archbox-${project_slug}"
    declare -r mac_address="52:54:00$(echo -n "${project_id}" | sed -E 's|(..)|:\1|g')"
    declare -r vm_interface="tap-${project_id}"
    declare -r vsock_cid="$(printf '%d\n' "${project_id}")"

    if [[ "${network}" == nat ]]; then
        declare -r bridge_interface="$ARCHBOX_NAT_BRIDGE"
    elif [[ "${network}" == bridge ]]; then
        declare -r bridge_interface="$ARCHBOX_EXTERNAL_BRIDGE"
    else
        return 1
    fi
    if ! ip link show "${vm_interface}" &> /dev/null; then
        sudo ip tuntap add mode tap "${vm_interface}"
    fi
    sudo ip link set dev "${vm_interface}" master "${bridge_interface}"
    sudo ip link set "${vm_interface}" up

    teardown() {
        kill $(jobs -p) ||:
        # avoid sudo prompt during shutdown, let network interface linger instead
        #sudo ip link delete "${vm_interface}"
    }
    if (( foreground )); then
        trap teardown EXIT
    fi

    if (( foreground )); then
        "$ARCHBOX_VIRTIOFSD" --socket-path "${run_dir}/virtiofs-project.sock" --shared-dir "${project_root}" &
        "$ARCHBOX_VIRTIOFSD" --socket-path "${run_dir}/virtiofs-share.sock" --shared-dir "$ARCHBOX_SHARE_DIR" &
    else
        systemd-run --user --unit "archbox-${project_name}-virtiofsd-project.service" --nice 10 -- "$ARCHBOX_VIRTIOFSD" --socket-path "${run_dir}/virtiofs-project.sock" --shared-dir "${project_root}"
        systemd-run --user --unit "archbox-${project_name}-virtiofsd-share.service" --nice 10 -- "$ARCHBOX_VIRTIOFSD" --socket-path "${run_dir}/virtiofs-share.sock" --shared-dir "$ARCHBOX_SHARE_DIR"
    fi

    declare qemu_args=(
        # FIXME: use direct kernel boot, remove efi
        #-kernel "$ARCHBOX_BUILD_DIR/vmlinuz-linux" -append 'root=LABEL=root rw'

        # efi
        -drive if=pflash,format=raw,unit=0,file="$ARCHBOX_OVMF_CODE",readonly=on
        -drive if=pflash,format=raw,unit=1,file="${state_dir}/efi.raw"
        -boot order=d,menu=on

        # storage
        -drive media=disk,file="${state_dir}/disk.raw",format=raw,if=virtio,aio=native,cache.direct=on,discard=unmap

        # ram, memory backend required for virtiofs
        -m size=8g
        -device virtio-balloon
        -object memory-backend-memfd,id=mem,size=8G,share=on -numa node,memdev=mem

        # compute
        -cpu host -smp dies=1,sockets=1,cores=2,threads=2
        -machine type=q35,accel=kvm -enable-kvm
        -device intel-iommu

        # networking
        -netdev type=tap,id=network0,ifname="${vm_interface}",script=no,downscript=no
        -device driver=virtio-net,netdev=network0,mac="${mac_address}"

        # video, virtio display doesn't support dynamic display resolution, qxl dynamic resolution requires x11
        -vga none
        -device qxl-vga,vgamem_mb=32
        -device virtio-serial-pci
        -spice unix=on,addr="${run_dir}/spice.sock",disable-ticketing=on
        -chardev spicevmc,id=spicechannel0,name=vdagent
        -device virtserialport,chardev=spicechannel0,name=com.redhat.spice.0

        # spice usb redirection
        -usb -device usb-tablet -device nec-usb-xhci,id=usb
        -chardev spicevmc,name=usbredir,id=usbredirchardev1 -device usb-redir,chardev=usbredirchardev1,id=usbredirdev1

        # audio
        -device intel-hda
        -device hda-duplex

        # virtiofs
        -chardev socket,id=char0,path="${run_dir}/virtiofs-project.sock" -device vhost-user-fs-pci,chardev=char0,tag=project
        -chardev socket,id=char1,path="${run_dir}/virtiofs-share.sock" -device vhost-user-fs-pci,chardev=char1,tag=share

        # systemd vm interface, see https://systemd.io/VM_INTERFACE/
        # sshd on vsock
        -device vhost-vsock-pci,id=vhost-vsock-pci0,guest-cid="${vsock_cid}"
        # config pass through
        -smbios type=11,value=io.systemd.credential.binary:system.hostname="$(echo -n "${hostname}" | base64 -w0)"
    )

    if (( foreground )); then
        qemu-system-x86_64 "${qemu_args[@]}" "${ARCHBOX_BOOT_ARGS[@]}" &
    else
        systemd-run --user --unit "archbox-${project_name}-qemu.service" --nice 10 -- qemu-system-x86_64 "${qemu_args[@]}" "${ARCHBOX_BOOT_ARGS[@]}"
    fi

    if (( gui )); then
        if (( foreground )); then
            spicy --uri "spice+unix://${run_dir}/spice.sock" &
        else
            systemd-run --user --unit "archbox-${project_name}-spicy.service" --nice 10 -- spicy --uri "spice+unix://${run_dir}/spice.sock"
        fi
    fi

    set +x
    echo 'Command to connect over SSH:'
    echo "ssh -i ~/.ssh/archbox $ARCHBOX_USER@vsock/${vsock_cid}"

    if (( foreground )); then
        wait
    fi
}

command_down() {
    if (( $# == 0 )); then
        declare project_root="$(git rev-parse --show-toplevel 2> /dev/null || echo "$PWD")"
    elif (( $# == 1 )); then
        declare project_root="$1"
    else
        echo bad args >&2
        return 1
    fi
    declare project_name="${project_root##/}"
    declare -r project_name="${project_name//\//-}"
    declare -r project_id="$(< "$ARCHBOX_STATE_DIR/${project_name}/id.txt")"
    declare -r vsock_cid="$(printf '%d\n' "${project_id}")"

    timeout 15 ssh -i ~/.ssh/archbox "root@vsock/${vsock_cid}" systemctl poweroff ||:
    systemctl --user stop "archbox-${project_name}-*.service"
    systemctl --user reset-failed "archbox-${project_name}-*.service"
}

command_destroy() {
    command_list | fzf --multi | xargs -r -- rm -rf --
}

command_logs() {
    exec journalctl --user --no-hostname --unit 'archbox*.service' "$@"
}

rsync() {
    command rsync --progress --human-readable "$@"
}

main "$@"
