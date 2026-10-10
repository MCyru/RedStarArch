#!/bin/bash
# =====================================================================
#  Arch live ISO "Aesthetic" - Red Star
#  Uso:  sudo ./build-arch-aesthetic.sh /caminho/wallpaper.(jpg|png|mp4|webm|gif) /caminho/saida
#  Roda no WSL (Arch) ou em qualquer Arch, como root, com internet. O intuito é criar uma iso pra instalar em um pendrive ou maquina essa customizacao especifica.
# =====================================================================
set -e
WALL="$1"
OUT="$2"

# ---------- Ajustes rapidos (mexa aqui) ----------
USERNAME="prickett"
PASSWORD="159951"
THEME="auto"          # auto = cores tiradas do wallpaper | blue | pink | violet para o meu wallpaper da liino
FLOATING=0            # 1 = janelas flutuantes (mais "Windows"), 0 = tiling
COPYTORAM=1           # 1 = copia tudo p/ RAM (rapido, pendrive pode ser removido; precisa de RAM >= tamanho da ISO + ~2GB) (Serve pra install não persistente em um pendrive pra facilidade de uso)
INSTALL_EXTRAS=1      # 1 = LibreOffice, GIMP, loja de apps (Flatpak), fontes CJK etc.
AUR_PKGS="mpvpaper"   # pacotes do AUR compilados no build (mpvpaper = wallpaper animado)
# -------------------------------------------------

echo "== 1/9 Checking wallpaper" # checa o comando de wallpaper e se e animado.
[ -f "$WALL" ] || { echo "ERROR: wallpaper not found at $WALL"; exit 1; }
[ -n "$OUT" ] || { echo "ERROR: usage: $0 wallpaper output_dir"; exit 1; }
mkdir -p "$OUT"
WALL_EXT=$(echo "${WALL##*.}" | tr 'A-Z' 'a-z')
case "$WALL_EXT" in mp4|webm|mkv|mov|gif) IS_VIDEO=1 ;; *) IS_VIDEO=0 ;; esac

echo "== 2/9 Installing archiso and build tools" #install a nivel basico do arch
pacman-key --init
pacman-key --populate archlinux
pacman -Syu --noconfirm archiso git nano base-devel sudo python-pillow code

echo "== 3/9 Colors" #ajuste de cores e tematicas
hex2rgb() { printf '%d, %d, %d' "0x${1:0:2}" "0x${1:2:2}" "0x${1:4:2}"; }
case "$THEME" in
  pink)   ACC=ffb3d9; SEC=c3a6ff ;; # ajustar manualmente se quiser, recomendo que nao no entanto
  violet) ACC=c3a6ff; SEC=a9c8ff ;; # '' '' 
  auto)
    if [ $IS_VIDEO = 0 ]; then #Daqui pra frente mecheu quebra, so ignorar o auto target do video
      PAL=$(python3 - "$WALL" << 'PY' 2>/dev/null || true
import sys, colorsys
from collections import Counter
from PIL import Image
im = Image.open(sys.argv[1]).convert("RGB").resize((96, 96))
bins = Counter()
for r, g, b in (im.get_flattened_data() if hasattr(im, "get_flattened_data") else im.getdata()):
    h, s, v = colorsys.rgb_to_hsv(r/255, g/255, b/255)
    if s > 0.22 and v > 0.35:
        bins[int(h*18)] += s*v
if not bins:
    print("a9c8ff c3a6ff"); sys.exit()
top = [k for k, _ in bins.most_common(8)]
h1 = (top[0]+0.5)/18
h2 = None
for k in top[1:]:
    d = min(abs(k-top[0]), 18-abs(k-top[0]))
    if d >= 3:
        h2 = (k+0.5)/18; break
if h2 is None:
    h2 = (h1+0.12) % 1
def pas(h):
    r, g, b = colorsys.hsv_to_rgb(h, 0.38, 1.0)
    return "%02x%02x%02x" % (int(r*255), int(g*255), int(b*255))
print(pas(h1), pas(h2))
PY
)
    fi
    ACC=${PAL%% *}; SEC=${PAL##* }
    [ ${#ACC} = 6 ] && [ ${#SEC} = 6 ] || { ACC=a9c8ff; SEC=c3a6ff; }
    ;;
  *)      ACC=a9c8ff; SEC=c3a6ff ;;
esac
ACC_RGB=$(hex2rgb $ACC); SEC_RGB=$(hex2rgb $SEC)
echo "Accent: #$ACC  Secondary: #$SEC"

echo "== 4/9 Profile, packages and AUR" #Configuracao de perfis
rm -rf ~/live ~/work ~/out ~/repo
cp -r /usr/share/archiso/configs/baseline ~/live
echo >> ~/live/packages.x86_64

REQUIRED="
linux-firmware
networkmanager
network-manager-applet
sudo
nano
git
gcc
make
clang
gdb
cmake
ripgrep
fd
hyprland
hyprlock
hypridle
xorg-xwayland
xdg-desktop-portal-hyprland
xdg-desktop-portal-gtk
qt5-wayland
qt6-wayland
polkit
polkit-gnome
dconf
libnotify
socat
wtype
xdg-utils
udisks2
ntfs-3g
exfatprogs
dosfstools
sof-firmware
alsa-ucm-conf
wpa_supplicant
wireless-regdb
iw
labwc
mesa
vulkan-radeon
vulkan-intel
pipewire
pipewire-alsa
pipewire-pulse
wireplumber
pavucontrol
bluez
bluez-utils
blueman
brightnessctl
playerctl
waybar
wofi
swaync
swaybg
swappy
cliphist
kitty
thunar
thunar-archive-plugin
tumbler
ffmpegthumbnailer
file-roller
gvfs
firefox
code
neovim
zathura
zathura-pdf-mupdf
ranger
python-pillow
jq
grim
slurp
wl-clipboard
btop
fastfetch
mpv
ttf-dejavu
ttf-jetbrains-mono-nerd
noto-fonts
noto-fonts-emoji
spotify-launcher
"
OPTIONAL="
papirus-icon-theme
adw-gtk-theme
bibata-cursor-theme
nwg-look
nwg-displays
hyprsunset
nwg-drawer
vulkan-nouveau
vulkan-swrast
intel-media-driver
libva-mesa-driver
loupe
gnome-calculator
"
EXTRAS="
libreoffice-fresh
gimp
noto-fonts-cjk
flatpak
gnome-software
"
for p in $REQUIRED; do echo "$p" >> ~/live/packages.x86_64; done #retry
MISS=0
for p in $(grep -v '^#' ~/live/packages.x86_64 | grep -v '^$' | sort -u); do
  pacman -Si "$p" >/dev/null 2>&1 || { echo "MISSING PACKAGE: $p"; MISS=1; }
done
[ $MISS = 0 ] || { echo "ERROR: fix the package names above and run again"; exit 1; }

HAS_CURSOR=0; HAS_PAPIRUS=0; HAS_ADW=0; HAS_FLATPAK=0
add_optional() {
  for p in $1; do
    if pacman -Si "$p" >/dev/null 2>&1; then
      echo "$p" >> ~/live/packages.x86_64
      case "$p" in
        bibata-cursor-theme) HAS_CURSOR=1 ;;
        papirus-icon-theme)  HAS_PAPIRUS=1 ;;
        adw-gtk-theme)       HAS_ADW=1 ;;
        flatpak)             HAS_FLATPAK=1 ;;
      esac
    else
      echo "WARNING: optional package not found, skipping: $p"
    fi
  done
}
add_optional "$OPTIONAL"
[ "$INSTALL_EXTRAS" = 1 ] && add_optional "$EXTRAS"

# --- pacotes do AUR (compilados aqui, entram na ISO por um repo local) ---
AUR_OK=""
REPO=$HOME/repo
mkdir -p $REPO
if [ -n "$AUR_PKGS" ]; then
  id builder >/dev/null 2>&1 || useradd -m builder
  echo 'builder ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/99-builder
  for p in $AUR_PKGS; do
    rm -rf /tmp/aur-$p
    if sudo -u builder git clone --depth 1 https://aur.archlinux.org/$p.git /tmp/aur-$p \
       && (cd /tmp/aur-$p && sudo -u builder makepkg -s --noconfirm --needed); then
      cp /tmp/aur-$p/*.pkg.tar.zst $REPO/ && AUR_OK="$AUR_OK $p"
    else
      echo "WARNING: AUR package failed to build, skipping: $p"
    fi
  done
  rm -f /etc/sudoers.d/99-builder
fi
if [ -n "$AUR_OK" ]; then
  repo-add $REPO/custom.db.tar.gz $REPO/*.pkg.tar.zst
  printf '\n[custom]\nSigLevel = Optional TrustAll\nServer = file://%s\n' "$REPO" >> ~/live/pacman.conf
  for p in $AUR_OK; do echo "$p" >> ~/live/packages.x86_64; done
fi
if [ $IS_VIDEO = 1 ] && ! echo "$AUR_OK" | grep -qw mpvpaper; then
  echo "ERROR: wallpaper is a video but mpvpaper did not build. Use an image or fix the AUR build."; exit 1
fi

# A sintaxe de regras do Hyprland mudou na 0.53: detecta a versao do repo. isso quebra de um jeito tao esquisito a depender do ambiente, better safe than sorry
HV=$(pacman -Si hyprland | awk '/^Version/{print $3}' | cut -d- -f1)
if [ "$(printf '%s\n%s\n' 0.53.0 "$HV" | sort -V | head -n1)" = "0.53.0" ]; then NEWRULES=1; else NEWRULES=0; fi
echo "Hyprland $HV (new rule syntax: $NEWRULES)"

echo "== 5/9 Hyprland, lock screen, idle" #ajuste das config
S=~/live/airootfs/etc/skel
mkdir -p $S/.config/hypr $S/.config/waybar $S/.config/wofi $S/.config/swaync $S/.config/kitty
mkdir -p "$S/.config/Code - OSS/User" $S/.config/gtk-3.0 $S/.config/gtk-4.0 $S/.local/bin $S/.local/share/applications
mkdir -p $S/Pictures $S/dev
cp "$WALL" $S/Pictures/wall.$WALL_EXT

cat > $S/.config/hypr/hyprland.conf << 'EOF'
monitor=,preferred,auto,1
$mod = SUPER

env = MOZ_ENABLE_WAYLAND,1
env = GTK_THEME,adw-gtk3-dark
env = XCURSOR_SIZE,24
env = QT_QPA_PLATFORM,wayland;xcb

input {
    kb_layout = br
    follow_mouse = 1
    touchpad {
        natural_scroll = true
        tap-to-click = true
    }
}

general {
    gaps_in = 6
    gaps_out = 14
    border_size = 2
    col.active_border = rgba(@ACC@ee) rgba(@SEC@ee) 45deg
    col.inactive_border = rgba(1a2150aa)
    resize_on_border = true
}

decoration {
    rounding = 14
    active_opacity = 0.90
    inactive_opacity = 0.78
    blur {
        enabled = true
        size = 9
        passes = 3
        noise = 0.02
        vibrancy = 0.25
        new_optimizations = true
    }
    shadow {
        enabled = true
        range = 20
        render_power = 3
        color = rgba(050816cc)
    }
}

animations {
    enabled = true
    bezier = smooth, 0.22, 1, 0.36, 1
    animation = windows, 1, 5, smooth, popin 80%
    animation = windowsOut, 1, 4, smooth, popin 80%
    animation = fade, 1, 5, smooth
    animation = layers, 1, 5, smooth, fade
    animation = workspaces, 1, 6, smooth, slide
}

dwindle {
    preserve_split = true
}

misc {
    disable_hyprland_logo = true
    disable_splash_rendering = true
    force_default_wallpaper = 0
}

exec-once = waybar
exec-once = swaync
exec-once = nm-applet --indicator
exec-once = blueman-applet
exec-once = /usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1
exec-once = hypridle
exec-once = ~/.local/bin/taskbar-daemon
exec-once = ~/.local/bin/net-tasks
exec-once = ~/.local/bin/lite-mode boot
exec-once = wl-paste --type text --watch cliphist store
exec-once = wl-paste --type image --watch cliphist store
exec-once = gsettings set org.gnome.desktop.interface color-scheme prefer-dark

# Programas
bind = $mod, RETURN, exec, kitty
bind = $mod, D, exec, ~/.local/bin/start-menu
bind = $mod, SPACE, exec, ~/.local/bin/start-menu
bind = $mod, E, exec, thunar
bind = $mod, C, exec, code
bind = $mod, B, exec, firefox
bind = $mod, S, exec, ~/.local/bin/file-search
bind = $mod, I, exec, ~/.local/bin/settings-menu
bind = $mod, P, exec, ~/.local/bin/display-mode
bind = $mod, PERIOD, exec, ~/.local/bin/emoji-picker
bind = $mod SHIFT, B, exec, ~/.local/bin/lite-mode
bind = $mod, X, exec, ~/.local/bin/power-menu
bind = $mod, N, exec, swaync-client -t -sw
bind = $mod, L, exec, hyprlock
bind = CTRL SHIFT, Escape, exec, kitty -e btop

# Area de transferencia (Win+V) e capturas (Win+Shift+S)
bind = $mod, V, exec, cliphist list | wofi --dmenu --prompt "Area de transferencia" | cliphist decode | wl-copy
bind = $mod SHIFT, S, exec, grim -g "$(slurp)" - | swappy -f -
bind = , Print, exec, grim -g "$(slurp)" - | wl-copy
bind = SHIFT, Print, exec, grim ~/Pictures/print-$(date +%s).png

# Janelas (estilo Windows)
bind = $mod, Q, killactive
bind = ALT, F4, killactive
bind = ALT, TAB, cyclenext
bind = $mod, F, fullscreen
bind = $mod, UP, fullscreen, 1
bind = $mod, DOWN, togglefloating
bind = $mod, T, togglefloating
bind = $mod SHIFT, E, exit
bind = $mod, left, movefocus, l
bind = $mod, right, movefocus, r
bind = $mod SHIFT, left, movewindow, l
bind = $mod SHIFT, right, movewindow, r
bind = $mod ALT, left, exec, ~/.local/bin/snap left
bind = $mod ALT, right, exec, ~/.local/bin/snap right
bind = $mod ALT, up, exec, ~/.local/bin/snap max
bind = $mod ALT, 1, exec, ~/.local/bin/snap tl
bind = $mod ALT, 2, exec, ~/.local/bin/snap tr
bind = $mod ALT, 3, exec, ~/.local/bin/snap bl
bind = $mod ALT, 4, exec, ~/.local/bin/snap br
bindm = $mod, mouse:272, movewindow
bindm = $mod, mouse:273, resizewindow

# Workspaces
bind = $mod, 1, workspace, 1
bind = $mod, 2, workspace, 2
bind = $mod, 3, workspace, 3
bind = $mod, 4, workspace, 4
bind = $mod SHIFT, 1, movetoworkspace, 1
bind = $mod SHIFT, 2, movetoworkspace, 2
bind = $mod SHIFT, 3, movetoworkspace, 3
bind = $mod SHIFT, 4, movetoworkspace, 4

# Volume, brilho, midia
bindel = , XF86AudioRaiseVolume, exec, wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ 5%+
bindel = , XF86AudioLowerVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-
bindl = , XF86AudioMute, exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle
bindel = , XF86MonBrightnessUp, exec, brightnessctl set 5%+
bindel = , XF86MonBrightnessDown, exec, brightnessctl set 5%-
bindl = , XF86AudioPlay, exec, playerctl play-pause
bindl = , XF86AudioNext, exec, playerctl next
bindl = , XF86AudioPrev, exec, playerctl previous
EOF

# Wallpaper: imagem (swaybg) ou video/gif animado (mpvpaper)
if [ $IS_VIDEO = 1 ]; then
  echo "exec-once = mpvpaper -o \"no-audio loop panscan=1.0\" '*' \$HOME/Pictures/wall.$WALL_EXT" >> $S/.config/hypr/hyprland.conf
else
  echo "exec-once = swaybg -i \$HOME/Pictures/wall.$WALL_EXT -m fill" >> $S/.config/hypr/hyprland.conf
fi

# Regras dependentes da versao do Hyprland (blur nas barras, janelas flutuantes) (Recomendo nao mexer a partir daqui porque tem tanto config pra safe boot quanto customizacao se quebrar n me responsabilizo)
if [ $NEWRULES = 1 ]; then
cat >> $S/.config/hypr/hyprland.conf << 'EOF'

layerrule = blur on, match:namespace ^(waybar|wofi|nwg-drawer|swaync-control-center|swaync-notification-window)$
windowrule = float on, match:class ^(pavucontrol|nm-connection-editor|blueman-manager|org.gnome.Calculator|swappy)$
EOF
  if [ "$FLOATING" = 1 ]; then
    printf '%s\n' 'windowrule = float on, match:class .*' 'windowrule = center on, match:class .*' >> $S/.config/hypr/hyprland.conf
  fi
else
cat >> $S/.config/hypr/hyprland.conf << 'EOF'

layerrule = blur, waybar
layerrule = blur, wofi
layerrule = blur, nwg-drawer
layerrule = ignorezero, nwg-drawer
layerrule = blur, swaync-control-center
layerrule = blur, swaync-notification-window
layerrule = ignorezero, wofi
layerrule = ignorezero, swaync-control-center
layerrule = ignorezero, swaync-notification-window
windowrulev2 = float, class:^(pavucontrol|nm-connection-editor|blueman-manager|org.gnome.Calculator|swappy)$
EOF
  if [ "$FLOATING" = 1 ]; then
    printf '%s\n' 'windowrulev2 = float, class:.*' 'windowrulev2 = center, class:.*' >> $S/.config/hypr/hyprland.conf
  fi
fi
if [ $HAS_CURSOR = 1 ]; then
  echo 'env = XCURSOR_THEME,Bibata-Modern-Ice' >> $S/.config/hypr/hyprland.conf
  echo 'exec-once = hyprctl setcursor Bibata-Modern-Ice 24' >> $S/.config/hypr/hyprland.conf
fi

cat > $S/.config/hypr/hyprlock.conf << 'EOF'
general {
    hide_cursor = true
}
background {
    monitor =
    path = screenshot
    blur_passes = 3
    blur_size = 7
    brightness = 0.65
}
input-field {
    monitor =
    size = 300, 54
    outline_thickness = 2
    inner_color = rgba(10, 14, 36, 0.6)
    outer_color = rgba(@ACC_RGB@, 0.85)
    font_color = rgb(219, 230, 255)
    fade_on_empty = true
    placeholder_text = Senha
    rounding = 27
    position = 0, -130
    halign = center
    valign = center
}
label {
    monitor =
    text = $TIME
    font_size = 110
    font_family = JetBrainsMono Nerd Font
    color = rgba(219, 230, 255, 1.0)
    position = 0, 130
    halign = center
    valign = center
}
EOF
cat > $S/.config/hypr/hypridle.conf << 'EOF'
general {
    lock_cmd = pidof hyprlock || hyprlock
    before_sleep_cmd = loginctl lock-session
    after_sleep_cmd = hyprctl dispatch dpms on
}
listener {
    timeout = 600
    on-timeout = loginctl lock-session
}
listener {
    timeout = 900
    on-timeout = hyprctl dispatch dpms off
    on-resume = hyprctl dispatch dpms on
}
EOF

cat > $S/.bash_profile << 'EOF'
if [ "$(tty)" = "/dev/tty1" ]; then
  if grep -qw 'aessafe=1' /proc/cmdline; then exec ~/.local/bin/start-fallback; fi
  if command -v start-hyprland >/dev/null 2>&1; then start-hyprland; else Hyprland; fi
  rc=$?
  # saida normal (Super+Shift+E) = 0; erro/crash = abre o desktop de emergencia
  if [ $rc -ne 0 ]; then exec ~/.local/bin/start-fallback; fi
  exit 0
fi
EOF

echo "== 6/9 Taskbar, start menu, notification center"
cat > $S/.local/bin/app-state << 'EOF'
#!/bin/bash
# imprime classe "running" ou "idle" para o icone da barra
if hyprctl clients -j | jq -e --arg c "$1" 'any(.[]; .class | test($c; "i"))' >/dev/null 2>&1; then
  echo '{"text":"x","class":"running"}'
else
  echo '{"text":"x","class":"idle"}'
fi
EOF
cat > $S/.local/bin/focus-or-launch << 'EOF'
#!/bin/bash
# focus-or-launch <regex-da-classe> <comando...>
cls="$1"; shift
addr=$(hyprctl clients -j | jq -r --arg c "$cls" '[.[] | select(.class | test($c; "i"))][0].address // empty')
if [ -n "$addr" ]; then hyprctl dispatch focuswindow "address:$addr"; else exec "$@"; fi
EOF
cat > $S/.local/bin/power-menu << 'EOF'
#!/bin/bash
c=$(printf 'Bloquear\nDesligar\nReiniciar\nSair da sessao\n' | wofi --dmenu --prompt "Energia" --width 320 --height 260 --hide-scroll)
case "$c" in
  Bloquear) hyprlock ;;
  Desligar) systemctl poweroff ;;
  Reiniciar) systemctl reboot ;;
  "Sair da sessao") hyprctl dispatch exit ;;
esac
EOF
cat > $S/.local/bin/spotify-mods << 'EOF'
#!/bin/bash
# Instala o Spicetify (extensoes/temas do Spotify). Precisa de internet.
echo "Abra o Spotify uma vez, faca login e feche. Depois aperte Enter."
read -r _
curl -fsSL https://raw.githubusercontent.com/spicetify/cli/main/install.sh | sh
export PATH="$HOME/.spicetify:$PATH"
spicetify config spotify_path "$HOME/.local/share/spotify-launcher/install/usr/share/spotify"
spicetify config prefs_path "$HOME/.config/spotify/prefs"
spicetify backup apply
echo "Pronto. Reabra o Spotify."
read -r _
EOF
cat > $S/.local/bin/taskbar-daemon << 'EOF'
#!/bin/bash
# Atualiza os icones da barra so quando uma janela abre/fecha (sem polling).
sock="$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock"
while [ ! -S "$sock" ]; do sleep 1; done
socat -U - "UNIX-CONNECT:$sock" | while read -r line; do
  case "$line" in
    openwindow*|closewindow*) pkill -RTMIN+8 waybar ;;
  esac
done
EOF
cat > $S/.local/bin/start-menu << 'EOF'
#!/bin/bash
# Menu Iniciar: grade de apps (nwg-drawer) ou lista (wofi) se o drawer nao existir/falhar
if command -v nwg-drawer >/dev/null 2>&1; then
  if pgrep -x nwg-drawer >/dev/null; then pkill -x nwg-drawer; exit 0; fi
  t0=$(date +%s%N)
  nwg-drawer -ovl -nocats -is 52 -c 6
  rc=$?
  el=$(( ($(date +%s%N) - t0) / 1000000 ))
  if [ $rc -eq 0 ] || [ $el -gt 1500 ]; then exit 0; fi
fi
pkill wofi || exec wofi --show drun
EOF
cat > $S/.local/bin/lite-mode << 'EOF'
#!/bin/bash
# Modo leve: sem blur, sombras, animacoes e transparencia (para PCs fracos). Win+Shift+B alterna.
F=/tmp/lite-mode.on
on() {
  hyprctl --batch "keyword decoration:blur:enabled 0 ; keyword decoration:shadow:enabled 0 ; keyword animations:enabled 0 ; keyword decoration:active_opacity 1 ; keyword decoration:inactive_opacity 1 ; keyword decoration:rounding 0 ; keyword general:gaps_in 2 ; keyword general:gaps_out 4" >/dev/null
  touch $F; notify-send "Modo leve" "Ligado"
}
off() { hyprctl reload >/dev/null; rm -f $F; notify-send "Modo leve" "Desligado"; }
case "$1" in
  on) on ;;
  off) off ;;
  boot) grep -qw 'aeslite=1' /proc/cmdline && { sleep 3; on; } ;;
  *) if [ -f $F ]; then off; else on; fi ;;
esac
EOF
cat > $S/.local/bin/start-fallback << 'EOF'
#!/bin/bash
# Desktop de emergencia (labwc, renderizacao por software) se o Hyprland nao subir
export WLR_RENDERER=pixman
export WLR_NO_HARDWARE_CURSORS=1
export XDG_CURRENT_DESKTOP=labwc
exec labwc
EOF
cat > $S/.local/bin/snap << 'EOF'
#!/bin/bash
# snap left|right|max|tl|tr|bl|br : encaixa a janela ativa (estilo Win+setas)
m=$(hyprctl monitors -j | jq '[.[] | select(.focused)][0]')
read -r mx my mw mh rl rt rr rb < <(jq -r '[.x,.y,(.width/.scale|floor),(.height/.scale|floor),.reserved[0],.reserved[1],.reserved[2],.reserved[3]] | @tsv' <<<"$m")
g=14
ux=$((mx+rl+g)); uy=$((my+rt+g)); uw=$((mw-rl-rr-2*g)); uh=$((mh-rt-rb-2*g))
hw=$(( (uw-g)/2 )); hh=$(( (uh-g)/2 ))
case "$1" in
  left)  x=$ux; y=$uy; w=$hw; h=$uh ;;
  right) x=$((ux+hw+g)); y=$uy; w=$hw; h=$uh ;;
  max)   x=$ux; y=$uy; w=$uw; h=$uh ;;
  tl)    x=$ux; y=$uy; w=$hw; h=$hh ;;
  tr)    x=$((ux+hw+g)); y=$uy; w=$hw; h=$hh ;;
  bl)    x=$ux; y=$((uy+hh+g)); w=$hw; h=$hh ;;
  br)    x=$((ux+hw+g)); y=$((uy+hh+g)); w=$hw; h=$hh ;;
  *) exit 1 ;;
esac
[ "$(hyprctl activewindow -j | jq -r '.floating')" = true ] || hyprctl dispatch setfloating >/dev/null
hyprctl --batch "dispatch resizewindowpixel exact $w $h,activewindow ; dispatch movewindowpixel exact $x $y,activewindow" >/dev/null
EOF
cat > $S/.local/bin/display-mode << 'EOF'
#!/bin/bash
# Win+P: estender, duplicar (projetor), so uma tela
mapfile -t mons < <(hyprctl monitors all -j | jq -r '.[].name')
prim=${mons[0]}
c=$(printf 'Estender (duas telas)\nDuplicar (projetor)\nSomente tela principal\nSomente segunda tela\n' | wofi --dmenu --prompt "Projetar" --width 360 --height 260 --hide-scroll)
case "$c" in
  Estender*) for m in "${mons[@]}"; do hyprctl keyword monitor "$m,preferred,auto,1" >/dev/null; done ;;
  Duplicar*) for m in "${mons[@]:1}"; do hyprctl keyword monitor "$m,preferred,auto,1,mirror,$prim" >/dev/null; done ;;
  "Somente tela principal") for m in "${mons[@]:1}"; do hyprctl keyword monitor "$m,disable" >/dev/null; done ;;
  "Somente segunda tela") [ -n "${mons[1]}" ] && hyprctl keyword monitor "$prim,disable" >/dev/null ;;
esac
EOF
cat > $S/.local/bin/emoji-picker << 'EOF'
#!/bin/bash
# Win+. : escolhe um emoji e digita na janela ativa
sel=$(wofi --dmenu -i --prompt "Emoji" --width 480 --height 440 < "$HOME/.local/share/emoji.txt") || exit 0
ch=${sel%% *}
[ -n "$ch" ] || exit 0
printf '%s' "$ch" | wl-copy
sleep 0.25
wtype "$ch"
EOF
cat > $S/.local/bin/file-search << 'EOF'
#!/bin/bash
# Win+S : pesquisa arquivos na home e nos discos montados
sel=$( { fd . "$HOME" --max-depth 7 --exclude .cache --exclude .git 2>/dev/null; fd . /run/media --max-depth 7 2>/dev/null; } \
  | wofi --dmenu -i --prompt "Pesquisar arquivos" --width 680 --height 460 ) || exit 0
[ -n "$sel" ] && xdg-open "$sel"
EOF
cat > $S/.local/bin/settings-menu << 'EOF'
#!/bin/bash
# Win+I : central de configuracoes
c=$(printf '%s\n' "Wi-Fi e rede" "Som" "Bluetooth" "Telas e projetor" "Resolucao e posicao das telas" "Aparencia (tema e icones)" "Luz noturna (liga/desliga)" "Modo leve (liga/desliga)" "Loja de apps" "Gerenciador de tarefas" \
  | wofi --dmenu --prompt "Configuracoes" --width 420 --height 400 --hide-scroll)
case "$c" in
  "Wi-Fi e rede") ~/.local/bin/wifi-menu ;;
  "Som") pavucontrol ;;
  "Bluetooth") blueman-manager ;;
  "Telas e projetor") ~/.local/bin/display-mode ;;
  "Resolucao e posicao das telas") nwg-displays ;;
  "Aparencia (tema e icones)") nwg-look ;;
  "Luz noturna (liga/desliga)") pkill hyprsunset || hyprsunset -t 4000 ;;
  "Modo leve (liga/desliga)") ~/.local/bin/lite-mode ;;
  "Loja de apps") gnome-software ;;
  "Gerenciador de tarefas") kitty -e btop ;;
esac
EOF
cat > $S/.local/bin/wifi-menu << 'EOF'
#!/bin/bash
# Menu de Wi-Fi (wofi + nmcli). Redes empresariais (802.1X/eduroam) abrem o editor completo.
W() { wofi --dmenu -i --width 420 --height 400 --hide-scroll "$@"; }
nmcli radio wifi on >/dev/null 2>&1
nmcli dev wifi rescan >/dev/null 2>&1; sleep 2
while true; do
  list=$(nmcli -t --escape no -f SIGNAL,SECURITY,SSID dev wifi list --rescan no 2>/dev/null \
    | sort -t: -k1,1 -nr \
    | while IFS=: read -r sig sec ssid; do [ -n "$ssid" ] && echo "$ssid  ($sig%)"; done \
    | awk '{k=$0; sub(/  \([0-9]+%\)$/,"",k); if(!seen[k]++) print}')
  choice=$(printf '%s\n%s\n%s\n' "$list" "Atualizar lista" "Editor avancado (redes empresariais ou ocultas)" | sed '/^$/d' | W --prompt "Wi-Fi")
  [ -n "$choice" ] || exit 1
  case "$choice" in
    "Atualizar lista") nmcli dev wifi rescan >/dev/null 2>&1; sleep 2; continue ;;
    "Editor avancado"*) nm-connection-editor; exit 0 ;;
  esac
  ssid=$(printf '%s' "$choice" | sed 's/  ([0-9]*%)$//')
  sec=$(nmcli -t --escape no -f SECURITY,SSID dev wifi list --rescan no 2>/dev/null | awk -F: -v s="$ssid" '{ x=$0; sub(/^[^:]*:/,"",x); if (x==s) { print $1; exit } }')
  case "$sec" in
    *802.1X*) notify-send "Rede empresarial" "Configure $ssid no editor que vai abrir"; nm-connection-editor; exit 0 ;;
  esac
  if nmcli -t -f NAME connection show | grep -Fxq "$ssid"; then
    if nmcli connection up id "$ssid" >/dev/null 2>&1; then notify-send "Wi-Fi" "Conectado a $ssid"; exit 0; fi
  fi
  if [ -z "$sec" ] || [ "$sec" = "--" ]; then
    if nmcli dev wifi connect "$ssid" >/dev/null 2>&1; then notify-send "Wi-Fi" "Conectado a $ssid"; exit 0; fi
  else
    pw=$(wofi --dmenu --password --prompt "Senha de $ssid" --width 420 --height 110 </dev/null)
    [ -n "$pw" ] || continue
    if nmcli dev wifi connect "$ssid" password "$pw" >/dev/null 2>&1; then notify-send "Wi-Fi" "Conectado a $ssid"; exit 0; fi
    nmcli connection delete id "$ssid" >/dev/null 2>&1
  fi
  notify-send "Wi-Fi" "Nao foi possivel conectar a $ssid"
done
EOF
cat > $S/.local/bin/net-tasks << 'EOF'
#!/bin/bash
# Tarefas que precisam de internet (ficam em ~/.local/share/net-tasks).
# Se nao houver rede, abre o menu de Wi-Fi uma vez; se voce pular, continua em segundo
# plano e roda sozinho assim que houver conexao (cabo, Wi-Fi do menu ou do icone da bandeja).
D="$HOME/.local/share/net-tasks"; M="$HOME/.cache/net-tasks"; mkdir -p "$M"
online() { curl -fsI --max-time 5 https://archlinux.org >/dev/null 2>&1; }
pending() { for t in "$D"/*.sh; do [ -e "$t" ] || continue; [ -e "$M/$(basename "$t").done" ] || return 0; done; return 1; }
pending || exit 0
sleep 6
for i in 1 2 3 4 5 6; do online && break; sleep 2; done
if ! online; then
  notify-send "Sem internet" "Escolha uma rede Wi-Fi. Se pular, as tarefas rodam sozinhas quando voce conectar (clique no icone de rede)."
  ~/.local/bin/wifi-menu
fi
tries=0
while pending && [ $tries -lt 5 ]; do
  until online; do sleep 10; done
  notify-send "Configuracao inicial" "Baixando itens em segundo plano..."
  for t in "$D"/*.sh; do
    [ -e "$t" ] || continue
    n=$(basename "$t")
    [ -e "$M/$n.done" ] && continue
    if timeout 900 bash "$t" >> "$M/log" 2>&1; then touch "$M/$n.done"; fi
  done
  tries=$((tries+1))
done
pending || notify-send "Configuracao inicial" "Tudo pronto."
EOF
chmod +x $S/.local/bin/*

# Tarefas de rede (rodam sozinhas quando houver internet)
mkdir -p $S/.local/share/net-tasks $S/.cache
if [ $HAS_FLATPAK = 1 ]; then
cat > $S/.local/share/net-tasks/10-flathub.sh << 'EOF'
#!/bin/bash
flatpak --user remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo && flatpak --user update --appstream -y
EOF
fi
cat > $S/.local/share/net-tasks/20-neovim-plugins.sh << 'EOF'
#!/bin/bash
nvim --headless "+Lazy! sync" +qa
EOF

# Lista de emojis offline (Win+.)
python3 - > $S/.local/share/emoji.txt << 'PY'
import unicodedata
ranges = [(0x1F300, 0x1F64F), (0x1F680, 0x1F6FF), (0x1F900, 0x1FAFF), (0x2600, 0x27BF), (0x2B50, 0x2B55)]
for a, b in ranges:
    for c in range(a, b + 1):
        try:
            n = unicodedata.name(chr(c)).lower()
        except ValueError:
            continue
        print(chr(c) + "  " + n)
PY

# Menu Iniciar em grade (nwg-drawer) com apps fixados
mkdir -p $S/.config/nwg-drawer
cat > $S/.config/nwg-drawer/drawer.css << 'EOF'
window {
  background-color: rgba(10, 14, 36, 0.80);
  color: #dbe6ff;
  font-family: "JetBrainsMono Nerd Font", "Noto Sans", sans-serif;
}
#searchbox {
  background-color: rgba(255, 255, 255, 0.08);
  color: #dbe6ff;
  border: 1px solid rgba(@SEC_RGB@, 0.40);
  border-radius: 14px;
  padding: 8px 14px;
  margin: 28px 160px 18px 160px;
}
button, image { background: none; border: none; box-shadow: none; color: #dbe6ff; }
button:hover { background-color: rgba(@ACC_RGB@, 0.18); border-radius: 14px; }
EOF
printf '%s\n' firefox.desktop thunar.desktop code-oss.desktop kitty.desktop spotify-launcher.desktop org.gnome.Software.desktop pavucontrol.desktop > $S/.cache/nwg-pin-cache

# Atalhos no menu Iniciar (sem terminal)
cat > $S/.local/share/applications/configuracoes.desktop << 'EOF'
[Desktop Entry]
Type=Application
Name=Configuracoes
Comment=Wi-Fi, som, telas, bluetooth e aparencia
Exec=/home/@USER@/.local/bin/settings-menu
Icon=preferences-system
Terminal=false
Categories=Settings;
EOF
cat > $S/.local/share/applications/wifi.desktop << 'EOF'
[Desktop Entry]
Type=Application
Name=Conectar ao Wi-Fi
Exec=/home/@USER@/.local/bin/wifi-menu
Icon=network-wireless
Terminal=false
Categories=Settings;Network;
EOF
cat > $S/.local/share/applications/modo-leve.desktop << 'EOF'
[Desktop Entry]
Type=Application
Name=Modo leve (liga/desliga)
Comment=Desativa blur e animacoes em PCs fracos
Exec=/home/@USER@/.local/bin/lite-mode
Icon=utilities-system-monitor
Terminal=false
Categories=Settings;
EOF

cat > $S/.local/share/applications/spotify-mods.desktop << 'EOF'
[Desktop Entry]
Type=Application
Name=Spotify Mods (Spicetify)
Comment=Instalar extensoes e temas no Spotify
Exec=kitty -e /home/@USER@/.local/bin/spotify-mods
Icon=spotify-launcher
Terminal=false
Categories=AudioVideo;
EOF


cat > $S/.config/mimeapps.list << 'EOF'
[Default Applications]
inode/directory=thunar.desktop
text/html=firefox.desktop
x-scheme-handler/http=firefox.desktop
x-scheme-handler/https=firefox.desktop
application/pdf=org.pwmt.zathura.desktop
video/mp4=mpv.desktop
video/x-matroska=mpv.desktop
video/webm=mpv.desktop
audio/mpeg=mpv.desktop
EOF

cat > $S/.config/waybar/config << 'EOF'
{
  "layer": "top",
  "position": "bottom",
  "height": 48,
  "spacing": 4,
  "modules-left": ["hyprland/workspaces"],
  "modules-center": [
    "custom/start",
    "custom/files",
    "custom/firefox",
    "custom/code",
    "custom/terminal",
    "custom/spotify",
    "wlr/taskbar"
  ],
  "modules-right": ["tray", "bluetooth", "pulseaudio", "network", "battery", "custom/notification", "clock"],

  "hyprland/workspaces": {
    "format": "{icon}",
    "format-icons": { "default": "\u25cf", "active": "\u25cf" },
    "persistent-workspaces": { "*": 4 },
    "on-click": "activate"
  },

  "custom/start": {
    "format": "\uf303",
    "tooltip": false,
    "on-click": "~/.local/bin/start-menu",
    "on-click-right": "~/.local/bin/power-menu"
  },
  "custom/files": {
    "format": "\uf07b", "tooltip": false,
    "exec": "~/.local/bin/app-state thunar", "return-type": "json", "interval": "once", "signal": 8,
    "on-click": "~/.local/bin/focus-or-launch thunar thunar"
  },
  "custom/firefox": {
    "format": "\uf269", "tooltip": false,
    "exec": "~/.local/bin/app-state firefox", "return-type": "json", "interval": "once", "signal": 8,
    "on-click": "~/.local/bin/focus-or-launch firefox firefox"
  },
  "custom/code": {
    "format": "\uf121", "tooltip": false,
    "exec": "~/.local/bin/app-state code", "return-type": "json", "interval": "once", "signal": 8,
    "on-click": "~/.local/bin/focus-or-launch code code"
  },
  "custom/terminal": {
    "format": "\uf120", "tooltip": false,
    "exec": "~/.local/bin/app-state kitty", "return-type": "json", "interval": "once", "signal": 8,
    "on-click": "~/.local/bin/focus-or-launch kitty kitty"
  },
  "custom/spotify": {
    "format": "\uf1bc", "tooltip": false,
    "exec": "~/.local/bin/app-state spotify", "return-type": "json", "interval": "once", "signal": 8,
    "on-click": "~/.local/bin/focus-or-launch spotify spotify-launcher"
  },

  "wlr/taskbar": {
    "format": "{icon}",
    "icon-size": 22,
    "tooltip-format": "{title}",
    "on-click": "activate",
    "on-click-middle": "close",
    "ignore-list": ["firefox", "Firefox", "code", "Code", "code-oss", "kitty", "thunar", "Thunar", "spotify", "Spotify"]
  },

  "tray": { "icon-size": 18, "spacing": 10 },
  "bluetooth": {
    "format": "\uf293", "format-disabled": "", "format-off": "",
    "tooltip-format": "Bluetooth",
    "on-click": "blueman-manager"
  },
  "pulseaudio": {
    "format": "{icon}",
    "format-muted": "\uf026",
    "format-icons": { "default": ["\uf027", "\uf028"] },
    "tooltip-format": "Volume: {volume}%",
    "on-click": "pavucontrol",
    "scroll-step": 5
  },
  "network": {
    "format-wifi": "\uf1eb",
    "format-ethernet": "\uf0e8",
    "format-disconnected": "\uf071",
    "tooltip-format-wifi": "{essid} ({signalStrength}%)",
    "tooltip-format-ethernet": "{ifname}",
    "on-click": "~/.local/bin/wifi-menu",
    "on-click-right": "nm-connection-editor"
  },
  "battery": {
    "format": "{icon}",
    "format-charging": "\uf0e7",
    "format-icons": ["\uf244", "\uf243", "\uf242", "\uf241", "\uf240"],
    "tooltip-format": "{capacity}%",
    "states": { "warning": 25, "critical": 12 }
  },
  "custom/notification": {
    "format": "\uf0f3",
    "tooltip": false,
    "on-click": "swaync-client -t -sw",
    "on-click-right": "swaync-client -d -sw"
  },
  "clock": {
    "format": "{:%H:%M}\n{:%d/%m/%Y}",
    "tooltip-format": "<tt>{calendar}</tt>"
  }
}
EOF

cat > $S/.config/waybar/style.css << 'EOF'
* {
  font-family: "JetBrainsMono Nerd Font", "Noto Sans", sans-serif;
  font-size: 15px;
  border: none;
  min-height: 0;
}
window#waybar {
  background: rgba(9, 12, 32, 0.55);
  border-top: 1px solid rgba(@ACC_RGB@, 0.18);
  color: #dbe6ff;
}
tooltip {
  background: rgba(12, 16, 42, 0.92);
  border: 1px solid rgba(@ACC_RGB@, 0.35);
  border-radius: 12px;
}
tooltip label { color: #dbe6ff; }

#workspaces { margin-left: 12px; }
#workspaces button {
  padding: 0 5px;
  margin: 17px 3px;
  font-size: 8px;
  color: rgba(@ACC_RGB@, 0.35);
  border-radius: 8px;
  transition: all 0.25s ease;
}
#workspaces button.active {
  color: #@SEC@;
  padding: 0 12px;
  background: rgba(@SEC_RGB@, 0.18);
}
#workspaces button:hover { color: #ffb3d9; }

#custom-start, #custom-files, #custom-firefox, #custom-code,
#custom-terminal, #custom-spotify {
  font-size: 20px;
  padding: 0 15px;
  margin: 5px 2px;
  border-radius: 12px;
  transition: all 0.2s ease;
}
#custom-start    { color: #@ACC@; }
#custom-files    { color: #ffd6a5; }
#custom-firefox  { color: #ffb3d9; }
#custom-code     { color: #8fb8ff; }
#custom-terminal { color: #@SEC@; }
#custom-spotify  { color: #9ef0c0; }
#custom-start:hover, #custom-files:hover, #custom-firefox:hover,
#custom-code:hover, #custom-terminal:hover, #custom-spotify:hover {
  background: rgba(255, 255, 255, 0.10);
}
#custom-files.idle, #custom-firefox.idle, #custom-code.idle,
#custom-terminal.idle, #custom-spotify.idle { opacity: 0.85; }
#custom-files.running, #custom-firefox.running, #custom-code.running,
#custom-terminal.running, #custom-spotify.running {
  background: rgba(255, 255, 255, 0.07);
  box-shadow: inset 0 -3px 0 #@ACC@;
}

#taskbar button {
  padding: 0 10px;
  margin: 5px 2px;
  border-radius: 12px;
  background: transparent;
}
#taskbar button:hover { background: rgba(255, 255, 255, 0.10); }
#taskbar button.active {
  background: rgba(255, 255, 255, 0.07);
  box-shadow: inset 0 -3px 0 #@SEC@;
}

#tray, #bluetooth, #pulseaudio, #network, #battery, #custom-notification, #clock {
  padding: 0 9px;
  margin: 6px 0;
}
#bluetooth, #pulseaudio, #network, #battery, #custom-notification { color: #@ACC@; font-size: 16px; }
#battery.warning { color: #ffd6a5; }
#battery.critical { color: #ff7a9c; }
#battery.charging { color: #9ef0c0; }
#clock {
  margin-right: 12px;
  border-radius: 10px;
  font-size: 12px;
  color: #dbe6ff;
}
#clock:hover { background: rgba(255, 255, 255, 0.08); }
EOF

cat > $S/.config/wofi/config << 'EOF'
show=drun
prompt=Pesquisar apps
width=560
height=520
location=center
allow_images=true
image_size=30
insensitive=true
hide_scroll=true
no_actions=true
gtk_dark=true
EOF
cat > $S/.config/wofi/style.css << 'EOF'
* { font-family: "JetBrainsMono Nerd Font", "Noto Sans", sans-serif; font-size: 15px; }
window {
  background-color: rgba(10, 14, 36, 0.72);
  border: 1px solid rgba(@ACC_RGB@, 0.35);
  border-radius: 20px;
  color: #dbe6ff;
}
#outer { margin: 18px; }
#input {
  background-color: rgba(255, 255, 255, 0.08);
  color: #dbe6ff;
  border: 1px solid rgba(@SEC_RGB@, 0.35);
  border-radius: 14px;
  padding: 10px 14px;
  margin-bottom: 14px;
}
#input:focus { border-color: #@SEC@; }
#scroll { margin: 0; }
#entry { padding: 8px 12px; border-radius: 12px; }
#entry:selected { background-color: rgba(@ACC_RGB@, 0.18); }
#text { margin-left: 12px; color: #dbe6ff; }
#entry:selected #text { color: #ffffff; }
EOF

# --- central de notificacoes estilo Windows 11 (swaync) ---
cat > $S/.config/swaync/config.json << 'EOF'
{
  "positionX": "right",
  "positionY": "top",
  "control-center-positionX": "right",
  "control-center-positionY": "top",
  "control-center-margin-top": 12,
  "control-center-margin-right": 12,
  "control-center-margin-bottom": 62,
  "control-center-width": 400,
  "notification-window-width": 370,
  "fit-to-screen": false,
  "timeout": 6,
  "widgets": ["title", "dnd", "mpris", "volume", "backlight", "notifications"],
  "widget-config": {
    "title": { "text": "Notificacoes", "clear-all-button": true, "button-text": "Limpar" },
    "dnd": { "text": "Nao perturbe" },
    "mpris": { "image-size": 64, "image-radius": 14 },
    "volume": { "label": "\uf028" },
    "backlight": { "label": "\uf185" }
  }
}
EOF
cat > $S/.config/swaync/style.css << 'EOF'
* { font-family: "JetBrainsMono Nerd Font", "Noto Sans", sans-serif; color: #dbe6ff; }
.control-center {
  background: rgba(10, 14, 36, 0.78);
  border: 1px solid rgba(@ACC_RGB@, 0.35);
  border-radius: 22px;
}
.control-center .widget-title > label { font-size: 16px; }
.control-center .widget-title button, .control-center .widget-dnd switch {
  background: rgba(@ACC_RGB@, 0.18);
  border-radius: 12px;
}
.control-center .widget-mpris, .control-center .widget-volume, .control-center .widget-backlight {
  background: rgba(255, 255, 255, 0.06);
  border-radius: 16px;
  padding: 8px;
  margin: 6px 10px;
}
.notification-row .notification-background .notification,
.floating-notifications.background .notification-row .notification-background .notification {
  background: rgba(12, 16, 48, 0.82);
  border: 1px solid rgba(@ACC_RGB@, 0.30);
  border-radius: 16px;
  margin: 6px 10px;
}
.notification-row .notification-background .notification:hover { background: rgba(@ACC_RGB@, 0.14); }
EOF

echo "== 7/9 Terminal, GTK, Firefox, VS Code, Neovim, Flatpak"
cat > $S/.config/kitty/kitty.conf << 'EOF'
font_family JetBrainsMono Nerd Font
font_size 11.5
window_padding_width 12
background_opacity 1.0
cursor_shape beam
confirm_os_window_close 0
foreground #dbe6ff
background #0b0e22
selection_foreground #0b0e22
selection_background #@ACC@
cursor #@SEC@
color0  #151a38
color8  #3a4278
color1  #ff7a9c
color9  #ff9db8
color2  #9ef0c0
color10 #b9f5d3
color3  #ffd6a5
color11 #ffe4c2
color4  #8fb8ff
color12 #a9c8ff
color5  #c3a6ff
color13 #d6bfff
color6  #9fe3ff
color14 #bcefff
color7  #dbe6ff
color15 #ffffff
EOF

GTKTHEME="Adwaita-dark"; [ $HAS_ADW = 1 ] && GTKTHEME="adw-gtk3-dark"
GTKICON="Adwaita"; [ $HAS_PAPIRUS = 1 ] && GTKICON="Papirus-Dark"
for v in 3.0 4.0; do
cat > $S/.config/gtk-$v/settings.ini << EOF
[Settings]
gtk-theme-name=$GTKTHEME
gtk-icon-theme-name=$GTKICON
gtk-font-name=Noto Sans 10
gtk-application-prefer-dark-theme=1
gtk-cursor-theme-name=Bibata-Modern-Ice
gtk-cursor-theme-size=24
EOF
done
sed -i "s/^env = GTK_THEME,.*/env = GTK_THEME,$GTKTHEME/" $S/.config/hypr/hyprland.conf
echo "exec-once = gsettings set org.gnome.desktop.interface gtk-theme $GTKTHEME" >> $S/.config/hypr/hyprland.conf
echo "exec-once = gsettings set org.gnome.desktop.interface icon-theme $GTKICON" >> $S/.config/hypr/hyprland.conf

# Firefox: sem telemetria + uBlock Origin instalado por politica (baixa na 1a abertura, precisa de internet)
mkdir -p ~/live/airootfs/etc/firefox/policies
cat > ~/live/airootfs/etc/firefox/policies/policies.json << 'EOF'
{
  "policies": {
    "DisableTelemetry": true,
    "DisableFirefoxStudies": true,
    "DontCheckDefaultBrowser": true,
    "NoDefaultBookmarks": true,
    "OverrideFirstRunPage": "",
    "Homepage": { "URL": "https://duckduckgo.com", "StartPage": "homepage" },
    "ExtensionSettings": {
      "uBlock0@raymondhill.net": {
        "installation_mode": "normal_installed",
        "install_url": "https://addons.mozilla.org/firefox/downloads/latest/ublock-origin/latest.xpi"
      }
    }
  }
}
EOF

# VS Code: extensoes embutidas na ISO (instaladas agora, no build)
echo "Installing VS Code extensions into the image"
rm -rf /tmp/vscode-ext /tmp/vscode-ud
mkdir -p /tmp/vscode-ext /tmp/vscode-ud
id builder >/dev/null 2>&1 || useradd -m builder
chown -R builder /tmp/vscode-ext /tmp/vscode-ud
for e in llvm-vs-code-extensions.vscode-clangd Catppuccin.catppuccin-vsc PKief.material-icon-theme; do
  sudo -u builder code --user-data-dir /tmp/vscode-ud --extensions-dir /tmp/vscode-ext --install-extension "$e" \
    || echo "WARNING: could not install VS Code extension $e (install it later from inside VS Code)"
done
mkdir -p $S/.vscode-oss
cp -r /tmp/vscode-ext $S/.vscode-oss/extensions

echo "--ozone-platform-hint=auto" > $S/.config/code-flags.conf
cat > "$S/.config/Code - OSS/User/settings.json" << 'EOF'
{
  "telemetry.telemetryLevel": "off",
  "update.mode": "none",
  "extensions.autoUpdate": false,
  "workbench.startupEditor": "none",
  "window.titleBarStyle": "custom",
  "workbench.colorTheme": "Catppuccin Mocha",
  "workbench.iconTheme": "material-icon-theme",
  "editor.fontFamily": "'JetBrainsMono Nerd Font', monospace",
  "editor.fontLigatures": true,
  "editor.fontSize": 14,
  "editor.cursorBlinking": "smooth",
  "editor.smoothScrolling": true,
  "editor.minimap.enabled": false,
  "clangd.path": "/usr/bin/clangd",
  "workbench.colorCustomizations": {
    "editor.background": "#0b0e22",
    "sideBar.background": "#0a0d1f",
    "activityBar.background": "#080b1a",
    "titleBar.activeBackground": "#080b1a",
    "tab.activeBorderTop": "#@ACC@",
    "focusBorder": "#@SEC@"
  }
}
EOF

# Neovim: LazyVim (LunarVim nao funciona com o Neovim atual do Arch). Plugins baixam na 1a abertura.
git clone --depth 1 https://github.com/LazyVim/starter $S/.config/nvim && rm -rf $S/.config/nvim/.git \
  || echo "WARNING: could not clone LazyVim starter"

# Flathub e plugins do Neovim: configurados em segundo plano pela tarefa de rede (net-tasks)
for d in $S/.local/share/applications/*.desktop; do sed -i "s/@USER@/$USERNAME/" "$d"; done


# Desktop de emergencia (labwc): usado se o Hyprland falhar ou no boot "Safe mode"
mkdir -p $S/.config/labwc
cat > $S/.config/labwc/environment << 'EOF'
XKB_DEFAULT_LAYOUT=br
XCURSOR_SIZE=24
MOZ_ENABLE_WAYLAND=1
EOF
if [ $IS_VIDEO = 1 ]; then FBWALL="swaybg -c 0b0e22 &"; else FBWALL="swaybg -i \$HOME/Pictures/wall.$WALL_EXT -m fill &"; fi
cat > $S/.config/labwc/autostart << EOF
$FBWALL
waybar -c \$HOME/.config/waybar/config-fallback &
swaync &
nm-applet --indicator &
/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1 &
\$HOME/.local/bin/net-tasks &
EOF
cat > $S/.config/labwc/rc.xml << 'EOF'
<?xml version="1.0"?>
<labwc_config>
  <keyboard>
    <default />
    <keybind key="W-Return"><action name="Execute"><command>kitty</command></action></keybind>
    <keybind key="W-d"><action name="Execute"><command>/home/@USER@/.local/bin/start-menu</command></action></keybind>
    <keybind key="W-e"><action name="Execute"><command>thunar</command></action></keybind>
    <keybind key="W-b"><action name="Execute"><command>firefox</command></action></keybind>
    <keybind key="W-c"><action name="Execute"><command>code</command></action></keybind>
  </keyboard>
</labwc_config>
EOF
cat > $S/.config/waybar/config-fallback << 'EOF'
{
  "layer": "top",
  "position": "bottom",
  "height": 44,
  "modules-left": ["custom/start"],
  "modules-center": ["wlr/taskbar"],
  "modules-right": ["tray", "pulseaudio", "network", "battery", "clock"],
  "custom/start": { "format": "\uf303", "tooltip": false, "on-click": "~/.local/bin/start-menu" },
  "wlr/taskbar": { "format": "{icon}", "icon-size": 22, "on-click": "activate", "on-click-middle": "close" },
  "tray": { "icon-size": 18, "spacing": 10 },
  "pulseaudio": { "format": "{icon}", "format-muted": "\uf026", "format-icons": { "default": ["\uf027", "\uf028"] }, "on-click": "pavucontrol" },
  "network": { "format-wifi": "\uf1eb", "format-ethernet": "\uf0e8", "format-disconnected": "\uf071", "on-click": "~/.local/bin/wifi-menu", "on-click-right": "nm-connection-editor" },
  "battery": { "format": "{icon}", "format-icons": ["\uf244", "\uf243", "\uf242", "\uf241", "\uf240"] },
  "clock": { "format": "{:%H:%M}\n{:%d/%m/%Y}" }
}
EOF
sed -i "s/@USER@/$USERNAME/g" $S/.config/labwc/rc.xml

# Aplica as cores escolhidas em todos os arquivos de configuracao
find $S/.config $S/.local -type f -print0 | xargs -0 sed -i \
  -e "s/@ACC_RGB@/$ACC_RGB/g" -e "s/@SEC_RGB@/$SEC_RGB/g" \
  -e "s/@ACC@/$ACC/g" -e "s/@SEC@/$SEC/g"

echo "== 8/9 User, auto-login, network, bluetooth, sudo"
A=~/live/airootfs
mkdir -p $A/etc/systemd/system/getty@tty1.service.d $A/etc/systemd/system/multi-user.target.wants $A/etc/sudoers.d
cat > $A/etc/systemd/system/create-user.service << EOF
[Unit]
Description=Create live user
Before=getty@tty1.service
ConditionPathExists=!/home/$USERNAME
[Service]
Type=oneshot
ExecStart=/usr/bin/useradd -m -G wheel,video,audio,input -s /bin/bash $USERNAME
ExecStartPost=/usr/bin/sh -c "echo $USERNAME:$PASSWORD | chpasswd"
[Install]
WantedBy=multi-user.target
EOF
ln -sf /etc/systemd/system/create-user.service $A/etc/systemd/system/multi-user.target.wants/create-user.service
ln -sf /usr/lib/systemd/system/NetworkManager.service $A/etc/systemd/system/multi-user.target.wants/NetworkManager.service
mkdir -p $A/etc/systemd/system/sysinit.target.wants
ln -sf /usr/lib/systemd/system/systemd-timesyncd.service $A/etc/systemd/system/sysinit.target.wants/systemd-timesyncd.service
ln -sf /usr/lib/systemd/system/bluetooth.service $A/etc/systemd/system/multi-user.target.wants/bluetooth.service
cat > $A/etc/systemd/system/getty@tty1.service.d/autologin.conf << EOF
[Service]
ExecStart=
ExecStart=-/sbin/agetty --noreset --noclear --autologin $USERNAME - \${TERM}
EOF
echo '%wheel ALL=(ALL:ALL) ALL' > $A/etc/sudoers.d/wheel
chmod 440 $A/etc/sudoers.d/wheel
echo 'file_permissions+=(["/etc/sudoers.d/wheel"]="0:0:440")' >> ~/live/profiledef.sh
echo KEYMAP=br-abnt2 > $A/etc/vconsole.conf
ln -sf /usr/share/zoneinfo/America/Sao_Paulo $A/etc/localtime

echo "== 9/9 Boot options and build"
if [ "$COPYTORAM" = 1 ]; then BOOTOPTS="copytoram=y cow_spacesize=4G"; else BOOTOPTS="cow_spacesize=4G"; fi
grep -rl 'archisobasedir=%INSTALL_DIR%' ~/live | xargs sed -i "s/archisobasedir=%INSTALL_DIR%/& $BOOTOPTS/"
grep -rq cow_spacesize ~/live || { echo "ERROR: could not add boot options"; exit 1; }
# Entradas extras no menu de boot: "Lite mode" (sem efeitos) e "Safe mode" (desktop de emergencia)
for f in ~/live/efiboot/loader/entries/*.conf; do
  [ -f "$f" ] || continue
  grep -q archisobasedir "$f" || continue
  d=$(dirname "$f"); b=$(basename "$f" .conf)
  for v in lite safe; do
    sed -e "s/^title .*/& - ${v^} mode/" -e "s/^options .*/& aes${v}=1/" "$f" > "$d/$b-$v.conf"
  done
done
for f in ~/live/syslinux/archiso_sys-linux.cfg; do
  [ -f "$f" ] || continue
  grep -q archisobasedir "$f" || continue
  cp "$f" /tmp/sys-linux.orig
  echo >> "$f"
  for v in lite safe; do
    sed -e '/MENU DEFAULT/d' -e "s/^\\(LABEL .*\\)/\\1$v/" -e "s/^\\(MENU LABEL .*\\)/\\1 - ${v^} mode/" -e "s/^\\(APPEND .*\\)/\\1 aes${v}=1/" /tmp/sys-linux.orig >> "$f"
    echo >> "$f"
  done
done
mkarchiso -w ~/work -o ~/out ~/live

echo "== Copying ISO to Windows"
cp ~/out/*.iso "$OUT"/
rm -rf ~/work
ls -lh "$OUT"/*.iso
echo "== DONE. The ISO is in: $OUT"
[ "$COPYTORAM" = 1 ] && echo "NOTE: copytoram needs RAM >= ISO size + ~2GB on the computer you boot."
