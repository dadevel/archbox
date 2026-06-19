# ArchBox

Run [Arch Linux](https://archlinux.org/) in per-project virtual machines.
Powered by [Podman](https://podman.io/) and KVM/Qemu.

## Setup

First, install all required Pacman packages.
Most of these should already be installed anyway.

~~~ bash
sudo pacman -Sy --needed dosfstools e2fsprogs edk2-ovmf gptfdisk iproute2 openssh podman qemu-desktop rsync spicy systemd util-linux
~~~

Then, clone this repository and customize the [Dockerfile](./image/Dockerfile) to your liking.
All parts marked with `@TODO` will need adjustment.

~~~ bash
git clone --depth 1 https://github.com/dadevel/archbox.git
cd ./archbox
$EDITOR ./image/Dockerfile
~~~

Next, "install" the [archbox.sh](./archbox.sh) script and tweak the configuration options at the top to match your environment.
All options marked with `@TODO` need to be modified.

~~~ bash
ln -s $PWD/archbox.sh ~/.local/bin/archbox
$EDITOR ~/.local/bin/archbox
~~~

Finally, build your first template image.
If you later want to update the image, just run the same command again.

~~~ bash
archbox build
~~~

> [!note]
> How the VM image is built:
>
> 1. Podman is used to build a `Dockerfile`. The only special requirement for this `Dockerfile` is that it must ensure that the directory `/boot` contains all the expected contents of an EFI partition (bootloader, Linux kernel, etc.).
> 2. An empty file is created and loop-mounted. This makes the file appear like a physical disk. Then a partition table and filesystems are initialized on this "disk".
> 3. The content of the container image is copied into the disk image.
> 4. You have a bootable disk image.

### Networking Setup

Before you can boot your first ArchBox VM, we have to talk about networking.
There are two networking modes: bridge and NAT.
Unfortunately, this common names are a bit misleading, because both require a bridge interface :D

You need to achieve the following setup on your host:

- a bridge interface for the NAT network with a DHCP server that hands out IPs to the VMs plus a firewall rule that performs the actual NATing
- another bridge interface where one or more physical ethernet interfaces and a DHCP client running that bridge interface, VMs retrieve their IPs from the same DHCP server as the host

If you are using `systemd-networkd`, `systemd-resolved` and `nftables` you can more or less directly copy the config files from [etc](./etc) into `/etc/`.

## Usage

A basic usage example:

~~~
❯ cd ~/projects/my-project
❯ archbox up --no-gui
...
Command to connect over SSH:
ssh -i ~/.ssh/archbox user@vsock/1234
❯ ssh -i ~/.ssh/archbox user@vsock/1234
user@archbox-my-project$ echo working on project
user@archbox-my-project$ exit
❯ archbox down
~~~

> [!note]
> `archbox up` creates a new ArchBox VM if none exists for the current project and boots it up.  
> The current project directory will be available inside the VM under `~/project`.
> When a Git repository is detected, the repository root will be treated as the project directory.
> Otherwise, the current working directory is used.  
> Additionally, `~/share` on the host is available in all ArchBox VMs under `~/share`.
