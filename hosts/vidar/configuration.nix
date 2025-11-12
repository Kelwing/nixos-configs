{ pkgs, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ./services.nix
    ../../common/users.nix
  ];

  nixpkgs.config.allowUnfree = true;
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
    };
  };

  time.timeZone = "America/Detroit";

  i18n.defaultLocale = "en_US.UTF-8";
  console.keyMap = "us";

  environment.systemPackages = with pkgs; [
    vim
    curl
    tmux
  ];

  system.stateVersion = "25.05";
}
