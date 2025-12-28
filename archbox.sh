#!/usr/bin/env bash
set -euo pipefail

# configuration: {{{

# core env vars, please don't touch
declare -r ARCHBOX_HOME="${ARCHBOX_HOME:-"$HOME"}"
declare -r ARCHBOX_XDG_RUNTIME_DIR="${ARCHBOX_XDG_RUNTIME_DIR:-"${XDG_RUNTIME_DIR:-"/run/user/$UID"}"}"
declare -r ARCHBOX_PROJECT_ROOT="${ARCHBOX_PROJECT_ROOT:-"$(git rev-parse --show-toplevel 2> /dev/null || echo "$PWD")"}"
declare -r ARCHBOX_PROJECT_NAME="$(basename "$ARCHBOX_PROJECT_ROOT")"
declare -r ARCHBOX_DISPLAY="${ARCHBOX_DISPLAY:-"${DISPLAY:-}"}"
declare -r ARCHBOX_WAYLAND_DISPLAY="${ARCHBOX_WAYLAND_DISPLAY:-"${WAYLAND_DISPLAY:-}"}"

# container image, replace with your image
declare -r ARCHBOX_IMAGE='ghcr.io/dadevel/archbox:latest'

# additional bind mounts, add/remove files and directories as needed
declare -ra ARCHBOX_VOLUMES=(
    "$ARCHBOX_HOME/shared:/home/user/shared:rw"
)

# additional capabilities
# wireshark requires 'net_admin,net_raw', but most network tools like nmap and tcpdump need just 'net_raw'
declare -r ARCHBOX_CAPABILITIES='net_raw'

# podman options, better know what you're doing
declare -r ARCHBOX_CONTAINER="archbox${ARCHBOX_PROJECT_ROOT//\//-}"
declare -a ARCHBOX_RUN_OPTS=(
    --name "$ARCHBOX_CONTAINER"
    --hostname "$ARCHBOX_PROJECT_NAME"
    --pull always
    --device /dev/net/tun
    --volume /etc/localtime:/etc/localtime:ro
    --volume "$ARCHBOX_PROJECT_ROOT:/home/user/project"
    --network host
    --cap-add "$ARCHBOX_CAPABILITIES"
)
for volume in "${ARCHBOX_VOLUMES[@]}"; do
    ARCHBOX_RUN_OPTS+=(--volume "${volume}")
done
declare -a ARCHBOX_EXEC_OPTS=(
    --interactive --tty
    --workdir "/home/user/project/$(realpath --relative-to="$ARCHBOX_PROJECT_ROOT" "$PWD")"
    --env ARCHBOX_PROJECT_NAME="$ARCHBOX_PROJECT_NAME"
    # the following env vars are set on purpose even when running as root
    --env XDG_RUNTIME_DIR=/run/user/1000
    --env "DISPLAY=$ARCHBOX_DISPLAY"
    --env XAUTHORITY=/run/user/1000/xauth
    --env "WAYLAND_DISPLAY=$ARCHBOX_WAYLAND_DISPLAY"
    # some gui programs, e.g. kitty, require 'DBUS_SESSION_BUS_ADDRESS' to be set, but dbus itself is not required
    --env "DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus"
    #--env XDG_CURRENT_DESKTOP
    #--env XDG_SEAT
    #--env XDG_SESSION_CLASS
    #--env XDG_SESSION_ID
    #--env XDG_SESSION_TYPE
)

# }}}

if (( UID != 0 )); then
    exec sudo ARCHBOX_HOME="$ARCHBOX_HOME" ARCHBOX_XDG_RUNTIME_DIR="$ARCHBOX_XDG_RUNTIME_DIR" ARCHBOX_PROJECT_ROOT="$ARCHBOX_PROJECT_ROOT" ARCHBOX_DISPLAY="$ARCHBOX_DISPLAY" ARCHBOX_WAYLAND_DISPLAY="$ARCHBOX_WAYLAND_DISPLAY" "$0" "$@"
fi

declare background=0
declare root=0
declare gui=1
declare replace=0
declare -a command=()
while (( $# )); do
    case "$1" in
        -b|--background)
            background=1
            ;;
        -r|--root)
            root=1
            ;;
        --no-gui)
            gui=0
            ;;
        --replace)
            replace=1
            ;;
        --help|-h)
            echo 'usage: archbox [OPTIONS] [COMMAND]...'
            echo ''
            echo 'options:'
            echo '  -b|--background  Run command in background'
            echo '  -r|--root        Open root shell inside container, otherwise unprivileged user'
            echo '  --no-gui         Disable desktop integration'
            echo '  --replace        Delete and recreate container from image'
            echo '  --help           Show this help'
            exit 0
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

if (( gui )); then
    ARCHBOX_RUN_OPTS+=(
        --device /dev/dri
        --device /dev/snd
        --volume /tmp/.X11-unix/X0:/tmp/.X11-unix/X0
        --volume "$XAUTHORITY:/run/user/1000/xauth"
        --volume "$ARCHBOX_XDG_RUNTIME_DIR/wayland-0:/run/user/1000/wayland-0"
        --volume "$ARCHBOX_XDG_RUNTIME_DIR/pipewire-0:/run/user/1000/pipewire-0"
        --volume "$ARCHBOX_XDG_RUNTIME_DIR/pulse/native:/run/user/1000/pulse/native"
    )
fi
if (( replace )); then
    ARCHBOX_RUN_OPTS+=(--replace)
fi
if (( replace )) ||  ! podman container inspect "$ARCHBOX_CONTAINER" &> /dev/null; then
    podman run -d --cidfile="/tmp/$ARCHBOX_CONTAINER.cid" "${ARCHBOX_RUN_OPTS[@]}" "$ARCHBOX_IMAGE"
fi

if (( root )); then
    ARCHBOX_EXEC_OPTS+=(--user root --env USER=root)
else
    ARCHBOX_EXEC_OPTS+=(--user user --env USER=user)
fi
if (( background )); then
    podman exec "${ARCHBOX_EXEC_OPTS[@]}" "$ARCHBOX_CONTAINER" "${command[@]:-$SHELL}" &> /dev/null &
else
    podman exec "${ARCHBOX_EXEC_OPTS[@]}" "$ARCHBOX_CONTAINER" "${command[@]:-$SHELL}"
fi
