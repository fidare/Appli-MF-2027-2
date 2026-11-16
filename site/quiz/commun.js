"use strict";
// Quiz Marvel Miss France : fonctions communes (joueurs et administrateur).

// Base Supabase (même projet que les Pronostics). Clé « publishable » :
// faite pour être publiée, toutes les écritures sont contrôlées par
// les fonctions qz_* côté serveur.
var SUPABASE = {
  url: "https://vqzvwihmyzjnoqnqrtsv.supabase.co",
  anonKey: "sb_publishable_7r4EbkKj3F5yLdgAUZn28w_EWwZZBCo"
};

function rpc(name, params, keepalive) {
  return fetch(SUPABASE.url + "/rest/v1/rpc/" + name, {
    method: "POST",
    keepalive: !!keepalive,
    headers: { "Content-Type": "application/json", "apikey": SUPABASE.anonKey },
    body: JSON.stringify(params || {})
  }).then(function (r) {
    if (r.status === 204) return null;
    return r.json().then(function (data) {
      if (!r.ok) {
        var msg = (data && (data.message || data.hint || data.error)) || ("Erreur " + r.status);
        var e = new Error(msg); e.serveur = true; throw e;
      }
      return data;
    });
  });
}

function esc(s) {
  return String(s == null ? "" : s)
    .replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;");
}

// Normalisation proche de celle du serveur (qz_norm), pour l'import.
function norm(s) {
  return String(s == null ? "" : s).toLowerCase()
    .replace(/œ/g, "oe").replace(/æ/g, "ae").replace(/ß/g, "ss")
    .normalize("NFD").replace(/[̀-ͯ]/g, "")
    .replace(/[^a-z0-9]+/g, " ").trim();
}

function nb(n) {
  var x = Number(n);
  return (Math.round(x * 100) / 100).toString().replace(".", ",");
}

function pluriel(n, mot) { return nb(n) + " " + mot + (Math.abs(Number(n)) >= 2 ? "s" : ""); }

var toastTimer = null;
function toast(msg, isErr) {
  var t = document.getElementById("toast");
  t.textContent = msg;
  t.className = isErr ? "err" : "";
  t.style.display = "block";
  clearTimeout(toastTimer);
  toastTimer = setTimeout(function () { t.style.display = "none"; }, 3400);
}

var ICONS = {
  check: '<path d="M4.5 12.5 10 18 19.5 6.5"/>',
  x: '<path d="M6 6l12 12M18 6 6 18"/>',
  trophy: '<path d="M7 4h10v5a5 5 0 0 1-10 0zM7 5.5H4.5a3 3 0 0 0 3.2 4.4M17 5.5h2.5a3 3 0 0 1-3.2 4.4M12 14v3.5M8.5 20.5h7M12 17.5v3"/>',
  list: '<rect x="5" y="3.5" width="14" height="17" rx="2.5"/><path d="M8.5 8h7M8.5 11.5h7M8.5 15h4"/>',
  inbox: '<path d="M3.5 13.5 6 5h12l2.5 8.5v5h-17zM3.5 13.5h5l1 2h5l1-2h5"/>',
  sliders: '<path d="M4 7h9M17 7h3M4 17h5M13 17h7"/><circle cx="15" cy="7" r="2"/><circle cx="11" cy="17" r="2"/>',
  trash: '<path d="M4.5 6.5h15M9.5 6V4.5h5V6M6.5 6.5l.8 13h9.4l.8-13M10 10.5v5.5M14 10.5v5.5"/>',
  down: '<path d="M12 4v11M7 10.5l5 5 5-5M5 20h14"/>',
  up: '<path d="M12 16V5M7 9.5l5-5 5 5M5 20h14"/>',
  edit: '<path d="M4 20h4L19 9l-4-4L4 16zM13.5 6.5l4 4"/>',
  undo: '<path d="M9 7 4.5 11.5 9 16M5 11.5h9a5 5 0 0 1 0 10h-3"/>',
  exit: '<path d="M15 4H5v16h10M10 12h10M17 9l3 3-3 3"/>',
  left: '<path d="M14.5 5.5 8 12l6.5 6.5"/>',
  right: '<path d="M9.5 5.5 16 12l-6.5 6.5"/>',
  cloud: '<path d="M7 18.5h10a4 4 0 0 0 .6-8 6 6 0 0 0-11.4 1.5A3.3 3.3 0 0 0 7 18.5z"/>',
  link: '<path d="M10 14a4 4 0 0 0 5.7 0l3-3a4 4 0 0 0-5.7-5.7l-1 1M14 10a4 4 0 0 0-5.7 0l-3 3a4 4 0 0 0 5.7 5.7l1-1"/>',
  refresh: '<path d="M19.5 12a7.5 7.5 0 1 1-2.2-5.3M19.5 4.5v4h-4"/>'
};
function icon(n) {
  return '<svg class="ic" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">' + ICONS[n] + '</svg>';
}

// Emblème : bouclier à anneaux rouges et blancs, étoile sur fond bleu.
var SHIELD = '<svg class="shield" viewBox="0 0 40 40" aria-hidden="true">'
  + '<circle cx="20" cy="20" r="19" fill="#e62429"/><circle cx="20" cy="20" r="15" fill="#f4f6fb"/>'
  + '<circle cx="20" cy="20" r="11" fill="#e62429"/><circle cx="20" cy="20" r="7.5" fill="#2f6fd6"/>'
  + '<path d="M20 13.2l1.6 4.6h4.8l-3.9 2.9 1.5 4.6-4-2.9-4 2.9 1.5-4.6-3.9-2.9h4.8z" fill="#f4f6fb"/></svg>';

// Titre avec le dernier mot en rouge, façon affiche.
function brandHtml(titre) {
  var t = String(titre || "Le Quiz").trim();
  var i = t.lastIndexOf(" ");
  return i > 0 ? esc(t.slice(0, i)) + " <em>" + esc(t.slice(i + 1)) + "</em>" : "<em>" + esc(t) + "</em>";
}

function dateFr(iso) {
  if (!iso) return "";
  var d = new Date(iso);
  return d.toLocaleDateString("fr-FR") + " " + d.toLocaleTimeString("fr-FR", { hour: "2-digit", minute: "2-digit" });
}

function store(k, v) {
  try {
    if (v === undefined) return JSON.parse(localStorage.getItem(k));
    if (v === null) localStorage.removeItem(k); else localStorage.setItem(k, JSON.stringify(v));
  } catch (e) { return null; }
}

(function ciel() {
  var seed = 2027, st = "";
  function r() { seed = (seed * 16807) % 2147483647; return seed / 2147483647; }
  for (var i = 0; i < 70; i++) {
    var tw = i % 6 === 0;
    st += '<circle cx="' + (r() * 100).toFixed(2) + '%" cy="' + (r() * 100).toFixed(2) + '%" r="'
      + (0.4 + r() * (tw ? 1.1 : 0.7)).toFixed(2) + '" opacity="' + (0.25 + r() * 0.6).toFixed(2) + '"'
      + ' class="' + (i % 9 === 0 ? "or" : "") + (tw ? " tw" : "") + '"'
      + (tw ? ' style="animation-delay:' + (r() * 3).toFixed(2) + 's"' : "") + '/>';
  }
  var sky = document.getElementById("sky");
  if (sky) sky.insertAdjacentHTML("afterbegin", "<svg>" + st + "</svg>");
})();
