{ config, ... }:
let
  tuwunelPort = 8008;
in
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
      virtualHosts = {
        "rpld.io" = {
          listen = [
            {
              addr = "0.0.0.0";
              port = 443;
              ssl = true;
            }
            {
              # For federation
              addr = "0.0.0.0";
              port = 8448;
              ssl = true;
            }
          ];
          locations."/" = {
            proxyPass = "http://127.0.0.1:${toString tuwunelPort}";
            recommendedProxySettings = true;
          };
          extraConfig = ''
            client_max_body_size 100M;
          '';
          enableACME = true;
          onlySSL = true;
        };
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
      autoCreatedWorldSize = "large";
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

    matrix-tuwunel = {
      enable = true;
      settings = {
        global = {
          server_name = "rpld.io";
          new_user_displayname_suffix = "✨";
          address = [
            "127.0.0.1"
            "::1"
          ];
          port = [ tuwunelPort ];
          allow_registration = true;
          registration_token_file = config.age.secrets."reg_token".path;
          allow_encryption = true;
          encryption_enabled_by_default_for_room_type = "all";
        };
      };
    };

  };
}
