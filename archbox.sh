#!/usr/bin/env bash
set -euo pipefail

# configuration {{{

declare -r XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-"/run/user/$UID"}"

declare -r ARCHBOX_IMAGE='localhost/archbox:latest'

declare -r ARCHBOX_BUILD_CONTEXT="$(dirname "$(realpath "$0")")/container"
declare -ra ARCHBOX_BUILD_VOLUMES=(
    /var/cache/pacman:/var/cache/pacman:rw
)

# additional bind mounts
# add/remove files and directories as needed
declare -ra ARCHBOX_RUNTIME_VOLUMES=(
    "$ARCHBOX_HOME/shared:/home/user/shared:rw"
)

# additional capabilities
# wireshark requires 'net_admin,net_raw', but most network tools like nmap and tcpdump need just 'net_raw'
declare -r ARCHBOX_CAPABILITIES='net_raw'

# }}}

main() {
    case "${1:-}" in
        help|list|destroy|update|enter)
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
    echo 'usage: archbox COMMAND [OPTION]...'
    echo ''
    echo 'commands:'
    echo '  help     Show this help'
    echo '  enter    Execute command inside container'
    echo '  list     Show containers'
    echo '  destroy  Delete container'
    echo '  update   Rebuild container image'
    echo ''
    echo 'enter options:'
    echo '  --network SPEC   Configure network, supported specifications: host|container:NAME|ns:PATH|none'
    echo '  --no-gui         Disable desktop integration'
    echo "  --private        Don't mount workdir into container"
    echo '  --replace        Delete and recreate container from image'
    echo '  -b|--background  Run command in background'
    echo '  -r|--root        Open root shell inside container, otherwise unprivileged user'
}

command_list() {
    sudo podman ps --all --format json | jq -r '.[]|select(.Names[]|startswith("archbox-"))|[.Names[0], .Status]|@tsv' | column -t -s $'\t'
}

command_destroy() {
    if (( $# )); then
        sudo podman rm -f -- "$@" > /dev/null
    else
        command_list | fzf --multi | xargs -r -- sudo podman rm -f -- > /dev/null
    fi
}

command_update() {
    declare -a build_opts=(
        -t "$ARCHBOX_IMAGE"
        --pull=always
    )
    declare volume
    for volume in "${ARCHBOX_BUILD_VOLUMES[@]}"; do
        build_opts+=(--volume "${volume}")
    done

    sudo podman build "${build_opts[@]}" "$ARCHBOX_BUILD_CONTEXT"
}

command_enter() {
    declare -i background=0
    declare user='user'
    declare network='host'
    declare -i gui=1
    declare project_root="$(git rev-parse --show-toplevel 2> /dev/null || echo "$PWD")"
    declare -i replace=0
    declare -a command=()
    while (( $# )); do
        case "$1" in
            -b|--background)
                background=1
                ;;
            -r|--root)
                user='root'
                ;;
            --network)
                network="$2"
                shift
                ;;
            --no-gui)
                gui=0
                ;;
            --private)
                project_root=''
                ;;
            --replace)
                replace=1
                ;;
            --)
                shift
                break
                ;;
            -*)
                echo 'bad arg(s)' >&2
                exit 1
                ;;
            *)
                command+=("$1")
                ;;
        esac
        shift
    done
    command+=("$@")

    if [[ -n "${project_root}" ]]; then
        declare -r project_name="$(basename "${project_root}")"
        declare -r container="archbox${project_root//\//-}"
    else
        declare -r project_name=private
        declare -r container='archbox-private'
    fi

    declare -a run_opts=(
        --name "${container}"
        --hostname "${project_name}"
        --device /dev/net/tun
        --cap-add "$ARCHBOX_CAPABILITIES"
        --network "${network}"
        --volume /etc/localtime:/etc/localtime:ro
    )
    for volume in "${ARCHBOX_RUNTIME_VOLUMES[@]}"; do
        run_opts+=(--volume "${volume}")
    done
    if (( gui )); then
        run_opts+=(--device /dev/dri --device /dev/snd)
        if [[ -n "${DISPLAY:-}" ]]; then
            run_opts+=(--volume /tmp/.X11-unix/X0:/tmp/.X11-unix/X0)
        fi
        if [[ -n "${XAUTHORITY:-}" ]]; then
            cp -- "$XAUTHORITY" "/run/user/$UID/xauth"
            run_opts+=(--volume "/run/user/$UID/xauth:/run/user/1000/xauth")
        fi
        if [[ -n "${WAYLAND_DISPLAY:-}" ]]; then
            run_opts+=(--volume "$XDG_RUNTIME_DIR/wayland-0:/run/user/1000/wayland-0")
        fi
        if [[ -e "$XDG_RUNTIME_DIR/pulse/native" ]]; then
            run_opts+=(--volume "$XDG_RUNTIME_DIR/pulse/native:/run/user/1000/pulse/native")
        fi
        if [[ -e "$XDG_RUNTIME_DIR/pipewire-0" ]]; then
            run_opts+=(--volume "$XDG_RUNTIME_DIR/pipewire-0:/run/user/1000/pipewire-0")
        fi
    fi
    if [[ -n "${project_root}" ]]; then
        run_opts+=(--volume "${project_root}:/home/user/project")
    fi
    if (( replace )); then
        run_opts+=(--replace)
    fi

    declare -ga exec_opts=(
        --interactive
        --tty
        --user "${user}"
        --env "USER=${user}"
        --env ARCHBOX_PROJECT_NAME="${project_name}"
        # the following env vars are set on purpose even when running as root
        --env XDG_RUNTIME_DIR=/run/user/1000
    )
    if [[ -n "${project_root}" ]]; then
        exec_opts+=(--workdir "/home/user/project/$(realpath --relative-to="${project_root}" "$PWD")")
    else
        exec_opts+=(--workdir /home/user/project)
    fi
    if (( gui )); then
        exec_opts+=(
            # some gui programs, e.g. kitty, require 'DBUS_SESSION_BUS_ADDRESS' to be set, but dbus itself is not required
            --env "DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus"
            #--env XDG_CURRENT_DESKTOP
            #--env XDG_SEAT
            #--env XDG_SESSION_CLASS
            #--env XDG_SESSION_ID
            #--env XDG_SESSION_TYPE
        )
        if [[ -n "${DISPLAY:-}" ]]; then
            exec_opts+=(--env "DISPLAY=$DISPLAY")
        fi
        if [[ -n "${XAUTHORITY:-}" ]]; then
            exec_opts+=(--env XAUTHORITY=/run/user/1000/xauth)
        fi
        if [[ -n "${WAYLAND_DISPLAY:-}" ]]; then
            exec_opts+=(--env "WAYLAND_DISPLAY=$WAYLAND_DISPLAY")
        fi
    fi

    declare -r status="$(sudo podman container inspect "${container}" 2> /dev/null)"
    if (( replace )) || [[ "${status}" == '[]' ]]; then
        sudo podman run -d --cidfile="/tmp/${container}.cid" "${run_opts[@]}" "$ARCHBOX_IMAGE"
    fi

    if (( !replace )) && [[ "$(jq -r 'first(.[]).State.Running' <<< "${status}")" == false ]]; then
        sudo podman container start "${container}"
    fi

    if (( background )); then
        sudo podman exec "${exec_opts[@]}" "${container}" "${command[@]:-$SHELL}" &> /dev/null &
    else
        sudo podman exec "${exec_opts[@]}" "${container}" "${command[@]:-$SHELL}"
    fi
}

main "$@"
