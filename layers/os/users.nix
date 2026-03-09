{ ... }:

{
users.users.wars = {
    isNormalUser = true;
    initialPassword = "wars";
    extraGroups = [ "wheel" ]; # Enable ‘sudo’ for the user.
    openssh.authorizedKeys.keys  = [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOZyhFTVgCdZy5KivCbBpUnAoiwI7wZ8jcj+sS0ZtFxO basiliyfedorov@Windows-10-2.local" ];
};
  security.sudo.wheelNeedsPassword = false;
}