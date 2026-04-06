{ pkgs, ... }:
{
  environment.etc."motd.kdl".text = ''
    global {
      version "1.0"
    }

    components {
      command "hostname | figlet -f slant"
      filesystems {
        filesystem name="root" mount-point="/"
      }
      service-status {
        service display-name="SCI Bot" unit="scibot"
        service display-name="Terraria" unit="terraria"
        service display-name="Tuwunel" unit="tuwunel"
        service display-name="Coturn" unit="coturn"
        service display-name="Impostor" unit="impostor"
      }
      uptime
      load-avg format="Load (1, 5, 15 min.): {one:.02}, {five:.02}, {fifteen:.02}"
    }
  '';

  systemd = {
    timers."rust-motd" = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = "5m";
        OnUnitActiveSec = "5m";
        Unit = "rust-motd.service";
      };
    };
    services."rust-motd" = {
      path = [
        pkgs.bash
        pkgs.coreutils
        pkgs.figlet
      ];
      script = ''
        set -eu
        ${pkgs.rust-motd}/bin/rust-motd /etc/motd.kdl > /etc/motd
      '';
      serviceConfig = {
        Type = "oneshot";
        User = "root";
      };
    };
  };

  services.openssh.settings.PrintMotd = true;
}
