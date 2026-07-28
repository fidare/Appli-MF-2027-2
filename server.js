// Mini-sondage — serveur Node.js sans dépendance, stockage SQLite.
// Lancement :  node server.js   (PORT et ADMIN_KEY configurables par variables d'environnement)
const http = require("node:http");
const fs = require("node:fs");
const path = require("node:path");
const { DatabaseSync } = require("node:sqlite");

const PORT = process.env.PORT || 3000;
const ADMIN_KEY = process.env.ADMIN_KEY || "change-moi";
const DATA_DIR = path.join(__dirname, "data");

fs.mkdirSync(DATA_DIR, { recursive: true });
const db = new DatabaseSync(path.join(DATA_DIR, "sondage.db"));
db.exec(`
  CREATE TABLE IF NOT EXISTS reponses (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    prenom TEXT NOT NULL,
    prenom_cle TEXT NOT NULL UNIQUE,
    q1 TEXT NOT NULL,
    q2 TEXT NOT NULL,
    cree_le TEXT NOT NULL DEFAULT (datetime('now')),
    modifie_le TEXT NOT NULL DEFAULT (datetime('now'))
  )
`);

const insertReponse = db.prepare(`
  INSERT INTO reponses (prenom, prenom_cle, q1, q2)
  VALUES (?, ?, ?, ?)
  ON CONFLICT(prenom_cle) DO UPDATE SET
    prenom = excluded.prenom,
    q1 = excluded.q1,
    q2 = excluded.q2,
    modifie_le = datetime('now')
`);
const listReponses = db.prepare("SELECT prenom, q1, q2, cree_le, modifie_le FROM reponses ORDER BY cree_le");

const INDEX_HTML = fs.readFileSync(path.join(__dirname, "public", "index.html"));

function esc(s) {
  return String(s).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;");
}

function sendJson(res, status, obj) {
  res.writeHead(status, { "Content-Type": "application/json; charset=utf-8" });
  res.end(JSON.stringify(obj));
}

function readBody(req, limit, cb) {
  let body = "";
  let tooBig = false;
  req.on("data", (chunk) => {
    body += chunk;
    if (body.length > limit) { tooBig = true; req.destroy(); }
  });
  req.on("end", () => { if (!tooBig) cb(body); });
}

function adminAutorise(url) {
  return ADMIN_KEY && url.searchParams.get("cle") === ADMIN_KEY;
}

function pageAdmin() {
  const rows = listReponses.all();
  const lignes = rows.map((r) => `
      <tr>
        <td>${esc(r.prenom)}</td>
        <td>${esc(r.q1)}</td>
        <td class="libre">${esc(r.q2)}</td>
        <td class="date">${esc(r.modifie_le)} (UTC)</td>
      </tr>`).join("");
  return `<!doctype html>
<html lang="fr"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Réponses du sondage (${rows.length})</title>
<style>
  body { font-family: -apple-system, "Segoe UI", Roboto, sans-serif; background: #f5f6f8; color: #3c4658; margin: 0; padding: 2rem 1rem; }
  .wrap { max-width: 860px; margin: 0 auto; }
  h1 { font-family: Georgia, serif; color: #1b2a4a; font-size: 1.6rem; }
  .compteur { color: #b98f1f; font-weight: 600; }
  table { width: 100%; border-collapse: collapse; background: #fff; border: 1px solid #dfe3ea; border-radius: 10px; overflow: hidden; }
  th, td { text-align: left; padding: 0.7rem 0.9rem; border-bottom: 1px solid #dfe3ea; vertical-align: top; }
  th { background: #1b2a4a; color: #fff; font-size: 0.8rem; text-transform: uppercase; letter-spacing: 0.08em; }
  td.libre { white-space: pre-wrap; }
  td.date { color: #71809a; font-size: 0.85rem; white-space: nowrap; }
  .vide { padding: 2rem; text-align: center; color: #71809a; }
  .export { margin-top: 1rem; font-size: 0.9rem; }
</style></head><body><div class="wrap">
  <h1>Réponses au mini-sondage — <span class="compteur">${rows.length} / 3</span></h1>
  ${rows.length === 0
    ? '<div class="vide">Aucune réponse pour le moment.</div>'
    : `<div style="overflow-x:auto"><table>
        <thead><tr><th>Prénom</th><th>Q1 — le matin</th><th>Q2 — week-end d'équipe</th><th>Dernière modification</th></tr></thead>
        <tbody>${lignes}</tbody>
      </table></div>`}
  <p class="export"><a href="/api/reponses?cle=${encodeURIComponent(ADMIN_KEY)}">Export JSON</a></p>
</div></body></html>`;
}

const server = http.createServer((req, res) => {
  const url = new URL(req.url, `http://${req.headers.host || "localhost"}`);

  if (req.method === "GET" && (url.pathname === "/" || url.pathname === "/index.html")) {
    res.writeHead(200, { "Content-Type": "text/html; charset=utf-8" });
    return res.end(INDEX_HTML);
  }

  if (req.method === "POST" && url.pathname === "/api/reponses") {
    return readBody(req, 10_000, (body) => {
      let data;
      try { data = JSON.parse(body); } catch { return sendJson(res, 400, { erreur: "JSON invalide" }); }
      const prenom = String(data.prenom || "").trim().slice(0, 60);
      const q1 = String(data.q1 || "").trim().slice(0, 120);
      const q2 = String(data.q2 || "").trim().slice(0, 2000);
      if (!prenom || !q1 || !q2) return sendJson(res, 400, { erreur: "Prénom et deux réponses obligatoires" });
      insertReponse.run(prenom, prenom.toLowerCase(), q1, q2);
      return sendJson(res, 201, { ok: true });
    });
  }

  if (req.method === "GET" && url.pathname === "/admin") {
    if (!adminAutorise(url)) return sendJson(res, 403, { erreur: "Clé d'administration invalide (paramètre ?cle=...)" });
    res.writeHead(200, { "Content-Type": "text/html; charset=utf-8" });
    return res.end(pageAdmin());
  }

  if (req.method === "GET" && url.pathname === "/api/reponses") {
    if (!adminAutorise(url)) return sendJson(res, 403, { erreur: "Clé d'administration invalide" });
    return sendJson(res, 200, listReponses.all());
  }

  sendJson(res, 404, { erreur: "Page inconnue" });
});

server.listen(PORT, () => {
  console.log(`Mini-sondage démarré sur http://localhost:${PORT}`);
  console.log(`Page des réponses : http://localhost:${PORT}/admin?cle=${ADMIN_KEY}`);
  if (ADMIN_KEY === "change-moi") {
    console.log("⚠️  Pensez à définir une vraie clé : ADMIN_KEY=votre-secret node server.js");
  }
});
