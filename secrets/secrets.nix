let
  kelwing = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJgW0mNhzaFegPBdf35nTks7bZVJQLMYh5ZgpA1V2GGb";
  kelwing-desktop = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFjnOwCitFWrv7GeMnqIsuRAj/oA2B8ehrtqjCkFnqBg";
  users = [
    kelwing
    kelwing-desktop
  ];

  vidar = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILU8rcMI45eApk5P+CVGCxkdgPjbF4LhoYy85YQO++oH";
  systems = [ vidar ];
in
{
  "scibot-config.toml.age".publicKeys = users ++ systems;
  "launcher-api-config.json.age".publicKeys = users ++ systems;
  "reg_token.age".publicKeys = users ++ systems;
}
