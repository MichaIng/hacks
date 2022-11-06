#!/bin/dash
systemctl disable --now systemd-binfmt proc-sys-fs-binfmt_misc.automount sys-fs-fuse-connections.mount sys-kernel-config.mount
systemctl mask systemd-binfmt proc-sys-fs-binfmt_misc.automount sys-fs-fuse-connections.mount sys-kernel-config.mount
