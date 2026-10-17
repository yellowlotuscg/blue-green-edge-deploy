const test = require('node:test');
const assert = require('node:assert/strict');
const { authGate } = require('./auth-gate');

const request = (uri, token) => ({ uri, headers: token ? { authorization: [{ value: `Bearer ${token}` }] } : {} });
const verifier = (token) => ({ valid: token !== 'bad', groups: token === 'admin' ? ['admins'] : ['users'] });

test('public request is allowed', () => assert.equal(authGate(request('/'), { verifyToken: verifier }).status, '200'));
test('anonymous admin request is 401', () => assert.equal(authGate(request('/admin'), { verifyToken: verifier }).status, '401'));
test('authenticated non-admin request is 403', () => assert.equal(authGate(request('/admin/settings', 'user'), { verifyToken: verifier }).status, '403'));
test('authenticated admin request is 200', () => assert.equal(authGate(request('/admin/settings', 'admin'), { verifyToken: verifier }).status, '200'));
test('invalid token is 403', () => assert.equal(authGate(request('/admin', 'bad'), { verifyToken: verifier }).status, '403'));
test('config files are always 404', () => {
  assert.equal(authGate(request('/data/app.config.json', 'admin'), { verifyToken: verifier }).status, '404');
  assert.equal(authGate(request('/admin/config/secrets', 'admin'), { verifyToken: verifier }).status, '404');
});
