{ ... }:

{
  environment.etc."neofetch/config.conf".text = ''
print_info() {
    info title
    info underline
    prin "Date" "$(date)"
    info "Uptime" uptime

    info underline
    prin "Hostname" "$(hostnamectl status | grep hostname |awk '{print $3}')"
    info "Kernel" kernel
    info "Host" model
    info "Packages" packages
    info "CPU" cpu
    info "GPU" gpu

    info underline
    info "CPU Usage" cpu_usage
    info "Disk" disk
    info "Memory" memory
    prin "Process count" "$(ps ax | wc -l | tr -d " ")"

    info underline
    prin "Wifi mode" "$(iw dev | grep wlp0s20f3  -A 10 | grep type | awk '{print $2}')"
    echo "Image"
    echo "29_01_2025_arch_linux_v4_universal (for prod only)"
    echo ""
    echo "IP in VPN tun:"
    echo "$(ip a l tun0 | awk '/inet/ {print $2}' | head -n 1)"
    echo ""
    echo "LAN IP:"
    echo "$(ip a l eth0 | awk '/inet/ {print $2}' | head -n 1)"
    echo ""
    echo "USB Modem IP:"
    echo "$(ip a l usbmodem0 | awk '/inet/ {print $2}' | head -n 1)"
    echo ""
    echo "Wifi client:"
    echo "$(iw dev wlp2s0 station dump | grep 'Station\|connected')"
    echo "Interfaces:"
    echo "$(echo "$(ip addr show | grep 'UP' | grep -i -v -E 'flannel|cni')")"

}
title_fqdn="off"
kernel_shorthand="on"
distro_shorthand="off"
os_arch="on"
uptime_shorthand="on"memory_percent="off"
memory_unit="mib"
package_managers="on"shell_path="off"
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
music_player="auto"song_format="%artist% - %album% - %title%"
song_shorthand="off"
mpc_args=()
colors=(distro)
bold="on"
underline_enabled="on"
underline_char="-"
separator=":"block_range=(0 15)
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
image_source="auto"
ascii_distro="auto"
ascii_colors=(distro)
ascii_bold="on"
image_loop="off"
thumbnail_dir="${XDG_CACHE_HOME:-${HOME}/.cache}/thumbnails/neofetch"crop_mode="normal"
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
  environment.etc."neofetch/ascii.txt".source = ./comp-logo.txt;
}