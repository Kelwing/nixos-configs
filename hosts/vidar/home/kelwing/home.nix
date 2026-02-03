{ config, ... }:
let
  bashCfg = config.programs.bash;
in
{
  programs = {
    zellij = {
      enable = true;
      enableBashIntegration = bashCfg.enable;
      attachExistingSession = true;
      exitShellOnExit = true;
    };

    bash = {
      enable = true;
    };

  };

  home.stateVersion = "25.11";
}
