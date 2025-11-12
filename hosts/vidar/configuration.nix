{ pkgs, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ../../common/users.nix
  ];

  nix.settings = {
    experimental-features = "nix-command flakes";
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
      allowedTCPPorts = [ 22 80 443 ];
    };
  };

  time.timeZone = "America/Detroit";

  i18n.defaultLocale = "en_US.UTF-8";
  console.keyMap = "us";

  environment.systemPackages = with pkgs; [
    vim
    curl
  ];

  services = {
    openssh = {
      enable = true;
      settings = {
        PermitRootLogin = "no";
        PasswordAuthentication = false;
        KbdInteractiveAuthentication = false;
      };
    };
  };

  system.stateVersion = "25.05";
}
