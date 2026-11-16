const test = require('node:test');
const assert = require('node:assert/strict');
const { OWNER_WEB_URL, isAllowedOwnerUrl } = require('../src/security.cjs');

test('allows the Owner web site and its same-origin routes', () => {
  assert.equal(isAllowedOwnerUrl(OWNER_WEB_URL), true);
  assert.equal(
    isAllowedOwnerUrl(
      'https://mynameismrsindia-cloud.github.io/owner_web/orders',
    ),
    true,
  );
});

test('rejects other origins and non-HTTPS URLs', () => {
  assert.equal(isAllowedOwnerUrl('https://example.com/'), false);
  assert.equal(
    isAllowedOwnerUrl('https://mynameismrsindia-cloud.github.io.evil.test/'),
    false,
  );
  assert.equal(isAllowedOwnerUrl('http://mynameismrsindia-cloud.github.io/'), false);
  assert.equal(isAllowedOwnerUrl('not a URL'), false);
});
