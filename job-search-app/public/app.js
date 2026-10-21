const STORAGE_KEY = 'cerca-lavoro:tracker:v1';
const STATUSES = [
  { id: 'saved', label: 'Salvate' },
  { id: 'applied', label: 'Candidato' },
  { id: 'interview', label: 'Colloquio' },
  { id: 'offer', label: 'Offerta' },
  { id: 'rejected', label: 'Non selezionato' },
];

const $ = (sel, root = document) => root.querySelector(sel);
const form = $('#search-form');
const resultsEl = $('#results');
const summaryEl = $('#results-summary');
const noticeEl = $('#notice');
const paginationEl = $('#pagination');
const dialog = $('#job-dialog');

let currentPage = 1;
let lastResults = [];
let requestSeq = 0;
let dialogJobId = null;

/* ---------- Tracker storage (per-browser) ---------- */

function loadTracker() {
  try {
    const parsed = JSON.parse(localStorage.getItem(STORAGE_KEY) || '{}');
    return parsed && typeof parsed === 'object' ? parsed : {};
  } catch {
    return {};
  }
}

let tracker = loadTracker();

function persistTracker() {
  try {
    localStorage.setItem(STORAGE_KEY, JSON.stringify(tracker));
  } catch {
    // Storage may be unavailable (private mode); the tracker still works for this session.
  }
  $('#tracker-count').textContent = Object.keys(tracker).length;
}

function toggleSaved(job) {
  if (tracker[job.id]) delete tracker[job.id];
  else tracker[job.id] = { job, status: 'saved', notes: '', savedAt: new Date().toISOString() };
  persistTracker();
  refreshSaveButtons();
  renderBoard();
}

function setStatus(id, status) {
  if (!tracker[id]) return;
  tracker[id].status = status;
  tracker[id].updatedAt = new Date().toISOString();
  persistTracker();
  renderBoard();
}

/* ---------- Formatting helpers ---------- */

const rtf = new Intl.RelativeTimeFormat('it', { numeric: 'auto' });

function timeAgo(iso) {
  if (!iso) return '';
  const diffDays = Math.round((Date.parse(iso) - Date.now()) / 86_400_000);
  if (diffDays === 0) return 'oggi';
  if (Math.abs(diffDays) < 30) return rtf.format(diffDays, 'day');
  return rtf.format(Math.round(diffDays / 30), 'month');
}

function safeUrl(url) {
  try {
    const parsed = new URL(url);
    return parsed.protocol === 'https:' || parsed.protocol === 'http:' ? parsed.href : null;
  } catch {
    return null;
  }
}

function el(tag, props = {}, ...children) {
  const node = document.createElement(tag);
  Object.assign(node, props);
  node.append(...children.filter((c) => c !== null && c !== undefined && c !== false));
  return node;
}

function metaPills(job) {
  const pills = [];
  if (job.location) pills.push(el('span', { textContent: `📍 ${job.location}` }));
  if (job.remote) pills.push(el('span', { className: 'pill remote', textContent: 'Remoto' }));
  for (const t of job.types) pills.push(el('span', { className: 'pill', textContent: t }));
  if (job.salary) pills.push(el('span', { textContent: `💶 ${job.salary}` }));
  if (job.publishedAt) pills.push(el('span', { textContent: timeAgo(job.publishedAt) }));
  pills.push(el('span', { textContent: `via ${job.source}` }));
  return pills;
}

/* ---------- Search ---------- */

function readParams() {
  const data = new FormData(form);
  const params = new URLSearchParams();
  for (const key of ['q', 'location', 'maxAgeDays', 'sort']) {
    const value = String(data.get(key) || '').trim();
    if (value && !(key === 'sort' && value === 'relevance')) params.set(key, value);
  }
  if (data.get('remote')) params.set('remote', 'true');
  const types = data.getAll('types');
  const sources = data.getAll('sources');
  if (types.length) params.set('types', types.join(','));
  if (sources.length) params.set('sources', sources.join(','));
  if (currentPage > 1) params.set('page', String(currentPage));
  return params;
}

function applyParams(params) {
  form.elements.q.value = params.get('q') || '';
  form.elements.location.value = params.get('location') || '';
  form.elements.remote.checked = params.get('remote') === 'true';
  form.elements.maxAgeDays.value = params.get('maxAgeDays') || '';
  form.elements.sort.value = params.get('sort') || 'relevance';
  currentPage = Math.max(1, parseInt(params.get('page'), 10) || 1);
}

function showSkeleton() {
  resultsEl.replaceChildren(...Array.from({ length: 5 }, () => el('li', { className: 'skeleton' })));
  paginationEl.replaceChildren();
}

// `params` is passed explicitly when restoring from the URL, before facet checkboxes exist.
async function runSearch({ pushHistory = true, params = readParams() } = {}) {
  const seq = ++requestSeq;
  if (pushHistory) {
    const qs = params.toString();
    history.pushState(null, '', qs ? `?${qs}` : location.pathname);
  }
  showSkeleton();
  summaryEl.textContent = 'Ricerca in corso…';

  let data;
  try {
    const res = await fetch(`/api/jobs?${params}`);
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    data = await res.json();
  } catch {
    if (seq !== requestSeq) return;
    summaryEl.textContent = '';
    resultsEl.replaceChildren(el('li', { className: 'empty', textContent: 'Impossibile caricare le offerte. Controlla la connessione e riprova.' }));
    return;
  }
  // Ignore responses from searches that were superseded while in flight.
  if (seq !== requestSeq) return;

  currentPage = data.page;
  lastResults = data.results;
  renderFacets(data.facets, params);
  renderNotice(data);
  renderResults(data);
  renderPagination(data);
}

function renderNotice(data) {
  if (data.fallback) {
    noticeEl.textContent = 'Le fonti esterne non sono raggiungibili in questo momento: stai vedendo offerte dimostrative.';
    noticeEl.hidden = false;
  } else if (data.errors?.length) {
    noticeEl.textContent = `Alcune fonti non hanno risposto (${data.errors.map((e) => e.source).join(', ')}). I risultati potrebbero essere incompleti.`;
    noticeEl.hidden = false;
  } else {
    noticeEl.hidden = true;
  }
}

function renderFacets(facets, params) {
  const build = (container, name, items, selected) => {
    container.replaceChildren(
      ...items.map(({ value, count }) => {
        const input = el('input', { type: 'checkbox', name, value, checked: selected.includes(value) });
        input.setAttribute('form', 'search-form');
        return el('label', { className: 'check' }, input, ` ${value}`, el('span', { className: 'count', textContent: count }));
      })
    );
  };
  const split = (key) => (params.get(key) ? params.get(key).split(',') : []);
  build($('#type-filters'), 'types', facets.types, split('types'));
  build($('#source-filters'), 'sources', facets.sources, split('sources'));
}

function renderResults(data) {
  const n = data.total;
  summaryEl.textContent = n === 0 ? 'Nessuna offerta trovata' : `${n.toLocaleString('it-IT')} ${n === 1 ? 'offerta trovata' : 'offerte trovate'}`;

  if (n === 0) {
    resultsEl.replaceChildren(
      el('li', { className: 'empty' },
        el('strong', { textContent: 'Nessun risultato.' }),
        el('br'),
        'Prova con parole chiave diverse o rimuovi qualche filtro.')
    );
    return;
  }

  const tpl = $('#job-card');
  resultsEl.replaceChildren(
    ...data.results.map((job) => {
      const card = tpl.content.firstElementChild.cloneNode(true);
      card.dataset.id = job.id;
      $('.card-title', card).textContent = job.title;
      $('.company', card).textContent = job.company;
      $('.meta', card).append(...metaPills(job));
      $('.snippet', card).textContent = job.description.slice(0, 260);
      $('.card-main', card).addEventListener('click', () => openJob(job));
      const save = $('.save-btn', card);
      save.addEventListener('click', () => toggleSaved(job));
      updateSaveButton(save, job.id);
      return card;
    })
  );
}

function updateSaveButton(btn, id) {
  const saved = Boolean(tracker[id]);
  btn.setAttribute('aria-pressed', String(saved));
  btn.setAttribute('aria-label', saved ? 'Rimuovi dalle salvate' : 'Salva offerta');
  btn.title = saved ? 'Rimuovi dalle salvate' : 'Salva offerta';
}

function refreshSaveButtons() {
  for (const card of resultsEl.querySelectorAll('.card')) {
    updateSaveButton($('.save-btn', card), card.dataset.id);
  }
  if (dialog.open && dialogJobId) syncDialogTracking(dialogJobId);
}

function renderPagination({ page, totalPages }) {
  if (totalPages <= 1) {
    paginationEl.replaceChildren();
    return;
  }
  const pages = new Set([1, totalPages, page - 1, page, page + 1].filter((p) => p >= 1 && p <= totalPages));
  const sorted = [...pages].sort((a, b) => a - b);
  const go = (p) => {
    currentPage = p;
    runSearch();
    window.scrollTo({ top: 0, behavior: 'smooth' });
  };
  const buttons = [];
  buttons.push(el('button', { className: 'btn', type: 'button', textContent: '‹', disabled: page === 1, ariaLabel: 'Pagina precedente', onclick: () => go(page - 1) }));
  sorted.forEach((p, i) => {
    if (i > 0 && p - sorted[i - 1] > 1) buttons.push(el('span', { className: 'muted', textContent: '…' }));
    const b = el('button', { className: 'btn', type: 'button', textContent: p, onclick: () => go(p) });
    if (p === page) b.setAttribute('aria-current', 'page');
    buttons.push(b);
  });
  buttons.push(el('button', { className: 'btn', type: 'button', textContent: '›', disabled: page === totalPages, ariaLabel: 'Pagina successiva', onclick: () => go(page + 1) }));
  paginationEl.replaceChildren(...buttons);
}

/* ---------- Job detail dialog ---------- */

function openJob(job) {
  dialogJobId = job.id;
  $('#dialog-title').textContent = job.title;
  $('#dialog-company').textContent = job.company;
  $('#dialog-meta').replaceChildren(...metaPills(job));
  $('#dialog-tags').replaceChildren(...job.tags.slice(0, 12).map((t) => el('span', { className: 'tag', textContent: t })));
  $('#dialog-description').textContent = job.description || 'Nessuna descrizione disponibile.';

  const apply = $('#dialog-apply');
  const href = safeUrl(job.url);
  apply.hidden = !href;
  if (href) apply.href = href;

  $('#dialog-save').onclick = () => toggleSaved(job);
  syncDialogTracking(job.id);
  if (!dialog.open) dialog.showModal();
  $('.dialog-body', dialog).scrollTop = 0;
}

function syncDialogTracking(id) {
  const entry = tracker[id];
  $('#dialog-save').textContent = entry ? '★ Salvata' : '☆ Salva';
  $('#dialog-status-wrap').hidden = !entry;
  $('#dialog-notes-wrap').hidden = !entry;
  if (entry) {
    $('#dialog-status').value = entry.status;
    $('#dialog-notes').value = entry.notes || '';
  }
}

$('#dialog-status').replaceChildren(...STATUSES.map((s) => el('option', { value: s.id, textContent: s.label })));
$('#dialog-status').addEventListener('change', (e) => setStatus(dialogJobId, e.target.value));
$('#dialog-notes').addEventListener('input', (e) => {
  if (!tracker[dialogJobId]) return;
  tracker[dialogJobId].notes = e.target.value;
  persistTracker();
});
$('#dialog-notes').addEventListener('change', renderBoard);
dialog.addEventListener('click', (e) => {
  // Clicking the backdrop (the dialog element itself, outside the article) closes it.
  if (e.target === dialog || e.target.closest('[data-close]')) dialog.close();
});
dialog.addEventListener('close', () => {
  dialogJobId = null;
});

/* ---------- Tracker board ---------- */

function renderBoard() {
  const entries = Object.entries(tracker).sort((a, b) => (b[1].updatedAt || b[1].savedAt).localeCompare(a[1].updatedAt || a[1].savedAt));
  const board = $('#board');
  board.replaceChildren(
    ...STATUSES.map((status) => {
      const items = entries.filter(([, e]) => e.status === status.id);
      const list = el('ul', {}, ...items.map(([id, entry]) => miniCard(id, entry)));
      return el('section', { className: 'column', ariaLabel: status.label },
        el('h2', {}, el('span', { textContent: status.label }), el('span', { className: 'muted', textContent: items.length })),
        items.length ? list : el('p', { className: 'empty-col', textContent: status.id === 'saved' ? 'Salva un’offerta dalla ricerca con ☆' : 'Nessuna offerta' })
      );
    })
  );
}

function miniCard(id, entry) {
  const select = el('select', { ariaLabel: 'Stato candidatura' }, ...STATUSES.map((s) => el('option', { value: s.id, textContent: s.label, selected: s.id === entry.status })));
  select.addEventListener('change', () => setStatus(id, select.value));
  const remove = el('button', {
    type: 'button', className: 'icon-btn remove', textContent: '✕', title: 'Rimuovi', ariaLabel: `Rimuovi ${entry.job.title}`,
    onclick: () => {
      if (!confirm(`Rimuovere “${entry.job.title}” dalle tue candidature?`)) return;
      delete tracker[id];
      persistTracker();
      refreshSaveButtons();
      renderBoard();
    },
  });
  return el('li', { className: 'mini-card' },
    el('button', { type: 'button', className: 'link', textContent: entry.job.title, onclick: () => openJob(entry.job) }),
    el('span', { className: 'company', textContent: entry.job.company }),
    entry.notes ? el('span', { className: 'note', textContent: entry.notes }) : null,
    el('div', { className: 'row' }, select, remove)
  );
}

/* ---------- Tabs & events ---------- */

function showView(view) {
  for (const tab of document.querySelectorAll('.tab')) {
    const active = tab.dataset.view === view;
    tab.setAttribute('aria-selected', String(active));
    $(`#${tab.getAttribute('aria-controls')}`).hidden = !active;
  }
  if (view === 'tracker') renderBoard();
}

for (const tab of document.querySelectorAll('.tab')) {
  tab.addEventListener('click', () => showView(tab.dataset.view));
}

form.addEventListener('submit', (e) => {
  e.preventDefault();
  currentPage = 1;
  showView('search');
  runSearch();
});

// Filters and sort apply immediately; text fields wait for submit.
document.addEventListener('change', (e) => {
  const target = e.target;
  if (target.form !== form || target.type === 'search') return;
  currentPage = 1;
  runSearch();
});

$('#reset-filters').addEventListener('click', () => {
  form.elements.remote.checked = false;
  form.elements.maxAgeDays.value = '';
  for (const box of document.querySelectorAll('#type-filters input, #source-filters input')) box.checked = false;
  currentPage = 1;
  runSearch();
});

window.addEventListener('popstate', () => {
  const params = new URLSearchParams(location.search);
  applyParams(params);
  runSearch({ pushHistory: false, params });
});

if (window.matchMedia('(max-width: 860px)').matches) $('#filters-panel').open = false;

const initialParams = new URLSearchParams(location.search);
applyParams(initialParams);
persistTracker();
runSearch({ pushHistory: false, params: initialParams });
