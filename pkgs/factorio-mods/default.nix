{
  lib,
  python3Packages,
  makeWrapper,
  nix,
}:

python3Packages.buildPythonApplication {
  pname = "factorio-mods";
  version = "0.1.0";
  format = "other";

  src = ./.;

  nativeBuildInputs = [ makeWrapper ];

  propagatedBuildInputs = with python3Packages; [
    requests
    tomlkit
  ];

  # The script shells out to nix-prefetch-url and nix-hash, so make sure
  # they're on PATH regardless of the caller's environment.
  makeWrapperArgs = [
    "--prefix"
    "PATH"
    ":"
    (lib.makeBinPath [ nix ])
  ];

  dontUnpack = false;
  dontBuild = true;
  dontConfigure = true;

  installPhase = ''
    runHook preInstall
    install -Dm755 factorio-mods.py $out/bin/factorio-mods
    runHook postInstall
  '';

  meta = {
    description = "Manage a TOML manifest of Factorio mods for Nix consumption";
    mainProgram = "factorio-mods";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
  };
}
