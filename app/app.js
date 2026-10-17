const statusLabel = {
  operational: 'Operational',
  degraded: 'Degraded performance',
  partial_outage: 'Partial outage',
  major_outage: 'Major outage'
};

const escapeHtml = (value) => String(value).replace(/[&<>'"]/g, (char) => ({
  '&': '&amp;', '<': '&lt;', '>': '&gt;', "'": '&#39;', '"': '&quot;'
}[char]));

function renderService(service) {
  const label = statusLabel[service.status] || service.status;
  return `<article class="service-card ${escapeHtml(service.status)}">
    <div><h3>${escapeHtml(service.name)}</h3><p>${escapeHtml(service.description)}</p></div>
    <span class="badge">${escapeHtml(label)}</span>
  </article>`;
}

function renderIncident(incident) {
  return `<article class="incident">
    <div class="incident-head"><h3>${escapeHtml(incident.title)}</h3><span>${escapeHtml(incident.status)}</span></div>
    <p>${escapeHtml(incident.message)}</p><time datetime="${escapeHtml(incident.created_at)}">${escapeHtml(new Date(incident.created_at).toLocaleString())}</time>
  </article>`;
}

async function loadStatus() {
  const response = await fetch('/data/status.json', { cache: 'no-store' });
  if (!response.ok) throw new Error(`status request failed: ${response.status}`);
  return response.json();
}

try {
  const data = await loadStatus();
  const outages = data.services.filter((service) => service.status !== 'operational').length;
  document.querySelector('#summary').textContent = outages ? `${outages} service(s) need attention.` : 'All systems operational.';
  document.querySelector('#updated').textContent = `Updated ${new Date(data.generated_at).toLocaleString()}`;
  document.querySelector('#services').innerHTML = data.services.map(renderService).join('');
  document.querySelector('#incidents').innerHTML = data.incidents.length
    ? data.incidents.map(renderIncident).join('')
    : '<p class="empty">No recent incidents.</p>';
} catch (error) {
  document.querySelector('#summary').textContent = 'Status is temporarily unavailable.';
  document.querySelector('#services').innerHTML = '<p class="empty">Unable to load service data.</p>';
  console.error(error);
}
