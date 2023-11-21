#!/usr/bin/env bash

set -e
newroot="$(mktemp -d)"
cd "$newroot"
debootstrap --arch=amd64 \
            --components=main,contrib,non-free,non-free-firmware \
            --include=kali-archive-keyring,kali-linux-wsl,kali-linux-default,kali-desktop-xfce,xorg,xrdp \
            kali-rolling \
            . \
            http://http.kali.org/kali
chroot . /debootstrap/debootstrap --second-stage
cat << EOF > ./etc/profile
# /etc/profile: system-wide .profile file for the Bourne shell (sh(1))
# and Bourne compatible shells (bash(1), ksh(1), ash(1), ...).

# WSL already sets PATH, shouldn't be overridden
IS_WSL=\$( grep -i microsoft /proc/version )
if test "\${IS_WSL}" = ""; then
  if [ "\$( id -u )" -eq 0 ]; then
    PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
  else
    PATH="/usr/local/bin:/usr/bin:/bin:/usr/local/games:/usr/games"
  fi
fi
export PATH

if [ "$\{PS1-}" ]; then
  if [ "\${BASH-}" ] && [ "\${BASH}" != "/bin/sh" ]; then
    # The file bash.bashrc already sets the default PS1.
    # PS1='\h:\w$ '
    if [ -f /etc/bash.bashrc ]; then
      . /etc/bash.bashrc
    fi
  else
    if [ "\$( id -u )" -eq 0 ]; then
      PS1='# '
    else
      PS1='$ '
    fi
  fi
fi

if [ -d /etc/profile.d ]; then
  for i in /etc/profile.d/*.sh; do
    if [ -r \$i ]; then
      . \$i
    fi
  done
  unset i
fi
EOF
sed -i 's/^port=3389$/port=3390/g' ./etc/xrdp/xrdp.ini
cat << EOF > ./etc/apt/sources.list
# See: https://www.kali.org/docs/general-use/kali-linux-sources-list-repositories/
deb http://http.kali.org/kali kali-rolling main contrib non-free non-free-firmware

# Additional line for source packages
#deb-src http://http.kali.org/kali kali-rolling main contrib non-free non-free-firmware
EOF
echo kali > ./etc/hostname
cat << EOF > ./etc/hosts
127.0.0.1 localhost
::1   localhost ip6-localhost ip6-loopback
ff02::1   ip6-allnodes
ff02::2   ip6-allrouters
EOF
truncate -s 0 ./etc/resolv.conf
# chroot . kali-tweaks
# chroot . adduser --quiet --gecos '' kali
chroot . adduser --quiet --gecos '' kali << EOF
kali
kali
EOF
chroot . usermod -aG adm,cdrom,sudo,dip,plugdev kali
# chroot --userspec=kali:kali . kali-tweaks
cat << EOF > "${rootfsDir}"/etc/wsl.conf
[network]
hostname=kali

[user]
default=kali

[boot]
systemd=true
EOF
chroot . apt clean
rm -vrf ./var/lib/apt/lists/*
mkdir -vp ./var/lib/apt/lists/partial
find ./var/log -depth -type f -exec truncate -s 0 {} +
rm -vf ./var/cache/ldconfig/aux-cache
cd -
tar --ignore-failed-read --xattrs -czf install.tar.gz "$newroot"/*
rm -rf "$newroot"
unset newroot
