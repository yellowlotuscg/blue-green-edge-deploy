const test = require('node:test');
const assert = require('node:assert/strict');
const { routeRequest } = require('./color-router');

test('routes root to active color index', () => assert.equal(routeRequest({ uri: '/' }, 'green').uri, '/green/app/index.html'));
test('routes a path to active color', () => assert.equal(routeRequest({ uri: '/app/app.js' }, 'blue').uri, '/blue/app/app.js'));
test('normalizes a color with a trailing slash', () => assert.equal(routeRequest({ uri: '/data/status.json' }, 'green/').uri, '/green/data/status.json'));
test('rejects an invalid color', () => assert.throws(() => routeRequest({ uri: '/' }, 'purple'), /blue or green/));
