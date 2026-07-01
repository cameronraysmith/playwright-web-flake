# Pick the newest "mac-<major>[-arm64]" WebKit download suffix present in a
# darwinHashes sub-table.
#
# Playwright publishes one darwin WebKit artifact per supported macOS major
# (see microsoft/playwright
# `packages/playwright-core/src/server/registry/index.ts`, the `webkit`
# `downloadURLs` map: 'mac14' -> webkit-mac-14.zip, 'mac26' -> webkit-mac-26.zip,
# ...). The *base* revision must be downloaded with the newest suffix, because
# that is the artifact Playwright resolves for a host running the newest macOS.
#
# Nix evaluation cannot detect the running macOS version, so the table itself is
# the single source of truth: whichever mac major is newest in the table is the
# base. This keeps a hardcoded suffix out of the packaging logic: bumping to a
# new macOS major is then purely a matter of `update.sh` adding the new key
# (which it derives from Playwright's own registry mapping).
{ lib }:
hashes:
let
  keys = lib.attrNames hashes;

  majorOf =
    key:
    let
      rest = lib.removePrefix "mac-" key;
      head' = lib.head (lib.splitString "-" rest);
    in
    if !lib.hasPrefix "mac-" key || head' == "" || lib.match "[0-9]+" head' == null then
      throw "darwin-suffix: ${key} is not a mac-<major>[-arm64] download suffix"
    else
      lib.toInt head';

  # Every key is validated (not just the winner), so a typo'd or foreign key is
  # a loud error rather than a silently ignored entry.
  parsed = map (key: {
    inherit key;
    major = majorOf key;
  }) keys;
  allValid = lib.all (entry: builtins.isInt entry.major) parsed;

  newest = lib.foldl' (
    acc: entry: if acc == null || entry.major > acc.major then entry else acc
  ) null parsed;
in
if keys == [ ] then
  throw "darwin-suffix: no darwin webkit hashes available for this system"
else if !allValid then
  throw "darwin-suffix: unreachable, majorOf throws on invalid keys"
else
  newest.key
