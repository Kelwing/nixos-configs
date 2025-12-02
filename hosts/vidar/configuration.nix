{ pkgs, config, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ./services.nix
    ../../common/users.nix
  ];

  nixpkgs.config.allowUnfree = true;
  nix = {
    settings = {
      experimental-features = "nix-command flakes";
    };
    extraOptions = ''
      !include ${config.age.secrets."github-token".path}
    '';
  };

  boot = {
    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
    };
    kernelPackages = pkgs.linuxPackages_latest;
  };

  networking = {
    hostName = "vidar";
    firewall = {
      enable = true;
      allowedTCPPorts = [ 80 443 ];
    };
  };

  time.timeZone = "America/Detroit";

  i18n.defaultLocale = "en_US.UTF-8";
  console.keyMap = "us";

  environment.systemPackages = with pkgs; [
    vim
    curl
    tmux
    git
  ];

  security.acme = {
    acceptTerms = true;
    defaults.email = "kelwing@kelnet.org";
  };

  services.scibot = {
    enable = true;
    configFile = config.age.secrets."scibot-config.toml".path;
  };

  # secrets
  age.secrets = {
    "scibot-config.toml".file = ../../secrets/scibot-config.toml.age;
    "github-token".file = ../../secrets/github-token.age;
  };

  system.stateVersion = "25.05";
}
