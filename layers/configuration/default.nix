{ ... }:

{
  imports = [
    ./00-udev
    ./01-ntp
    ./02-journald
    ./03-hostname
    ./04-resolver
    ./05-ssh
    ./06-wifi-ap
    ./07-postgres
    ./08-k3s 
    ./banner
  ];
}