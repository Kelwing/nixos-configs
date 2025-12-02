let
  kelwing = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJgW0mNhzaFegPBdf35nTks7bZVJQLMYh5ZgpA1V2GGb";
  users = [ kelwing ];

  vidar = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILU8rcMI45eApk5P+CVGCxkdgPjbF4LhoYy85YQO++oH";
  systems = [ vidar ];
in
{
  "scibot-config.toml.age".publicKeys = users ++ systems;
  "github-token.age".publicKeys = users ++ systems;
}
