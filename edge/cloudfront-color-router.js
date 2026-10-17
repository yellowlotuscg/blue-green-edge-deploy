import cf from 'cloudfront';

function route(request, color) {
  const selected = color === 'green' ? 'green' : 'blue';
  const suffix = request.uri === '/' ? '/app/index.html' : (request.uri.startsWith('/') ? request.uri : `/${request.uri}`);
  request.uri = `/${selected}${suffix}`;
  return request;
}

async function handler(event) {
  const request = event.request;
  let activeColor = 'blue';
  try {
    const kvsHandle = cf.kvs();
    activeColor = await kvsHandle.get('active_color');
  } catch (_) {
    // Keep blue as a safe first-deploy default if KVS is not readable.
  }
  return route(request, activeColor);
}

export { handler };
