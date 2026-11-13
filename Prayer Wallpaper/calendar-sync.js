"use strict";

const fs = require("node:fs");
const path = require("node:path");
const { randomUUID } = require("node:crypto");

// Date-only events follow the calendar day, even if Windows uses another zone.
process.env.TZ = "Europe/Istanbul";

const DAY = 86_400_000;
const readJson = file => JSON.parse(fs.readFileSync(file, "utf8").replace(/^\uFEFF/, ""));
const privateDirectory = path.join(process.env.LOCALAPPDATA, "Sariyer Widgets");
const sourceFile = path.join(privateDirectory, "calendar-source.json");
const dataFile = path.join(privateDirectory, "calendar-snapshot.js");
const lockFile = path.join(privateDirectory, "calendar-sync.lock");
let nextPrayerRefresh = 0;

async function refreshPrayerSchedule() {
  const targetFile = path.join(privateDirectory, "rainmeter-target.json");
  if (Date.now() < nextPrayerRefresh || !fs.existsSync(targetFile)) return;
  const response = await fetch("https://namazvakti.mtopal.dev/vakitler/9541", {
    signal: AbortSignal.timeout(15_000)
  });
  if (!response.ok) throw new Error("Prayer timetable is temporarily unavailable.");
  const entries = await response.json();
  if (!Array.isArray(entries)) throw new Error("Invalid prayer timetable.");
  const fields = ["Imsak", "Gunes", "Ogle", "Ikindi", "Aksam", "Yatsi"];
  const dates = {};
  for (const entry of entries) {
    const date = entry?.MiladiTarihUzunIso8601?.slice(0, 10);
    const times = fields.map(field => entry?.[field]);
    if (typeof date !== "string" || !/^\d{4}-\d{2}-\d{2}$/.test(date)) continue;
    if (!times.every((time, i) => typeof time === "string" &&
        /^(?:[01]\d|2[0-3]):[0-5]\d$/.test(time) && (i === 0 || time > times[i - 1]))) continue;
    dates[date] = times;
  }
  if (!Object.keys(dates).length) throw new Error("No valid prayer times received.");
  const { dataPath } = readJson(targetFile);
  const snapshot = { updated: Date.now(), dates };
  writeAtomic(path.join(path.dirname(dataPath), "ScheduleAPI.lua"), "return " + luaValue(snapshot) + "\n");
  nextPrayerRefresh = Date.now() + 12 * 60 * 60_000;
}

function writeAtomic(file, contents) {
  const temporary = file + "." + randomUUID() + ".tmp";
  try {
    fs.writeFileSync(temporary, contents);
    fs.renameSync(temporary, file);
  } finally {
    fs.rmSync(temporary, { force: true });
  }
}

function calendarAddress(value) {
  let url;
  try {
    url = new URL(value);
  } catch {
    throw new Error("Paste an iCal address from Google Calendar.");
  }
  if (url.origin !== "https://calendar.google.com" || url.username || url.password ||
      url.search || url.hash || !/^\/calendar\/ical\/[^/]+\/(?:private-[^/]+|public)\/basic\.ics$/i.test(url.pathname)) {
    throw new Error("Paste an iCal address from Google Calendar’s Integrate calendar settings.");
  }
  return url.href;
}

function calendarSnapshot(text, now = Date.now()) {
  const ical = require("node-ical");
  if (!text.trimStart().startsWith("BEGIN:VCALENDAR")) throw new Error("Invalid calendar data.");
  const today = new Date(now);
  const start = +new Date(today.getFullYear(), today.getMonth() - 6, 1);
  const end = +new Date(today.getFullYear(), today.getMonth() + 13, 1);
  const dateKey = new Intl.DateTimeFormat("sv-SE", { timeZone: "Europe/Istanbul", dateStyle: "short" });
  const dates = {};
  const dateLists = [];
  for (let day = start; day < end; day += DAY) {
    const list = [];
    dates[dateKey.format(day)] = list;
    dateLists.push(list);
  }
  const range = { from: new Date(start), to: new Date(end - 1), expandOngoing: true };
  for (const entry of Object.values(ical.sync.parseICS(text))) {
    if (entry.type !== "VEVENT" || entry.status === "CANCELLED" || !entry.start) continue;
    for (const event of ical.expandRecurringEvent(entry, range)) {
      if (event.event.status === "CANCELLED") continue;
      const eventStart = event.start.getTime();
      const eventEnd = event.end.getTime();
      if (!Number.isFinite(eventStart) || !Number.isFinite(eventEnd)) continue;
      const title = typeof event.summary === "string" ? event.summary.trim().slice(0, 250) : "";
      const item = { title: title || "Untitled event", start: eventStart, end: eventEnd, allDay: event.isFullDay };
      const firstDay = Math.max(0, Math.floor((eventStart - start) / DAY));
      for (let i = firstDay; i < dateLists.length; i++) {
        const dayStart = start + i * DAY;
        if (dayStart > eventStart && dayStart >= eventEnd) break;
        dateLists[i].push(item);
      }
    }
  }
  for (const list of dateLists) {
    list.sort((a, b) => Number(b.allDay) - Number(a.allDay) || a.start - b.start || a.title.localeCompare(b.title));
  }
  return { updated: now, firstDate: dateKey.format(start), lastDate: dateKey.format(end - DAY), dates };
}

async function downloadCalendar(address) {
  let response;
  try {
    response = await fetch(address, { redirect: "error", signal: AbortSignal.timeout(15_000) });
    if (!response.ok || !response.body) throw new Error("Request failed.");
    const chunks = [];
    let bytes = 0;
    for await (const chunk of response.body) {
      bytes += chunk.byteLength;
      if (bytes > 8 * 1024 * 1024) throw new Error("Calendar is too large.");
      chunks.push(chunk);
    }
    return calendarSnapshot(Buffer.concat(chunks).toString("utf8"));
  } catch {
    // Fetch failures can include the private feed address.
    throw new Error("Couldn’t read this calendar. Check the iCal address and try again.");
  }
}

function writeSnapshot(snapshot) {
  writeAtomic(dataFile, "receiveCalendarData(" + JSON.stringify(snapshot) + ");\n");
  const rainmeterTarget = path.join(privateDirectory, "rainmeter-target.json");
  if (fs.existsSync(rainmeterTarget)) {
    const { dataPath } = readJson(rainmeterTarget);
    writeAtomic(dataPath, "return " + luaValue(snapshot?.dates ?? {}) + "\n");
  }
}

function luaValue(value) {
  if (typeof value === "string") {
    return '"' + value.replace(/[\\ "\x00-\x1f]/g, character => {
      if (character === " ") return character;
      if (character === "\\" || character === '"') return "\\" + character;
      return "\\" + String(character.charCodeAt(0)).padStart(3, "0");
    }) + '"';
  }
  if (value === null) return "nil";
  if (typeof value !== "object") return String(value);
  const items = Array.isArray(value)
    ? value.map(luaValue)
    : Object.entries(value).map(([key, item]) => "[" + luaValue(key) + "]=" + luaValue(item));
  return "{" + items.join(",") + "}";
}

async function withCalendarLock(action) {
  let lock;
  try {
    lock = fs.openSync(lockFile, "wx");
  } catch (error) {
    if (error.code !== "EEXIST") throw error;
    if (Date.now() - (fs.statSync(lockFile, { throwIfNoEntry: false })?.mtimeMs ?? 0) < 60_000) {
      throw new Error("The calendar is already syncing. Try again in a moment.");
    }
    fs.rmSync(lockFile, { force: true });
    lock = fs.openSync(lockFile, "wx");
  }
  try {
    return await action();
  } finally {
    fs.closeSync(lock);
    fs.rmSync(lockFile, { force: true });
  }
}

async function setCalendarSource(value) {
  return withCalendarLock(async () => {
    if (value === null) {
      fs.rmSync(sourceFile, { force: true });
      writeSnapshot(null);
      return;
    }
    const address = calendarAddress(value);
    const snapshot = await downloadCalendar(address);
    writeAtomic(sourceFile, JSON.stringify({ address }));
    writeSnapshot(snapshot);
  });
}

async function refreshCalendar() {
  if (!fs.existsSync(sourceFile)) return;
  await withCalendarLock(async () => {
    if (!fs.existsSync(sourceFile)) return;
    const { address } = readJson(sourceFile);
    writeSnapshot(await downloadCalendar(calendarAddress(address)));
  });
}

if (require.main === module) {
  if (process.argv.includes("--watch")) {
    const poll = async () => {
      try {
        await Promise.allSettled([refreshCalendar(), refreshPrayerSchedule()]);
      } catch {
        // The last good snapshot stays available while the next sync retries.
      }
      setTimeout(poll, 10 * 60_000);
    };
    void poll();
  } else {
    refreshCalendar().catch(() => { process.exitCode = 1; });
  }
}

module.exports = { calendarSnapshot, setCalendarSource, refreshPrayerSchedule };
