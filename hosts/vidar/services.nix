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

    terraria = {
      enable = true;
      port = 7777;
      maxPlayers = 16;
      openFirewall = true;
      messageOfTheDay = "Hello gays";
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
      listenPort = 5050;
      nginx = {
        enable = true;
        virtualHost = "amongus.kelw.ing";
        useACME = true;
      };
    };

    scibot = {
      enable = true;
      configFile = config.age.secrets."scibot-config.toml".path;
      apiPort = 5001;
      nginx = {
        enable = true;
        virtualHost = "scibot.kelw.ing";
        useACME = true;
      };
    };
  };
}
