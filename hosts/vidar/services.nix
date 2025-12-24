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

    nginx = {
      enable = true;
    };

    kelwing-homepage = {
      enable = true;
      virtualHost = "kelw.ing";
      extraVirtualHostConfig = {
        addSSL = true;
        enableACME = true;
      };
    };

    terraria-server = {
      enable = true;
      port = 7777;
      maxPlayers = 16;
      autoCreatedWorldSize = "medium";
      messageOfTheDay = "Welcome to Kelwing's Terraria server!";
      worldPath = "/var/lib/terraria/world1.wld";
      noUPnP = true;
      openFirewall = true;
      extraSettings = {
        difficulty = 2;
        journeypermission_godmode = 0;
      };
      adminUsers = [ "kelwing" ];
    };

    impostor = {
      enable = true;
      httpServer = {
        enable = true;
      };
      publicIp = "impostor.kelwing.dev";
      nginx = {
        enable = true;
        virtualHost = "impostor.kelwing.dev";
        useACME = true;
      };
    };
  };
}
