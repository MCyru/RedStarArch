#!/bin/bash
set -e
WALL="$1"
OUT="$2"

echo "== 1/7 Checking wallpaper"
[ -f "$WALL" ] || { echo "ERROR: wallpaper not found at $WALL"; exit 1; }
mkdir -p "$OUT"

echo "== 2/7 Installing archiso"
pacman-key --init
pacman-key --populate archlinux
pacman -Syu --noconfirm archiso git nano

echo "== 3/7 Creating profile and package list"
rm -rf ~/live ~/work ~/out
cp -r /usr/share/archiso/configs/baseline ~/live
echo >> ~/live/packages.x86_64
cat >> ~/live/packages.x86_64 << 'EOF'
linux-firmware
networkmanager
network-manager-applet
sudo
nano
git
gcc
make
hyprland
foot
waybar
wofi
swaybg
xdg-desktop-portal-hyprland
polkit
mesa
ttf-dejavu
pcmanfm
firefox
code
EOF
MISS=0
for p in $(grep -v '^#' ~/live/packages.x86_64 | grep -v '^$' | sort -u); do
  pacman -Si "$p" >/dev/null 2>&1 || { echo "MISSING PACKAGE: $p"; MISS=1; }
done
[ $MISS = 0 ] || { echo "ERROR: fix the package names above and run again"; exit 1; }

echo "== 4/7 Desktop config"
S=~/live/airootfs/etc/skel
mkdir -p $S/.config/hypr "$S/.config/Code - OSS/User" $S/Pictures $S/dev
cp "$WALL" $S/Pictures/wall.jpg
cat > $S/.config/hypr/hyprland.conf << 'EOF'
monitor=,preferred,auto,1
$mod = SUPER
env = MOZ_ENABLE_WAYLAND,1
input {
    kb_layout = br
}
general {
    gaps_in = 5
    gaps_out = 10
    border_size = 2
}
decoration {
    rounding = 8
}
misc {
    disable_hyprland_logo = true
}
exec-once = waybar
exec-once = nm-applet --indicator
exec-once = swaybg -i $HOME/Pictures/wall.jpg -m fill
bind = $mod, RETURN, exec, foot
bind = $mod, D, exec, wofi --show drun
bind = $mod, E, exec, code
bind = $mod, B, exec, firefox
bind = $mod, T, exec, pcmanfm
bind = $mod, Q, killactive
bind = $mod SHIFT, E, exit
bind = $mod, F, fullscreen
bind = $mod, V, togglefloating
bind = $mod, left, movefocus, l
bind = $mod, right, movefocus, r
bind = $mod, 1, workspace, 1
bind = $mod, 2, workspace, 2
bind = $mod, 3, workspace, 3
bindm = $mod, mouse:272, movewindow
bindm = $mod, mouse:273, resizewindow
EOF
cat > $S/.bash_profile << 'EOF'
if [ "$(tty)" = "/dev/tty1" ]; then exec Hyprland; fi
EOF
echo "--ozone-platform-hint=auto" > $S/.config/code-flags.conf
cat > "$S/.config/Code - OSS/User/settings.json" << 'EOF'
{"telemetry.telemetryLevel":"off","update.mode":"none","workbench.startupEditor":"none"}
EOF

echo "== 5/7 User, auto-login, network, sudo"
A=~/live/airootfs
mkdir -p $A/etc/systemd/system/getty@tty1.service.d $A/etc/systemd/system/multi-user.target.wants $A/etc/sudoers.d
cat > $A/etc/systemd/system/create-user.service << 'EOF'
[Unit]
Description=Create live user
Before=getty@tty1.service
ConditionPathExists=!/home/prickett
[Service]
Type=oneshot
ExecStart=/usr/bin/useradd -m -G wheel,video,audio,input -s /bin/bash prickett
ExecStartPost=/usr/bin/sh -c "echo prickett:158575 | chpasswd"
[Install]
WantedBy=multi-user.target
EOF
ln -sf /etc/systemd/system/create-user.service $A/etc/systemd/system/multi-user.target.wants/create-user.service
ln -sf /usr/lib/systemd/system/NetworkManager.service $A/etc/systemd/system/multi-user.target.wants/NetworkManager.service
cat > $A/etc/systemd/system/getty@tty1.service.d/autologin.conf << 'EOF'
[Service]
ExecStart=
ExecStart=-/sbin/agetty --noreset --noclear --autologin prickett - ${TERM}
EOF
echo '%wheel ALL=(ALL:ALL) ALL' > $A/etc/sudoers.d/wheel
chmod 440 $A/etc/sudoers.d/wheel
echo 'file_permissions+=(["/etc/sudoers.d/wheel"]="0:0:440")' >> ~/live/profiledef.sh
echo KEYMAP=br-abnt2 > $A/etc/vconsole.conf
ln -sf /usr/share/zoneinfo/America/Sao_Paulo $A/etc/localtime

echo "== 6/7 Boot options (RAM copy) and build"
grep -rl 'archisobasedir=%INSTALL_DIR%' ~/live | xargs sed -i 's/archisobasedir=%INSTALL_DIR%/& copytoram=y cow_spacesize=1G/'
grep -rq copytoram ~/live || { echo "ERROR: could not add boot options"; exit 1; }
mkarchiso -w ~/work -o ~/out ~/live

echo "== 7/7 Copying ISO to Windows"
cp ~/out/*.iso "$OUT"/
rm -rf ~/work
ls -lh "$OUT"/*.iso
SIZE=$(stat -c %s ~/out/*.iso)
[ $SIZE -lt 3800000000 ] || echo "WARNING: ISO may be too big for the 4 GB stick"
echo "== DONE. The ISO is in your Downloads folder"