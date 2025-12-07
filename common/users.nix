{ ... }:
{
  users.users = {
    root.hashedPassword = "!"; # Disable root login
    kelwing = {
      isNormalUser = true;
      extraGroups = [ "wheel" ];
      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFjnOwCitFWrv7GeMnqIsuRAj/oA2B8ehrtqjCkFnqBg kelwing@desktop"
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJgW0mNhzaFegPBdf35nTks7bZVJQLMYh5ZgpA1V2GGb kelwing@mbp"
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEEBIF1VgcvTRqgnEhrJYxrT0zy9zdWNkYjnpn9nJn2c github-deploy"
      ];
    };
  };

  security.sudo.wheelNeedsPassword = false;
}
