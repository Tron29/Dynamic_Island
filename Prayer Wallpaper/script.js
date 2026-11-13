"use strict";

const ISTANBUL = "Europe/Istanbul";
const PRAYERS = ["Fajr", "Sunrise", "Dhuhr", "Asr", "Maghrib", "Isha"];
const FIELDS = ["Imsak", "Gunes", "Ogle", "Ikindi", "Aksam", "Yatsi"];
// Use Diyanet's Istanbul timetable for Sarıyer.
const CACHE_KEY = "istanbul-prayer-times-9541-v1";
const API = "https://namazvakti.mtopal.dev/vakitler/9541";
const DAY = 86_400_000;
const dayKey = new Intl.DateTimeFormat("sv-SE", { timeZone: ISTANBUL, dateStyle: "short" });
const timeLabel = new Intl.DateTimeFormat("en-GB", {
  timeZone: ISTANBUL, hour: "2-digit", minute: "2-digit", hourCycle: "h23"
});
const clockLabel = new Intl.DateTimeFormat("en-GB", {
  timeZone: ISTANBUL, hour: "2-digit", minute: "2-digit", second: "2-digit", hourCycle: "h23"
});

const currentTime = document.querySelector("#current-time");
const prayerCountdown = document.querySelector("#prayer-countdown");
const statusLabel = document.querySelector("#status");
const prayerTimes = document.querySelector("#prayer-times");
const nightTimes = document.querySelector("#night-times");
const rowTemplate = document.querySelector("#time-row");

function createTimeRow(container, name) {
  const row = rowTemplate.content.firstElementChild.cloneNode(true);
  row.cells[0].textContent = name;
  container.append(row);
  return {
    row,
    fill: row.querySelector(".fill"),
    startTime: row.querySelector(".start-time time"),
    endTime: row.querySelector(".end-time time"),
    start: null,
    end: null,
    progress: 0,
    active: false
  };
}

const rows = PRAYERS.map(name => createTimeRow(prayerTimes, name));
const lastThirdRow = createTimeRow(nightTimes, "Last third");
lastThirdRow.startTime.id = "night-time";

const schedule = new Map(Object.entries(ISTANBUL_SCHEDULE));
try {
  for (const [date, times] of Object.entries(JSON.parse(localStorage.getItem(CACHE_KEY)) || {})) {
    if (!schedule.has(date) && validTimes(times)) schedule.set(date, times);
  }
} catch {
  // The bundled timetable also works when browser storage is unavailable.
}

let refreshAfter = 0;
let refreshDate;
let timetable;
let shownPrayerTimes;

function validTimes(times) {
  return Array.isArray(times) && times.length === PRAYERS.length &&
    times.every((time, i) => /^(?:[01]\d|2[0-3]):[0-5]\d$/.test(time) &&
      (i === 0 || time > times[i - 1]));
}

async function refreshSchedule(now, dateToday) {
  if (dateToday === refreshDate && now < refreshAfter) return;
  refreshDate = dateToday;
  refreshAfter = now + 30 * 60_000;
  try {
    const response = await fetch(API, { signal: AbortSignal.timeout(10_000) });
    if (!response.ok) return;

    let received = 0;
    for (const entry of await response.json()) {
      if (typeof entry?.MiladiTarihUzunIso8601 !== "string") continue;
      const date = entry.MiladiTarihUzunIso8601.slice(0, 10);
      if (!/^\d{4}-\d{2}-\d{2}$/.test(date)) continue;
      const times = FIELDS.map(field => entry[field]);
      if (!validTimes(times)) continue;
      received++;
      if (ISTANBUL_SCHEDULE[date]) continue;
      schedule.set(date, times);
      timetable = undefined;
    }
    if (!received) return;
    refreshAfter = now + 12 * 60 * 60_000;
    const recent = [...schedule].filter(([date]) => date >= dayKey.format(now - DAY));
    localStorage.setItem(CACHE_KEY, JSON.stringify(Object.fromEntries(recent)));
  } catch {
    // Continue with the verified timetable and retry later.
  }
}

function timesOn(date) {
  return schedule.get(date)?.map(time => Date.parse(`${date}T${time}:00+03:00`));
}

function nightFor(sunset, dawn) {
  const duration = dawn - sunset;
  if (!(duration > 0)) return { dawn, midnight: null, third: null };
  const midnight = sunset + duration / 2;
  const third = Math.ceil((sunset + duration * 2 / 3) / 60_000) * 60_000;
  return { dawn, midnight, third };
}

function showTime(element, instant) {
  element.textContent = instant ? timeLabel.format(instant) : "—";
  if (instant) element.dateTime = new Date(instant).toISOString();
  else element.removeAttribute("datetime");
}

function showPeriod(entry, start = null, end = null) {
  if (entry.start !== start) {
    entry.start = start;
    showTime(entry.startTime, start);
  }
  if (entry.end !== end) {
    entry.end = end;
    showTime(entry.endTime, end);
  }
}

function countdown(milliseconds) {
  const seconds = Math.max(0, Math.ceil(milliseconds / 1000));
  return [Math.floor(seconds / 3600), Math.floor(seconds / 60) % 60, seconds % 60]
    .map(value => String(value).padStart(2, "0")).join(":");
}

function setProgress(entry, now) {
  const { start, end } = entry;
  const active = Boolean(start && end && now >= start && now < end);
  const progress = start && end > start ? Math.min(1, Math.max(0, (now - start) / (end - start))) : 0;
  if (entry.active !== active) {
    entry.active = active;
    entry.row.dataset.active = active;
  }
  if (entry.progress !== progress) {
    entry.progress = progress;
    entry.fill.style.setProperty("--progress", progress);
  }
}

function timetableFor(now, date) {
  if (timetable?.date === date) return timetable;
  const today = timesOn(date);
  const tomorrow = timesOn(dayKey.format(now + DAY));
  const yesterday = timesOn(dayKey.format(now - DAY));
  timetable = {
    date, today, yesterday,
    previousNight: nightFor(yesterday?.[4], today?.[0]),
    upcomingNight: nightFor(today?.[4], tomorrow?.[0])
  };
  return timetable;
}

function showPrayerDay(times, midnight) {
  if (shownPrayerTimes === times) return;
  shownPrayerTimes = times;
  rows.forEach((entry, index) => {
    const end = index === rows.length - 1 ? midnight : times?.[index + 1];
    showPeriod(entry, times?.[index], end);
  });
}

function setText(element, value) {
  if (element.textContent !== value) element.textContent = value;
}

function render(now = Date.now(), date = dayKey.format(now)) {
  setText(currentTime, (optionValue("clockSeconds") ? clockLabel : timeLabel).format(now));

  const { today, yesterday, previousNight, upcomingNight } = timetableFor(now, date);
  const beforeFajr = now < today?.[0];
  const usePreviousDay = beforeFajr && yesterday;
  showPrayerDay(usePreviousDay ? yesterday : today, usePreviousDay ? previousNight.midnight : upcomingNight.midnight);
  const upcoming = today?.findIndex((time, i) => i !== 1 && time > now) ?? -1;
  const nextTime = upcoming >= 0 ? today[upcoming] : today && upcomingNight.dawn;
  setText(prayerCountdown, nextTime ? countdown(nextTime - now) : "—");

  rows.forEach(entry => setProgress(entry, now));

  const { dawn, third } = beforeFajr ? previousNight : upcomingNight;
  showPeriod(lastThirdRow, third, dawn);
  setProgress(lastThirdRow, now);

  const hasSchedule = Boolean(today && nextTime);
  if (statusLabel.hidden !== hasSchedule) statusLabel.hidden = hasSchedule;
  if (!hasSchedule) setText(statusLabel, today ? "Tomorrow’s timetable is unavailable." : "Today’s timetable is unavailable.");
}

function tick() {
  const now = Date.now();
  const date = dayKey.format(now);
  render(now, date);
  renderCalendar(now, date);
  void refreshSchedule(now, date);
}

function livelyPropertyListener(name, value) {
  if (Object.hasOwn(options, name)) {
    applyWidgetOption(name, value);
    return;
  }
  switch (name) {
    case "positionX":
    case "positionY":
      prayerLayout.restorePosition(name === "positionX" ? "x" : "y", value);
      break;
    case "calendarX":
    case "calendarY":
      calendarLayout.restorePosition(name === "calendarX" ? "x" : "y", value);
      break;
    case "panelScale":
      prayerLayout.restoreScale(value);
      break;
    case "panelWidth":
    case "panelHeight":
      prayerLayout.restoreDimension(name === "panelWidth" ? "width" : "height", value);
      break;
    case "calendarWidth":
    case "calendarHeight":
      calendarLayout.restoreDimension(name === "calendarWidth" ? "width" : "height", value);
      break;
    case "wallpaperImage": {
      const path = value?.replaceAll("\\", "/");
      const file = path?.split("/").pop();
      root.style.backgroundImage = file ? `url(${JSON.stringify(`backgrounds/${encodeURIComponent(file)}`)})` : "none";
      break;
    }
  }
}

tick();
setInterval(tick, 1000);
document.addEventListener("visibilitychange", () => {
  if (document.hidden) endWidgetDrag();
  else tick();
});
