{ ... }:
{
  services = {
    openssh = {
      enable = true;
      settings = {
        PermitRootLogin = "no";
        PasswordAuthentication = false;
        KbdInteractiveAuthentication = false;
      };
      openFirewall = true;
    };

    terraria = {
      enable = true;
      openFirewall = true;
      maxPlayers = 10;
      messageOfTheDay = "Welcome to Kelwing's Terraria Server!";
      worldPath = "/var/lib/terraria/world1.wld";
    };

    nginx = {
      enable = true;
    };

    kelwing-homepage = {
      enable = true;
      virtualHost = "kelwing.dev";
      extraVirtualHostConfig = {
        addSSL = true;
        enableACME = true;
      };
    };
  };
}
