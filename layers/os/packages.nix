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
    pciutils
    # Wi‑Fi AP (05-wifi-ap): hostapd, dnsmasq, iw
    hostapd
    dnsmasq
    iw
  ];
}