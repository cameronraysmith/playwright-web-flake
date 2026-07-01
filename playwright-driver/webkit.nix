{
  lib,
  stdenv,
  fetchzip,
  fetchFromGitHub,
  makeWrapper,
  autoPatchelfHook,
  patchelfUnstable,
  fetchpatch,
  libjxl,
  brotli,
  at-spi2-atk,
  cairo,
  enchant_2,
  flite,
  fontconfig,
  freetype,
  glib,
  glib-networking,
  gst_all_1,
  harfbuzz,
  harfbuzzFull,
  hyphen,
  icu74,
  lcms,
  libavif,
  libbacktrace,
  libdrm,
  libepoxy,
  libevent,
  libgcc,
  libgcrypt,
  libgpg-error,
  libjpeg8,
  libopus,
  libpng,
  libsoup_3,
  libtasn1,
  libvpx,
  libwebp,
  libwpe,
  libwpe-fdo,
  libxkbcommon,
  libxml2_13,
  libxslt,
  libgbm,
  sqlite,
  systemdLibs,
  wayland-scanner,
  woff2,
  zlib,
  suffix,
  revision,
  revisionOverrides ? { },
  system,
  throwSystem,
}:
let
  # Nix evaluation cannot detect the host macOS version, so both darwin webkit
  # builds are laid out under the exact directory names Playwright computes at
  # runtime (readDescriptors): the base revision under "webkit-<rev>" and each
  # matching macNN override under "webkit_<key>_special-<override-rev>". Playwright
  # selects the directory that matches the running OS when it launches. Linux
  # revisionOverrides (debianNN, ubuntu20.04) are intentionally not laid out; the
  # flake ships only the base ubuntu-24.04 linux build.
  linuxSuffix = "ubuntu-24.04" + (lib.removePrefix "linux" suffix);
  libvpx' = libvpx.overrideAttrs (
    finalAttrs: previousAttrs: {
      version = "1.12.0";
      src = fetchFromGitHub {
        owner = "webmproject";
        repo = finalAttrs.pname;
        rev = "v${finalAttrs.version}";
        sha256 = "sha256-9SFFE2GfYYMgxp1dpmL3STTU2ea1R5vFKA1L0pZwIvQ=";
      };
    }
  );

  libjxl' = libjxl.overrideAttrs (
    finalAttrs: previousAttrs: {
      version = "0.8.2";
      src = fetchFromGitHub {
        owner = "libjxl";
        repo = "libjxl";
        rev = "v${finalAttrs.version}";
        hash = "sha256-I3PGgh0XqRkCFz7lUZ3Q4eU0+0GwaQcVb6t4Pru1kKo=";
        fetchSubmodules = true;
      };
      outputs = [
        "out"
        "dev"
      ];
      patches = [
        # Add missing <atomic> content to fix gcc compilation for RISCV architecture
        # https://github.com/libjxl/libjxl/pull/2211
        (fetchpatch {
          url = "https://github.com/libjxl/libjxl/commit/22d12d74e7bc56b09cfb1973aa89ec8d714fa3fc.patch";
          hash = "sha256-X4fbYTMS+kHfZRbeGzSdBW5jQKw8UN44FEyFRUtw0qo=";
        })
      ];
      postPatch = ''
        # Fix multiple definition errors by using C++17 instead of C++11
        substituteInPlace CMakeLists.txt \
          --replace "set(CMAKE_CXX_STANDARD 11)" "set(CMAKE_CXX_STANDARD 17)"
        # Fix the build with CMake 4.
        # See:
        # * <https://github.com/webmproject/sjpeg/commit/9990bdceb22612a62f1492462ef7423f48154072>
        # * <https://github.com/webmproject/sjpeg/commit/94e0df6d0f8b44228de5be0ff35efb9f946a13c9>
        substituteInPlace third_party/sjpeg/CMakeLists.txt \
          --replace-fail \
            'cmake_minimum_required(VERSION 2.8.7)' \
            'cmake_minimum_required(VERSION 3.5...3.10)'
      '';
      postInstall = "";

      cmakeFlags = [
        "-DJPEGXL_FORCE_SYSTEM_BROTLI=ON"
        "-DJPEGXL_FORCE_SYSTEM_HWY=ON"
        "-DJPEGXL_FORCE_SYSTEM_GTEST=ON"
      ]
      ++ lib.optionals stdenv.hostPlatform.isStatic [
        "-DJPEGXL_STATIC=ON"
      ]
      ++ lib.optionals stdenv.hostPlatform.isAarch32 [
        "-DJPEGXL_FORCE_NEON=ON"
      ];
    }
  );
  webkit-linux = stdenv.mkDerivation {
    name = "playwright-webkit";
    src = fetchzip {
      url = "https://cdn.playwright.dev/builds/webkit/${revision}/webkit-${linuxSuffix}.zip";
      stripRoot = false;
      hash =
        {
          x86_64-linux = "sha256-w/avBW8CAiGd9WzddVGLymLLG23OzY/Bm7Dhw9JVQOA=";
          aarch64-linux = "sha256-KUVT67b11IljTNpzCcEy+O5CW5UuqyVi6QFdQ87lVLA=";
        }
        .${system} or throwSystem;
    };

    nativeBuildInputs = [
      autoPatchelfHook
      patchelfUnstable
      makeWrapper
    ];
    buildInputs = [
      at-spi2-atk
      cairo
      enchant_2
      flite
      fontconfig.lib
      freetype
      glib
      brotli
      libjxl'
      gst_all_1.gst-plugins-bad
      gst_all_1.gst-plugins-base
      gst_all_1.gstreamer
      harfbuzz
      harfbuzzFull
      hyphen
      icu74
      lcms
      libavif
      libbacktrace
      libdrm
      libepoxy
      libevent
      libgcc
      libgcrypt
      libgpg-error
      libjpeg8
      libopus
      libpng
      libsoup_3
      libtasn1
      libwebp
      libwpe
      libwpe-fdo
      libvpx'
      libxml2_13
      libxslt
      libgbm
      sqlite
      systemdLibs
      wayland-scanner
      woff2.lib
      libxkbcommon
      zlib
    ];

    patchelfFlags = [ "--no-clobber-old-sections" ];
    buildPhase = ''
      cp -R . $out

      # remove unused gtk browser
      rm -rf $out/minibrowser-gtk
      # remove bundled libs
      rm -rf $out/minibrowser-wpe/sys

      wrapProgram $out/minibrowser-wpe/bin/MiniBrowser \
        --prefix GIO_EXTRA_MODULES ":" "${glib-networking}/lib/gio/modules/" \
        --prefix LD_LIBRARY_PATH ":" $out/minibrowser-wpe/lib
    '';
  };
  # The base darwin build is the newest mac build Playwright ships (mac-15); the
  # override builds derive their suffix from the revisionOverride key.
  darwinBaseSuffix = "mac-15" + (lib.removePrefix "mac" suffix);

  darwinHashes = {
    x86_64-darwin = {
      "mac-15" = "sha256-FFWFWKHroNBeDw4KYDe4UeucaJzMyin0Ca/qxN2iaO0=";
      "mac-14" = "sha256-zmxdNdptFJ+8sad6HICoJRNsVNdQ0j4kKKCPX9YsBE8=";
    };
    aarch64-darwin = {
      "mac-15-arm64" = "sha256-glVkYnthOFBPp1gZXTue9WwjP+oCgQpq6j9Mlm/bjmg=";
      "mac-14-arm64" = "sha256-AbDHuUg8jLNPWur6hieDdY8Kc2+PmlXRJGD46yujam4=";
    };
  };

  mkWebkitDarwin =
    {
      rev,
      macSuffix,
    }:
    fetchzip {
      url = "https://cdn.playwright.dev/builds/webkit/${rev}/webkit-${macSuffix}.zip";
      stripRoot = false;
      hash = darwinHashes.${system}.${macSuffix};
    };

  # macNN[-arm64] override keys for the current darwin arch (the base always applies).
  darwinOverrideKeys = lib.filter (
    key:
    lib.hasPrefix "mac" key
    && (
      if lib.hasSuffix "-arm64" suffix then lib.hasSuffix "-arm64" key else !lib.hasSuffix "-arm64" key
    )
  ) (lib.attrNames revisionOverrides);

  webkit-darwin = {
    "webkit-${revision}" = mkWebkitDarwin {
      rev = revision;
      macSuffix = darwinBaseSuffix;
    };
  }
  // lib.listToAttrs (
    map (
      key:
      lib.nameValuePair
        "webkit_${lib.replaceStrings [ "-" ] [ "_" ] key}_special-${revisionOverrides.${key}}"
        (mkWebkitDarwin {
          rev = revisionOverrides.${key};
          macSuffix = "mac-" + (lib.removePrefix "mac" key);
        })
    ) darwinOverrideKeys
  );

  webkit-linux' = {
    "webkit-${revision}" = webkit-linux;
  };
in
{
  x86_64-linux = webkit-linux';
  aarch64-linux = webkit-linux';
  x86_64-darwin = webkit-darwin;
  aarch64-darwin = webkit-darwin;
}
.${system} or throwSystem
