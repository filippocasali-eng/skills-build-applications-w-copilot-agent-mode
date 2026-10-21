'use strict';

const http = require('node:http');
const path = require('node:path');
const fs = require('node:fs/promises');
const { createJobStore } = require('./lib/store');
const { parseQuery, searchJobs } = require('./lib/search');

const PUBLIC_DIR = path.join(__dirname, 'public');
const MIME_TYPES = {
  '.html': 'text/html; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.svg': 'image/svg+xml',
  '.png': 'image/png',
  '.ico': 'image/x-icon',
};

function sendJson(res, status, body) {
  res.writeHead(status, { 'Content-Type': MIME_TYPES['.json'], 'Cache-Control': 'no-store' });
  res.end(JSON.stringify(body));
}

async function serveStatic(req, res, pathname) {
  const relative = pathname === '/' ? 'index.html' : decodeURIComponent(pathname).replace(/^\/+/, '');
  const filePath = path.resolve(PUBLIC_DIR, relative);
  if (!filePath.startsWith(PUBLIC_DIR + path.sep)) {
    res.writeHead(403).end('Forbidden');
    return;
  }
  try {
    const data = await fs.readFile(filePath);
    res.writeHead(200, {
      'Content-Type': MIME_TYPES[path.extname(filePath)] || 'application/octet-stream',
      'X-Content-Type-Options': 'nosniff',
    });
    res.end(req.method === 'HEAD' ? undefined : data);
  } catch {
    res.writeHead(404, { 'Content-Type': 'text/plain; charset=utf-8' }).end('Pagina non trovata');
  }
}

function createServer(store = createJobStore()) {
  return http.createServer(async (req, res) => {
    const url = new URL(req.url, 'http://localhost');
    try {
      if (req.method !== 'GET' && req.method !== 'HEAD') {
        res.writeHead(405, { Allow: 'GET, HEAD' }).end();
        return;
      }
      if (url.pathname === '/api/jobs') {
        const { jobs, fetchedAt, fallback, errors } = await store.getJobs();
        const result = searchJobs(jobs, parseQuery(url.searchParams));
        sendJson(res, 200, { ...result, fetchedAt: new Date(fetchedAt).toISOString(), fallback, errors });
        return;
      }
      if (url.pathname === '/api/health') {
        sendJson(res, 200, { ok: true });
        return;
      }
      await serveStatic(req, res, url.pathname);
    } catch (err) {
      console.error(err);
      sendJson(res, 500, { error: 'Errore interno del server' });
    }
  });
}

if (require.main === module) {
  const port = Number(process.env.PORT) || 3000;
  const store = createJobStore({ useLive: process.env.OFFLINE !== '1' });
  createServer(store).listen(port, () => {
    console.log(`Cerca Lavoro in ascolto su http://localhost:${port}`);
  });
}

module.exports = { createServer };
