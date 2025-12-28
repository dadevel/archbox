# ArchBox

Run [Arch Linux](https://archlinux.org/) in a lightly isolated container with desktop integration and support for nested containers.
Powered by [Podman](https://podman.io/).

## Setup

First, click `Use this template` in the top right to create your personal fork.  
Then, customize the [Dockerfile](./container/Dockerfile) and [pkgs.txt](./container/pkgs.txt) to your liking.  
Afterwards, install the [archbox.sh](./archbox.sh) script on your host and tweak the configuration options at the top.

~~~ bash
curl -sSfL https://github.com/dadevel/archbox/raw/refs/heads/main/archbox.sh ~/.local/bin/archbox
chmod +x ~/.local/bin/archbox
$EDITOR ~/.local/bin/archbox
~~~

## Usage

Get a shell inside the ArchBox container.
For each project, a separate container is used.

~~~ bash
cd ~/projects/my-project
archbox
~~~

> [!NOTE]
> If no container for this project exists yet, ArchBox spawns a new container and mounts the current working directory into it.
> Or, if you are inside a git project, the git project root directory is mounted instead.  
> Additional bind mounts integrate the container with your desktop, unless `--no-gui` was specified.
>
> After the container is ready, a shell as unprivileged user is opened inside the container.
> To get a root shell add the flag `--root`.

Open a terminal window inside the ArchBox container.

~~~ bash
cd ~/projects/my-project
archbox -b kitty
~~~

## Development

Build and run locally.

~~~ bash
sudo podman build --pull=always -t ghcr.io/dadevel/archbox:latest ./container
./archbox.sh
~~~
