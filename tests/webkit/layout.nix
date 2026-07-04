{
  pkgs,
  webkitOnly,
  webkitJSON,
}:
let
  lib = pkgs.lib;
  isDarwin = pkgs.stdenv.hostPlatform.isDarwin;
  darwinOverrideKey = if pkgs.stdenv.hostPlatform.isAarch64 then "mac14-arm64" else "mac14";
  # Reconstructed independently from browsers.json (an oracle, not re-derived
  # through driver.nix's naming helper) so a linkFarm naming regression fails here.
  expectedWebkitDirs = [
    "webkit-${webkitJSON.revision}"
  ]
  ++
    lib.optional (isDarwin && (webkitJSON.revisionOverrides or { }) ? ${darwinOverrideKey})
      "webkit_${lib.replaceStrings [ "-" ] [ "_" ] darwinOverrideKey}_special-${
        webkitJSON.revisionOverrides.${darwinOverrideKey}
      }";
in
pkgs.runCommand "webkit-layout-check" { } ''
  set -euo pipefail
  ${lib.concatMapStringsSep "\n" (d: ''
    if [ ! -x "${webkitOnly}/${d}/pw_run.sh" ]; then
      echo "webkit-layout FAILED: missing executable ${d}/pw_run.sh" >&2
      exit 1
    fi
  '') expectedWebkitDirs}
  echo "webkit-layout OK: ${toString expectedWebkitDirs}"
  touch $out
''
