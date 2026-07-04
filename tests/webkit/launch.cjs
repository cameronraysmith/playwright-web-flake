// Launch the nix-provided WebKit headless and render a page, proving the
// browser the flake lays out actually launches on the host's macOS version.
// Catches the class of runtime crash (e.g. the mac-14 build's "Protocol error
// (Console.enable)" abort on macOS 26) that pure `nix eval`/`nix build` cannot.
const path = require('path');
const { webkit } = require('playwright-core');

(async () => {
  const exe = webkit.executablePath();
  if (!/webkit(-|_)/.test(exe)) {
    throw new Error(`unexpected webkit executablePath: ${exe}`);
  }
  const browser = await webkit.launch();
  try {
    const page = await browser.newPage();
    await page.setContent('<title>pw-launch</title><h1 id="h">hello-webkit</h1>');
    const title = await page.title();
    const h1 = await page.$eval('#h', (e) => e.textContent);
    const ua = await page.evaluate(() => navigator.userAgent);
    if (title !== 'pw-launch' || h1 !== 'hello-webkit') {
      throw new Error(`render mismatch: title=${title} h1=${h1}`);
    }
    const dir = path.basename(path.dirname(exe));
    const version = (ua.match(/Version\/[\d.]+/) || ['UA ' + ua])[0];
    console.log(`webkit-launch OK: rendered headless page (${dir}, UA ${version})`);
  } finally {
    await browser.close();
  }
})().catch((err) => {
  console.error(`webkit-launch FAILED: ${err && err.message ? err.message : err}`);
  process.exit(1);
});
