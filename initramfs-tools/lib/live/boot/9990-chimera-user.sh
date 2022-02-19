# this sets up the user in the live environment
#
# a part of chimera linux, license: BSD-2-Clause

Chimera_Service() {
    if [ -f /root/etc/dinit.d/$1 ]; then
        ln -sf ../$1 /root/etc/dinit.d/$2.d/$1
    fi
}

Chimera_Userserv() {
    if [ -f /root/etc/dinit.d/user/$1 ]; then
        ln -sf ../$1 /root/home/$2/.config/dinit.d/boot.d/$1
    fi
}

Chimera_User() {
    log_begin_msg "Setting up user"

    [ -x /root/usr/bin/mksh ] && USERSHELL="/usr/bin/mksh"
    [ -z "$USERSHELL" ] && USERSHELL="/bin/sh"

    # hostname; prevent syslog from doing dns lookup
    echo "127.0.0.1 $(cat /root/etc/hostname)" >> /root/etc/hosts
    echo "::1 $(cat /root/etc/hostname)" >> /root/etc/hosts

    # /etc/issue
    if [ -f "/lib/live/data/issue.in" ]; then
        sed \
            -e "s|@USER@|anon|g" \
            -e "s|@PASSWORD@|chimera|g" \
            "/lib/live/data/issue.in" > /root/etc/issue
    fi

    chroot /root useradd -m -c anon -G audio,video,wheel -s "$USERSHELL" anon

    chroot /root sh -c 'echo "root:chimera"|chpasswd -c SHA512'
    chroot /root sh -c 'echo "anon:chimera"|chpasswd -c SHA512'

    if [ -x /root/usr/bin/doas ]; then
        echo "permit persist :wheel" >> /root/etc/doas.conf
        chmod 600 /root/etc/doas.conf
    fi

    if [ -f /root/etc/sudoers ]; then
        echo "%wheel ALL=(ALL) ALL" >> /root/etc/sudoers
    fi

    # enable services
    Chimera_Service udevd init
    Chimera_Service dhcpcd network
    Chimera_Service dinit-userservd login
    Chimera_Service dbus login
    Chimera_Service elogind login
    Chimera_Service polkitd login
    Chimera_Service syslog-ng login
    Chimera_Service network login
    Chimera_Service sshd boot

    # enable extra gettys if needed; for serial and so on
    for _PARAMETER in ${LIVE_BOOT_CMDLINE}; do
        case "${_PARAMETER}" in
            console=*)
                case "${_PARAMETER#console=}" in
                    *ttyS0*) Chimera_Service agetty-ttyS0 boot;;
                    *ttyAMA0*) Chimera_Service agetty-ttyAMA0 boot;;
                    *ttyUSB0*) Chimera_Service agetty-ttyUSB0 boot;;
                    *hvc0*) Chimera_Service agetty-hvc0 boot;;
                    *hvsi0*) Chimera_Service agetty-hvsi0 boot;;
                esac
                ;;
        esac
    done

    # enable user services
    chroot /root mkdir -p /home/anon/.config/dinit.d/boot.d
    Chimera_Userserv dbus anon
    Chimera_Userserv pipewire-pulse anon
    Chimera_Userserv pipewire anon
    Chimera_Userserv wireplumber anon
    # fix up permissions
    chroot /root chown -R anon:anon /home/anon

    log_end_msg
}
