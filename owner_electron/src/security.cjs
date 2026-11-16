const OWNER_WEB_URL = 'https://mynameismrsindia-cloud.github.io/owner_web/';
const OWNER_WEB_ORIGIN = new URL(OWNER_WEB_URL).origin;

function isAllowedOwnerUrl(value) {
  try {
    const url = new URL(value);
    return url.protocol === 'https:' && url.origin === OWNER_WEB_ORIGIN;
  } catch {
    return false;
  }
}

module.exports = {
  OWNER_WEB_URL,
  isAllowedOwnerUrl,
};
