{
  pkgs,
}:
let
  lib = pkgs.lib;
  pickNewestDarwinSuffix = import ../../playwright-driver/darwin-suffix.nix { inherit lib; };

  # Each case: the darwinHashes sub-table for one system -> the download suffix
  # that must be used for the *base* revision.
  cases = [
    {
      name = "picks the newest major on x86_64";
      hashes = {
        "mac-14" = "sha-14";
        "mac-26" = "sha-26";
      };
      expected = "mac-26";
    }
    {
      name = "preserves the -arm64 tail";
      hashes = {
        "mac-14-arm64" = "sha-14";
        "mac-26-arm64" = "sha-26";
      };
      expected = "mac-26-arm64";
    }
    {
      name = "orders numerically, not lexicographically";
      hashes = {
        "mac-9" = "sha-9";
        "mac-10" = "sha-10";
      };
      expected = "mac-10";
    }
    {
      name = "a single entry is the newest";
      hashes = {
        "mac-14-arm64" = "sha-14";
      };
      expected = "mac-14-arm64";
    }
  ];

  failures = lib.concatMap (
    case:
    let
      got = pickNewestDarwinSuffix case.hashes;
    in
    lib.optional (got != case.expected) "${case.name}: expected ${case.expected}, got ${got}"
  ) cases;

  # Degenerate inputs must fail loudly rather than silently resolving to a
  # suffix that has no hash (a missing key is an eval error downstream).
  throwCases = [
    {
      name = "empty table throws";
      hashes = { };
    }
    {
      name = "non-mac key throws";
      hashes = {
        "ubuntu-24.04" = "sha";
      };
    }
  ];

  throwFailures = lib.concatMap (
    case:
    lib.optional (builtins.tryEval (pickNewestDarwinSuffix case.hashes)).success "${case.name}: expected an evaluation error, got a value"
  ) throwCases;

  allFailures = failures ++ throwFailures;
in
if allFailures != [ ] then
  throw "darwin-suffix FAILED:\n  ${lib.concatStringsSep "\n  " allFailures}"
else
  pkgs.runCommand "webkit-darwin-suffix-check" { } ''
    echo "darwin-suffix OK: ${toString (lib.length (cases ++ throwCases))} cases"
    touch $out
  ''
