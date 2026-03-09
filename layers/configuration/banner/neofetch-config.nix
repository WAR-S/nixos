{ ... }:

{
  environment.etc."neofetch/config.conf".text = ''
print_info() {
    info title
    info underline
    prin "Date" "$(date)"
    info "Uptime" uptime

    info underline

    hostname=$(hostname)
    prin "Hostname" "$hostname"

    info "Kernel" kernel
    info "Host" model
    info "Packages" packages
    info "CPU" cpu
    info "GPU" gpu

    info underline

    info "CPU Usage" cpu_usage
    info "Disk" disk
    info "Memory" memory

    proc_count=$(ps ax | wc -l | tr -d " ")
    prin "Process count" "$proc_count"

    info underline

    wifi_mode=$(iw dev 2>/dev/null | grep wlp0s20f3 -A10 | grep type | awk '{print $2}')
    prin "Wifi mode" "$wifi_mode"

    # Разрываем колонку neofetch
    printf "\n"

    echo "Image"
    echo "29_01_2025_arch_linux_v4_universal (for prod only)"
    echo ""

    vpn_ip=$(ip -4 addr show tun0 2>/dev/null | awk '/inet/ {print $2}' | head -n1)
    lan_ip=$(ip -4 addr show eth0 2>/dev/null | awk '/inet/ {print $2}' | head -n1)
    usb_ip=$(ip -4 addr show usbmodem0 2>/dev/null | awk '/inet/ {print $2}' | head -n1)

    echo "VPN IP: $vpn_ip"
    echo "LAN IP: $lan_ip"
    echo "USB Modem IP: $usb_ip"
    echo ""

    wifi_client=$(iw dev wlp2s0 station dump 2>/dev/null | grep -E 'Station|connected')
    echo "Wifi client:"
    echo "$wifi_client"
    echo ""

    interfaces=$(ip addr show | grep 'UP' | grep -viE 'flannel|cni')
    echo "Interfaces:"
    echo "$interfaces"
}
}
title_fqdn="off"
kernel_shorthand="on"
distro_shorthand="off"
os_arch="on"
uptime_shorthand="on"
memory_percent="off"
memory_unit="mib"
package_managers="on"
shell_path="off"
shell_version="on"
speed_type="bios_limit"
speed_shorthand="off"
cpu_brand="on"
cpu_speed="on"
cpu_cores="logical"
cpu_temp="off"
gpu_brand="on"
gpu_type="all"
refresh_rate="off"
gtk_shorthand="off"
gtk2="on"
gtk3="on"
public_ip_host="http://ident.me"
public_ip_timeout=2
local_ip_interface=('auto')
de_version="on"
  disk_show=('/')
  disk_subtitle="mount"
  disk_percent="on"
  music_player="auto"
  song_format="%artist% - %album% - %title%"
  song_shorthand="off"
mpc_args=()
colors=(distro)
bold="on"
underline_enabled="on"
underline_char="-"
  separator=":"
  block_range=(0 15)
  color_blocks="on"
block_width=3
block_height=1
col_offset="auto"
bar_char_elapsed="-"
bar_char_total="="
bar_border="on"
bar_length=15
bar_color_elapsed="distro"
bar_color_total="distro"
memory_display="off"
battery_display="off"
disk_display="off"
image_backend="ascii"
ascii_distro="auto"
ascii_colors=(distro)
ascii_bold="on"
image_loop="off"
thumbnail_dir="$HOME/.cache/thumbnails/neofetch"
crop_mode="normal"
crop_offset="center"
image_size="auto"
catimg_size="2"
gap=3
yoffset=0
xoffset=0
background_color=
stdout="off"
'';

  # ASCII‑логотип для neofetch (используем в update-issue через --ascii ...)
  # ASCII‑логотип кладём в /etc/neofetch/comp-logo.txt, чтобы имя совпадало с исходником
  environment.etc."neofetch/comp-logo.txt".source = ./comp-logo.txt;
}