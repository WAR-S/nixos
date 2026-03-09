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
}
'';
}