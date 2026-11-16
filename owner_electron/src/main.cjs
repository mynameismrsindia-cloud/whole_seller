const { app, BrowserWindow, dialog, session } = require('electron');
const path = require('node:path');
const { pathToFileURL } = require('node:url');
const { OWNER_WEB_URL, isAllowedOwnerUrl } = require('./security.cjs');

const OWNER_WEB_ORIGIN = new URL(OWNER_WEB_URL).origin;

async function prepareWebSession(ownerSession) {
  await Promise.all([
    ownerSession.clearCache(),
    ownerSession.clearStorageData({
      origin: OWNER_WEB_ORIGIN,
      storages: ['serviceworkers', 'cachestorage'],
    }),
  ]);
}

function configureWebSession(ownerSession) {
  ownerSession.setPermissionRequestHandler((_webContents, _permission, callback) => {
    callback(false);
  });

  ownerSession.on('will-download', async (event, item) => {
    event.preventDefault();
    const suggestedName = path.basename(item.getFilename()) || 'download';
    try {
      const { canceled, filePath } = await dialog.showSaveDialog({
        defaultPath: suggestedName,
        filters: suggestedName.toLowerCase().endsWith('.pdf')
          ? [{ name: 'PDF document', extensions: ['pdf'] }]
          : [{ name: 'All files', extensions: ['*'] }],
      });

      if (!canceled && filePath) item.setSavePath(filePath);
      else item.cancel();
    } catch (error) {
      item.cancel();
      console.error('Could not save downloaded file:', error);
    }
  });
}

async function createWindow() {
  const ownerSession = session.fromPartition('owner-electron');
  await prepareWebSession(ownerSession);
  configureWebSession(ownerSession);

  const window = new BrowserWindow({
    width: 1280,
    height: 850,
    minWidth: 900,
    minHeight: 650,
    show: false,
    webPreferences: {
      partition: 'owner-electron',
      nodeIntegration: false,
      contextIsolation: true,
      sandbox: true,
      webSecurity: true,
      allowRunningInsecureContent: false,
      webviewTag: false,
    },
  });

  window.webContents.setWindowOpenHandler(() => ({ action: 'deny' }));
  window.webContents.on('will-navigate', (event, url) => {
    if (!isAllowedOwnerUrl(url)) event.preventDefault();
  });
  window.webContents.on('will-redirect', (event, url) => {
    if (!isAllowedOwnerUrl(url)) event.preventDefault();
  });
  window.webContents.on('will-attach-webview', (event) => {
    event.preventDefault();
  });
  window.webContents.on('will-prevent-unload', (event) => {
    event.preventDefault();
  });
  window.webContents.on('did-fail-load', (_event, code, description, url, isMainFrame) => {
    if (isMainFrame && code !== -3 && isAllowedOwnerUrl(url)) {
      window.loadFile(path.join(__dirname, 'offline.html'));
      console.error(`Owner web app failed to load (${code}): ${description}`);
    }
  });

  window.once('ready-to-show', () => window.show());
  const startUrl = new URL(OWNER_WEB_URL);
  startUrl.searchParams.set('desktop_refresh', Date.now().toString());
  await window.loadURL(startUrl.toString());
}

app.whenReady().then(createWindow).catch((error) => {
  console.error('Could not start Bonzar Owner:', error);
  app.quit();
});

app.on('window-all-closed', () => {
  if (process.platform !== 'darwin') app.quit();
});

app.on('activate', () => {
  if (BrowserWindow.getAllWindows().length === 0) {
    createWindow().catch((error) => {
      console.error('Could not reopen Bonzar Owner:', error);
      app.quit();
    });
  }
});
