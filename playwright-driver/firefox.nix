{
  lib,
  stdenv,
  fetchzip,
  firefox-bin,
  suffix,
  revision,
  system,
  throwSystem,
}:
let
  firefox-linux = stdenv.mkDerivation {
    name = "playwright-firefox";
    src = fetchzip {
      url = "https://cdn.playwright.dev/builds/firefox/${revision}/firefox-${
        "ubuntu-24.04" + (lib.removePrefix "linux" suffix)
      }.zip";
      hash =
        {
          x86_64-linux = "sha256-GmjRWhlSv7by3PFtrKgo6EBmHigmp55HwG8iA/Ykq88=";
          aarch64-linux = "sha256-7vxVe82NxebzoSSoSFg9qNxKOqlT7EOwCxQVavkDoMM=";
        }
        .${system} or throwSystem;
    };

    inherit (firefox-bin.unwrapped)
      nativeBuildInputs
      buildInputs
      runtimeDependencies
      appendRunpaths
      patchelfFlags
      ;

    buildPhase = ''
      mkdir -p $out/firefox
      cp -R . $out/firefox
    '';
  };
  firefox-darwin = fetchzip {
    url = "https://cdn.playwright.dev/builds/firefox/${revision}/firefox-${suffix}.zip";
    stripRoot = false;
    hash =
      {
        x86_64-darwin = "sha256-Z5pQ0HVElHuP76IR4QozG76oqr7A7Dw2ssEQfNt/dlQ=";
        aarch64-darwin = "sha256-E7/Kbvjg1dcWwSe/07hMR+W6NR0JHoAPxp1e+SncQYs=";
      }
      .${system} or throwSystem;
  };
in
{
  x86_64-linux = firefox-linux;
  aarch64-linux = firefox-linux;
  x86_64-darwin = firefox-darwin;
  aarch64-darwin = firefox-darwin;
}
.${system} or throwSystem
