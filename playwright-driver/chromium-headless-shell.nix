{
  fetchzip,
  revision,
  browserVersion,
  suffix,
  system,
  throwSystem,
  stdenv,
  autoPatchelfHook,
  patchelfUnstable,

  alsa-lib,
  at-spi2-atk,
  expat,
  glib,
  libXcomposite,
  libXdamage,
  libXfixes,
  libXrandr,
  libgbm,
  libgcc,
  libxkbcommon,
  nspr,
  nss,
  ...
}:
let
  linux = stdenv.mkDerivation {
    name = "playwright-chromium-headless-shell";
    src = fetchzip {
      url =
        {
          x86_64-linux = "https://cdn.playwright.dev/builds/cft/${browserVersion}/linux64/chrome-headless-shell-linux64.zip";
          aarch64-linux = "https://cdn.playwright.dev/builds/chromium/${revision}/chromium-headless-shell-${suffix}.zip";
        }
        .${system} or throwSystem;
      stripRoot = false;
      hash =
        {
          x86_64-linux = "sha256-2w0Ul3tpzrVkfGHIbQGwEsCRmVUUy3OAShGhuoH6Rmw=";
          aarch64-linux = "sha256-DoZf+pKXW0Oj2e8vtGDDSViJ0SX8PkYE1Q0LJs53IWg=";
        }
        .${system} or throwSystem;
    };

    nativeBuildInputs = [
      autoPatchelfHook
      patchelfUnstable
    ];

    buildInputs = [
      alsa-lib
      at-spi2-atk
      expat
      glib
      libXcomposite
      libXdamage
      libXfixes
      libXrandr
      libgbm
      libgcc
      libxkbcommon
      nspr
      nss
    ];

    buildPhase = ''
      cp -R . $out
    '';
  };

  darwin = fetchzip {
    url =
      {
        x86_64-darwin = "https://cdn.playwright.dev/builds/cft/${browserVersion}/mac-x64/chrome-headless-shell-mac-x64.zip";
        aarch64-darwin = "https://cdn.playwright.dev/builds/cft/${browserVersion}/mac-arm64/chrome-headless-shell-mac-arm64.zip";
      }
      .${system} or throwSystem;
    stripRoot = false;
    hash =
      {
        x86_64-darwin = "sha256-PThY75tNnOg3Eh0yIh9+vhBVOQTJZ6vfd9e0b8VyifY=";
        aarch64-darwin = "sha256-5VQESywHZKhqc7Fhq/jqNF+yXl90F3+i9nPzBHyJV8k=";
      }
      .${system} or throwSystem;
  };
in
{
  x86_64-linux = linux;
  aarch64-linux = linux;
  x86_64-darwin = darwin;
  aarch64-darwin = darwin;
}
.${system} or throwSystem
