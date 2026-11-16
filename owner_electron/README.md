# Bonzar Owner Electron shell

This is a separate Electron desktop shell for the live Flutter Web app:

`https://mynameismrsindia-cloud.github.io/owner_web/`

It does not bundle Flutter web files. Deploying a new web build updates the UI
served inside the shell without rebuilding the Electron installer. The shell
clears its HTTP cache and service-worker caches at startup and adds a fresh
query parameter to the site URL. GitHub Pages/CDN caching and browser runtime
behavior can still delay a web deployment; the app can be restarted to fetch
the current site.

## Local development

Requirements: Node.js 22+ and npm.

```sh
npm ci
npm test
npm start
```

## Windows installer

Build on Windows, or use the separate `Build Owner Electron` GitHub Actions
workflow. It uploads `Bonzar-Owner-Setup-1.0.0.exe` as an Actions artifact.
The installer is unsigned because no signing certificate is configured.

## Security and limitations

- The renderer loads only the HTTPS Owner Web origin.
- Node integration is disabled; context isolation and Chromium sandboxing are
  enabled. New windows, webviews, and web permissions are denied.
- Browser session storage is ephemeral and HTTP/service-worker caches are
  cleared when the shell starts.
- Invoice/file downloads use a native Save dialog.
- Flutter UI changes appear from the hosted site. Electron/native shell changes
  still require a new Setup.exe.
- This project does not bypass Windows Smart App Control. New unsigned EXE or
  Setup.exe downloads may be blocked; no acceptance or reputation outcome is
  guaranteed.
- Owner Web must be reachable and its backend CORS allowlist must allow its
  deployed web origin for API calls to work.
