{
  lib,
  buildNpmPackage,
  stdenv,
  chromium,
  ffmpeg,
  jq,
  nodejs,
  fetchFromGitHub,
  linkFarm,
  callPackage,
  makeFontsConf,
  makeWrapper,
  runCommand,
  cacert,
}:
let
  inherit (stdenv.hostPlatform) system;

  throwSystem = throw "Unsupported system: ${system}";
  suffix =
    {
      x86_64-linux = "linux";
      aarch64-linux = "linux-arm64";
      x86_64-darwin = "mac";
      aarch64-darwin = "mac-arm64";
    }
    .${system} or throwSystem;

  version = "1.62.1";

  src = fetchFromGitHub {
    owner = "Microsoft";
    repo = "playwright";
    rev = "v${version}";
    hash = "sha256-3gLXo9bd2qXCy8MYMbnYU6AXIWrqoitqMBPMF4g07nY=";
  };

  playwright = buildNpmPackage {
    pname = "playwright";
    inherit version src;

    sourceRoot = "${src.name}"; # update.sh depends on sourceRoot presence
    npmDepsHash = "sha256-iebe0sP3VMdk1vBFDkwM1L4x2VrHPZF/NbjMeU5diWM=";

    nativeBuildInputs = [
      cacert
      jq
    ];

    env.ELECTRON_SKIP_BINARY_DOWNLOAD = true;

    postPatch = ''
      sed -i '/\/\/ Update test runner./,/^\s*$/{d}' utils/build/build.js
      # The dlopen library check uses ldconfig, which does not work under Nix.
      # Libraries are already provided via rpath by autoPatchelfHook and wrapProgram.
      substituteInPlace packages/playwright-core/src/server/registry/index.ts \
        --replace-fail "['libGLESv2.so.2', 'libx264.so']" "[]"
    '';

    installPhase = ''
      runHook preInstall

      shopt -s extglob

      mkdir -p "$out/lib/node_modules/playwright"
      cp -r packages/playwright/!(bundles|src|node_modules|.*) "$out/lib/node_modules/playwright"

      # for not supported platforms (such as NixOS) playwright assumes that it runs on ubuntu-20.04
      # that forces it to use overridden webkit revision
      # let's remove that override to make it use latest revision provided in Nixpkgs
      # https://github.com/microsoft/playwright/blob/baeb065e9ea84502f347129a0b896a85d2a8dada/packages/playwright-core/src/server/utils/hostPlatform.ts#L111
      jq '(.browsers[] | select(.name == "webkit") | .revisionOverrides) |= del(."ubuntu20.04-x64", ."ubuntu20.04-arm64")' \
        packages/playwright-core/browsers.json > browser.json.tmp && mv browser.json.tmp packages/playwright-core/browsers.json
      mkdir -p "$out/lib/node_modules/playwright-core"
      cp -r packages/playwright-core/!(bundles|src|bin|.*) "$out/lib/node_modules/playwright-core"

      mkdir -p "$out/lib/node_modules/@playwright/test"
      cp -r packages/playwright-test/* "$out/lib/node_modules/@playwright/test"

      runHook postInstall
    '';

    meta = {
      description = "Framework for Web Testing and Automation";
      homepage = "https://playwright.dev";
      license = lib.licenses.asl20;
      maintainers = with lib.maintainers; [
        kalekseev
        marie
      ];
      inherit (nodejs.meta) platforms;
    };
  };

  playwright-core = stdenv.mkDerivation (finalAttrs: {
    pname = "playwright-core";
    inherit (playwright) version src meta;

    installPhase = ''
      runHook preInstall

      cp -r ${playwright}/lib/node_modules/playwright-core "$out"

      runHook postInstall
    '';

    passthru = {
      browsersJSON = (lib.importJSON ./browsers.json).browsers;
      selectBrowsers = browsers;
      browsers = browsers { };
      browsers-chromium = browsers {
        withFirefox = false;
        withWebkit = false;
        withChromiumHeadlessShell = false;
      };
      inherit components;
    };
  });

  playwright-test = stdenv.mkDerivation (finalAttrs: {
    pname = "playwright-test";
    inherit (playwright) version src;

    nativeBuildInputs = [ makeWrapper ];
    installPhase = ''
      runHook preInstall

      shopt -s extglob
      mkdir -p $out/bin
      cp -r ${playwright}/* $out

      makeWrapper "${nodejs}/bin/node" "$out/bin/playwright" \
        --add-flags "$out/lib/node_modules/@playwright/test/cli.js" \
        --prefix NODE_PATH : ${placeholder "out"}/lib/node_modules \
        --set-default PLAYWRIGHT_BROWSERS_PATH "${playwright-core.passthru.browsers}"

      runHook postInstall
    '';

    meta = playwright.meta // {
      mainProgram = "playwright";
    };
  });

  components = {
    chromium = callPackage ./chromium.nix {
      inherit suffix system throwSystem;
      inherit (playwright-core.passthru.browsersJSON.chromium) revision browserVersion;
      fontconfig_file = makeFontsConf {
        fontDirectories = [ ];
      };
    };
    chromium-headless-shell = callPackage ./chromium-headless-shell.nix {
      inherit suffix system throwSystem;
      inherit (playwright-core.passthru.browsersJSON.chromium) revision browserVersion;
    };
    firefox = callPackage ./firefox.nix {
      inherit suffix system throwSystem;
      inherit (playwright-core.passthru.browsersJSON.firefox) revision;
    };
    webkit = callPackage ./webkit.nix {
      inherit suffix system throwSystem;
      inherit (playwright-core.passthru.browsersJSON.webkit) revision;
      revisionOverrides = playwright-core.passthru.browsersJSON.webkit.revisionOverrides or {};
    };
    ffmpeg = callPackage ./ffmpeg.nix {
      inherit suffix system throwSystem;
      inherit (playwright-core.passthru.browsersJSON.ffmpeg) revision;
      revisionOverrides = playwright-core.passthru.browsersJSON.ffmpeg.revisionOverrides or {};
    };
  };

  browsers = lib.makeOverridable (
    {
      withChromium ? true,
      withFirefox ? true,
      withWebkit ? true, # may require `export PLAYWRIGHT_HOST_PLATFORM_OVERRIDE="ubuntu-24.04"`
      withFfmpeg ? true,
      withChromiumHeadlessShell ? true,
      fontconfig_file ? makeFontsConf {
        fontDirectories = [ ];
      },
    }:
    let
      browsers =
        lib.optionals withChromium [ "chromium" ]
        ++ lib.optionals withChromiumHeadlessShell [ "chromium-headless-shell" ]
        ++ lib.optionals withFirefox [ "firefox" ]
        ++ lib.optionals withWebkit [ "webkit" ]
        ++ lib.optionals withFfmpeg [ "ffmpeg" ];
    in
    linkFarm "playwright-browsers" (
      lib.listToAttrs (
        lib.concatMap (
          name:
          let
            revName = if name == "chromium-headless-shell" then "chromium" else name;
            value = playwright-core.passthru.browsersJSON.${revName};
          in
          if name == "webkit" then
            # Lay out the base build under "webkit-<rev>" plus, on darwin, one
            # "webkit_<key>_special-<override-rev>" entry per macNN override matching
            # the host arch, reproducing the directory names Playwright resolves at
            # runtime (readDescriptors). Linux override keys are intentionally not
            # laid out; the flake ships only the base ubuntu-24.04 linux build.
            let
              overrides = value.revisionOverrides or { };
              darwinOverrideKeys = lib.optionals stdenv.hostPlatform.isDarwin (
                lib.filter (
                  key:
                  lib.hasPrefix "mac" key
                  && (
                    if stdenv.hostPlatform.isAarch64 then lib.hasSuffix "-arm64" key else !lib.hasSuffix "-arm64" key
                  )
                ) (lib.attrNames overrides)
              );
              baseName = "webkit-${value.revision}";
              overrideName = key: "webkit_${lib.replaceStrings [ "-" ] [ "_" ] key}_special-${overrides.${key}}";
            in
            [ (lib.nameValuePair baseName components.webkit.${baseName}) ]
            ++ map (
              key: lib.nameValuePair (overrideName key) components.webkit.${overrideName key}
            ) darwinOverrideKeys
          else
            [
              (lib.nameValuePair "${
                lib.replaceStrings [ "-" ] [ "_" ] name
              }-${value.revision}" components.${name})
            ]
        ) browsers
      )
    )
  );
in
{
  playwright-core = playwright-core;
  playwright-test = playwright-test;
}
