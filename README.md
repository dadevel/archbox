# ArchBox

Run [Arch Linux](https://archlinux.org/) in a lightly isolated container with desktop integration and support for nested containers.
Powered by [Podman](https://podman.io/).

## Setup

First, clone this repository and customize the [Dockerfile](./container/Dockerfile) to your liking.

~~~ bash
git clone --depth 1 https://github.com/dadevel/archbox.git
cd ./archbox
$EDITOR ./container/Dockerfile
~~~

Then, "install" the [archbox.sh](./archbox.sh) script and tweak the configuration options at the top to match your environment.

~~~ bash
ln -s $PWD/archbox.sh ~/.local/bin/archbox
$EDITOR ~/.local/bin/archbox
~~~

Finally, build the container image.

~~~ bash
archbox update
~~~

## Usage

Get a shell inside the ArchBox container.
For each project, a separate container is used.

~~~ bash
cd ~/projects/my-project
archbox enter
~~~

> [!NOTE]
> If no container for this project exists yet, ArchBox spawns a new container and mounts the current working directory into it.
> Or, if you are inside a git project, the git project root directory is mounted instead.  
> Additional bind mounts integrate the container with your desktop, unless `--no-gui` was specified.  
> After the container is ready, a shell as unprivileged user is opened inside the container.
> To get a root shell add the flag `--root`.

Open a terminal window inside the ArchBox container.

~~~ bash
cd ~/projects/my-project
archbox enter -b kitty
~~~

### Networking

For direct layer one access to the local network specify the option `--network host`.
This is the default.  
If another container provides access to a remote network, e.g. through a VPN, join the network namespace of that container with `--network container:CONTAINER_NAME`.  
It is also possible to join a completely custom network namespace with `--network ns:/run/netns/NETNS_NAME`.
