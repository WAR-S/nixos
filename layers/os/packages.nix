{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    git
    vim
    curl
    htop
    openssh
    jq
    yq
    neofetch
    dmidecode
    hostname
    openvpn
    # Debug network lscpu lscpi
    pciutils
    networkmanager
    dnsmasq
    iw
    nmcli
    wpa_supplicant
    wireless-regdb
  ];
}