"use strict";

const { spawn, execFile } = require("node:child_process");
const { randomBytes } = require("node:crypto");
const fs = require("node:fs");
const http = require("node:http");
const path = require("node:path");
const { promisify } = require("node:util");
const { setCalendarSource } = require("./calendar-sync");

const run = promisify(execFile);
const appData = path.join(process.env.LOCALAPPDATA, "Lively Wallpaper");
const lively = path.join(process.env.LOCALAPPDATA, "Programs", "Lively Wallpaper", "Lively.exe");
const edge = path.join(process.env["ProgramFiles(x86)"], "Microsoft", "Edge", "Application", "msedge.exe");
const readJson = file => JSON.parse(fs.readFileSync(file, "utf8").replace(/^\uFEFF/, ""));
const library = readJson(path.join(appData, "Settings.json")).WallpaperDir;
const project = path.join(library, "wallpapers", "istanbul-prayer-dashboard");
const readActiveDisplay = () => readJson(path.join(appData, "WallpaperLayout.json"))
  .find(entry => path.resolve(entry.LivelyInfoPath) === project)?.LivelyScreen.Index;
const monitor = readActiveDisplay();
if (!monitor) throw new Error("Set Sarıyer Prayer Dashboard as the Lively wallpaper first.");
const propertyFile = path.join(library, "SaveData", "wpdata", "istanbul-prayer-dashboard",
  String(monitor), "LivelyProperties.json");
const token = randomBytes(24).toString("hex");
const positionKeys = ["positionX", "positionY", "calendarX", "calendarY"];
const sizeKeys = ["panelWidth", "panelHeight", "calendarWidth", "calendarHeight"];
const opacityKeys = ["panelOpacity", "calendarOpacity"];
const toggleKeys = ["clockSeconds", "calendarShowFinished"];
const colorKeys = ["panelBackground", "panelText", "accent", "calendarBackground", "calendarText", "calendarAccent"];
const keys = [...positionKeys, ...sizeKeys, ...opacityKeys, ...toggleKeys, ...colorKeys];
let idleTimer;

function initializeEditor(settings, accessToken) {
  const notice = document.querySelector("#editor-notice");
  const apply = document.querySelector("#editor-apply");
  for (const [name, property] of Object.entries(settings)) {
    livelyPropertyListener(name, property.value);
  }

  apply.addEventListener("click", async () => {
    apply.disabled = true;
    notice.textContent = "Applying…";
    try {
      const response = await fetch("/apply", {
        method: "POST",
        headers: { "Content-Type": "application/json", "X-Layout-Token": accessToken },
        body: JSON.stringify(widgetEditorValues())
      });
      notice.textContent = await response.text();
    } catch {
      notice.textContent = "The editor session ended. Open Edit desktop widgets again.";
    } finally {
      apply.disabled = false;
    }
  });

  document.querySelector("#calendar-desktop-help").hidden = true;
  const form = document.querySelector("#calendar-connection");
  const address = document.querySelector("#calendar-source");
  const status = document.querySelector("#calendar-connection-status");
  const disconnect = document.querySelector("#calendar-disconnect");
  const submit = form.querySelector('[type="submit"]');
  form.hidden = false;
  async function saveCalendar(value) {
    submit.disabled = disconnect.disabled = true;
    status.textContent = value ? "Connecting…" : "Disconnecting…";
    try {
      const response = await fetch("/calendar-source", {
        method: "POST",
        headers: { "Content-Type": "application/json", "X-Layout-Token": accessToken },
        body: JSON.stringify({ address: value })
      });
      status.textContent = await response.text();
      if (response.ok) {
        address.value = "";
        loadCalendarData();
      }
    } catch {
      status.textContent = "The editor session ended. Open Edit desktop widgets again.";
    } finally {
      submit.disabled = disconnect.disabled = false;
    }
  }
  form.addEventListener("submit", event => {
    event.preventDefault();
    void saveCalendar(address.value.trim());
  });
  disconnect.addEventListener("click", () => void saveCalendar(null));
  document.querySelector("#calendar-setup").addEventListener("close", () => { address.value = ""; });
}

const toolbar = '<aside class="layout-toolbar"><span id="editor-notice">' +
  'Drag to move, drag an edge to resize, or right-click for settings.</span><button id="editor-apply">Apply to desktop</button></aside>';
const toolbarStyle = '<style>.layout-toolbar{position:fixed;bottom:10px;left:50%;translate:-50% 0;' +
  'z-index:3;display:flex;align-items:center;gap:12px;padding:6px 10px;border:1px solid #535960;' +
  'border-radius:8px;background:#0b0c0e;font:14px Segoe UI,sans-serif;white-space:nowrap}' +
  '.layout-toolbar button{font:inherit;padding:5px 9px;cursor:pointer}</style>';
const mimeTypes = {
  ".css": "text/css", ".js": "text/javascript", ".svg": "image/svg+xml",
  ".jpg": "image/jpeg", ".jpeg": "image/jpeg", ".png": "image/png", ".webp": "image/webp"
};

function reply(response, status, value, type = "text/plain") {
  response.writeHead(status, {
    "Content-Type": type,
    "Cache-Control": "no-store",
    "Cross-Origin-Resource-Policy": "same-origin",
    "X-Content-Type-Options": "nosniff"
  });
  response.end(value);
}

async function readRequest(request, limit) {
  let body = "";
  request.setEncoding("utf8");
  for await (const chunk of request) {
    body += chunk;
    if (body.length > limit) return null;
  }
  try { return JSON.parse(body); } catch { return null; }
}

function integerInRange(value, min, max) {
  return Number.isInteger(value) && value >= min && value <= max;
}

async function applyLayout(request, response) {
  const layout = await readRequest(request, 512);
  if (!layout ||
      !positionKeys.every(key => integerInRange(layout[key], 0, 100)) ||
      !sizeKeys.every(key => layout[key] === 0 || integerInRange(layout[key], key === "calendarHeight" ? 180 : 220, 4000)) ||
      !opacityKeys.every(key => integerInRange(layout[key], 50, 100)) ||
      !toggleKeys.every(key => typeof layout[key] === "boolean") ||
      !colorKeys.every(key => typeof layout[key] === "string" && /^#[\da-f]{6}$/i.test(layout[key]))) {
    return reply(response, 400, "Check the widget dimensions and palette colors.");
  }
  if (readActiveDisplay() !== monitor) return reply(response, 409, "The active wallpaper has changed.");
  const settings = readJson(propertyFile);
  for (const key of keys) settings[key].value = layout[key];
  const temporaryFile = propertyFile + "." + token + ".tmp";
  fs.writeFileSync(temporaryFile, JSON.stringify(settings, null, 2));
  fs.renameSync(temporaryFile, propertyFile);
  try {
    await run(lively, ["setwp", "--file", "reload", "--monitor", String(monitor)], { windowsHide: true });
    reply(response, 200, "Layout saved to your desktop.");
  } catch {
    reply(response, 500, "Layout saved. Restart Lively to apply it.");
  }
}

async function connectCalendar(request, response) {
  const data = await readRequest(request, 2048);
  if (!data || (data.address !== null && typeof data.address !== "string")) {
    return reply(response, 400, "Enter a Google Calendar iCal address.");
  }
  try {
    await setCalendarSource(data.address);
    reply(response, 200, data.address === null ? "Calendar disconnected." : "Calendar connected.");
  } catch (error) {
    reply(response, 400, error.code ? "Couldn’t save the calendar connection." : error.message);
  }
}

const server = http.createServer(async (request, response) => {
  if (request.headers.host !== "127.0.0.1:" + server.address().port) {
    return reply(response, 403, "Open the editor from its local shortcut.");
  }
  clearTimeout(idleTimer);
  idleTimer = setTimeout(() => server.close(), 15 * 60_000);
  try {
    const origin = "http://" + request.headers.host;
    const url = new URL(request.url, origin);
    if (url.origin !== origin) return reply(response, 403, "Editor session required.");
    if (request.method === "POST") {
      if (request.headers.origin !== origin || request.headers["x-layout-token"] !== token) {
        return reply(response, 403, "Editor session required.");
      }
      if (url.pathname === "/apply") await applyLayout(request, response);
      else if (url.pathname === "/calendar-source") await connectCalendar(request, response);
      else reply(response, 404, "File not found.");
    } else if (request.method === "GET" && request.url === "/") {
      const html = fs.readFileSync(path.join(project, "index.html"), "utf8")
        .replace("</head>", toolbarStyle + '<script defer src="editor.js"></script></head>')
        .replace("</body>", toolbar + "</body>");
      reply(response, 200, html, "text/html; charset=utf-8");
    } else if (request.method === "GET" && request.url === "/editor.js") {
      const script = "(" + initializeEditor.toString() + ")(" +
        JSON.stringify(readJson(propertyFile)) + "," + JSON.stringify(token) + ");";
      reply(response, 200, script, "text/javascript; charset=utf-8");
    } else if (request.method === "GET") {
      const file = decodeURIComponent(url.pathname.slice(1));
      const isBackground = /^backgrounds\/[^/\\:]+$/.test(file) && /\.(svg|jpe?g|png|webp)$/i.test(file);
      if (!isBackground && !["style.css", "script.js", "schedule.js", "widgets.js", "calendar.js", "calendar-data.js"].includes(file)) {
        return reply(response, 404, "File not found.");
      }
      reply(response, 200, fs.readFileSync(path.join(project, file)), mimeTypes[path.extname(file).toLowerCase()]);
    } else {
      reply(response, 404, "File not found.");
    }
  } catch {
    reply(response, 500, "The editor could not finish that action.");
  }
});

server.listen(0, "127.0.0.1", () => {
  const url = "http://127.0.0.1:" + server.address().port;
  if (process.argv.includes("--no-browser")) {
    process.stdout.write(url + "\n");
  } else {
    const browser = spawn(edge, ["--app=" + url, "--start-maximized"], { detached: true, stdio: "ignore" });
    browser.on("error", () => server.close());
    browser.unref();
  }
  idleTimer = setTimeout(() => server.close(), 15 * 60_000);
});
