"use strict";

const http = require("node:http");
const { randomBytes } = require("node:crypto");
const { spawn } = require("node:child_process");
const path = require("node:path");
const { setCalendarSource } = require("./calendar-sync");
const token = randomBytes(24).toString("hex");
let timer;

const page = '<!doctype html><meta charset="utf-8"><title>Connect desktop calendar</title>' +
  '<style>html{color-scheme:dark;font:16px Segoe UI;background:#0f1012;color:#fafafa}' +
  'main{max-width:480px;margin:50px auto;padding:24px}h1{font-size:24px}p{line-height:1.6}' +
  'input,button{box-sizing:border-box;font:inherit;padding:10px;border:1px solid #535960;border-radius:6px}' +
  'input{width:100%;margin:10px 0}button{cursor:pointer;background:#9ee6a8;color:#0f1012}</style>' +
  '<main><h1>Google Calendar</h1><p>In Google Calendar, open Settings, choose your calendar, then Integrate calendar. ' +
  'Copy the Secret address in iCal format and paste it here.</p>' +
  '<form><label for="address">Calendar address</label><input id="address" type="password" autocomplete="off" required>' +
  '<button>Connect calendar</button></form><p id="status" role="status"></p></main>' +
  '<script>document.querySelector("form").onsubmit=async e=>{e.preventDefault();' +
  'const b=document.querySelector("button"),s=document.querySelector("#status"),a=document.querySelector("input");' +
  'b.disabled=true;s.textContent="Connecting…";try{const r=await fetch("/connect",{method:"POST",' +
  'headers:{"Content-Type":"application/json","X-Setup-Token":"' + token + '"},body:JSON.stringify({address:a.value.trim()})});' +
  's.textContent=await r.text();if(r.ok)a.value="";}catch{s.textContent="Open calendar setup again."}finally{b.disabled=false;}}</script>';

const server = http.createServer(async (request, response) => {
  const origin = "http://127.0.0.1:" + server.address().port;
  const reply = (code, text, type = "text/plain; charset=utf-8") => {
    response.writeHead(code, { "Content-Type": type, "Cache-Control": "no-store", "Cross-Origin-Resource-Policy": "same-origin" });
    response.end(text);
  };
  if (request.headers.host !== "127.0.0.1:" + server.address().port) return reply(403, "Open setup locally.");
  clearTimeout(timer);
  timer = setTimeout(() => server.close(), 15 * 60_000);
  if (request.method === "GET" && request.url === "/") return reply(200, page, "text/html; charset=utf-8");
  if (request.method !== "POST" || request.url !== "/connect" || request.headers.origin !== origin ||
      request.headers["x-setup-token"] !== token) return reply(403, "Open setup locally.");
  try {
    let body = "";
    request.setEncoding("utf8");
    for await (const chunk of request) {
      body += chunk;
      if (body.length > 2048) return reply(400, "Calendar address is too long.");
    }
    const { address } = JSON.parse(body);
    if (typeof address !== "string") return reply(400, "Enter your calendar address.");
    await setCalendarSource(address);
    reply(200, "Connected. Your desktop calendar will refresh within a minute.");
  } catch {
    reply(400, "Couldn’t connect. Check the secret iCal address and your internet connection.");
  }
});

server.listen(0, "127.0.0.1", () => {
  const url = "http://127.0.0.1:" + server.address().port;
  if (process.argv.includes("--no-browser")) process.stdout.write(url + "\n");
  else {
    const edge = path.join(process.env["ProgramFiles(x86)"], "Microsoft", "Edge", "Application", "msedge.exe");
    const browser = spawn(edge, ["--app=" + url], { detached: true, stdio: "ignore", windowsHide: true });
    browser.on("error", () => server.close());
    browser.unref();
  }
  timer = setTimeout(() => server.close(), 15 * 60_000);
});
