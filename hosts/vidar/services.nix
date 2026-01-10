{ config, ... }:
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
      virtualHosts."stream.kelw.ing" = {
        locations."/" = {
          proxyPass = "http://127.0.0.1:${toString config.services.owncast.port}";
          recommendedProxySettings = true;
        };
        forceSSL = true;
        enableACME = true;
      };
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
      openFirewall = true;
      publicIp = "impostor.kelw.ing";
      nginx = {
        enable = true;
        virtualHost = "impostor.kelw.ing";
        useACME = true;
      };
    };

    owncast = {
      enable = true;
      openFirewall = true;
    };

    launcherapi = {
      enable = true;
      configFile = config.age.secrets."launcher-api-config.json".path;
      nginx = {
        enable = true;
        virtualHost = "amongus.kelw.ing";
        useACME = true;
      };
    };
  };
}
