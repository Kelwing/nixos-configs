{
  stdenv,
  lib,
  fetchurl,
}:
rec {
  mkFactorioMod =
    {
      name,
      download_id,
      version,
      hash ? lib.fakeHash,
    }:
    # Catch the most common failure mode at evaluation time: the caller forgot
    # to run the prefetch script, so `hash` is still the placeholder. Without
    # this assert the user would instead see a confusing fetchurl hash-mismatch
    # error at build time.
    assert lib.assertMsg (hash != lib.fakeHash) ''
      Factorio mod "${name}" (download_id: ${download_id}) has no hash set.

      Factorio mod downloads require authentication, so Nix cannot fetch them
      during a build. You must pre-populate the Nix store by running the
      prefetch script first, which writes a `hash` value into the mod
      manifest TOML:

          FACTORIO_USERNAME=... FACTORIO_TOKEN=... \
              python3 prefetch_mods.py mods.toml

      Then rebuild.
    '';
    let
      download_url = "/download/${name}/${download_id}";
      filename = "${name}_${version}.zip";
    in
    stdenv.mkDerivation {
      inherit name version filename;
      src = fetchurl {
          # Give the fixed-output derivation a descriptive name so that if the
          # store path is missing and Nix has to fall back to the network (which
          # will fail, since the URL requires auth query params we don't have
          # here), the error message at least identifies which mod is at fault.
          name = filename;
          url = "https://mods.factorio.com${download_url}";
          inherit hash;
        };

      dontUnpack = true;
      dontConfigure = true;
      dontBuild = true;

      installPhase = ''
        runHook preInstall
        mkdir -p $out
        cp $src $out/$filename
        runHook postInstall
      '';
      deps = [ ];
    };

  # Parse a TOML manifest of Factorio mods and return a list of mod
  # derivations, one per `[[mod]]` entry.
  #
  # The TOML file is expected to look like:
  #
  #     [[mod]]
  #     name = "AutoDeconstruct"
  #     download_id = "69a0d19734a726c6c089b0ea"
  #     hash = "sha256:130nz4vykc00j5m3bmx83p82gl3c5kvahn15b7vj7q1nxflhxcj0"
  #
  # The `hash` field is populated by the companion `prefetch_mods.py` script,
  # which must be run (with valid FACTORIO_USERNAME / FACTORIO_TOKEN) before
  # any derivation that depends on these mods is built. Otherwise the fetch
  # will fail, since mod downloads require authentication that cannot be
  # supplied from inside a Nix fixed-output derivation.
  mkFactorioModsFromToml =
    tomlPath:
    let
      parsed =
        # readFile + fromTOML rather than importTOML so this works on older
        # nixpkgs versions that don't expose lib.importTOML.
        builtins.fromTOML (builtins.readFile tomlPath);

      entries =
        parsed.mod or (throw ''
          Factorio mod manifest ${toString tomlPath} contains no `[[mod]]` entries.
        '');
    in
    map mkFactorioMod entries;
}
