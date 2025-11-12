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
    };

    terraria = {
      enable = true;
      openFirewall = true;
      maxPlayers = 10;
      messageOfTheDay = "Welcome to Kelwing's Terraria Server!";
    };
  };
}
