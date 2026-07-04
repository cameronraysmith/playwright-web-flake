{
  pkgs,
  self,
  system,
}:
let
  lib = pkgs.lib;
  browsersJSON = lib.importJSON ../playwright-driver/browsers.json;
  # Build webkit only, keeping `nix flake check` light and focused on this change.
  webkitOnly = self.packages.${system}.playwright-driver.browsers.override {
    withChromium = false;
    withChromiumHeadlessShell = false;
    withFirefox = false;
    withFfmpeg = false;
    withWebkit = true;
  };
  webkit-layout = import ./webkit/layout.nix {
    inherit pkgs webkitOnly;
    webkitJSON = browsersJSON.browsers.webkit;
  };
  webkit-launch = pkgs.writeShellApplication {
    name = "webkit-launch";
    runtimeInputs = [ pkgs.nodejs ];
    text = ''
      export PLAYWRIGHT_BROWSERS_PATH="${webkitOnly}"
      export PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1
      export NODE_PATH="${self.packages.${system}.playwright-test}/lib/node_modules"
      exec node ${./webkit/launch.cjs} "$@"
    '';
  };
in
{
  checks = {
    inherit webkit-layout;
  };
  apps = {
    webkit-launch = {
      type = "app";
      program = "${webkit-launch}/bin/webkit-launch";
      meta.description = "Launch the packaged WebKit headless and verify it renders";
    };
  };
}
