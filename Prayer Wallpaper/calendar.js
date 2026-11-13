"use strict";

const calendarDay = document.querySelector("#calendar-day");
const calendarDate = document.querySelector("#calendar-date");
const calendarEvents = document.querySelector("#calendar-events");
const calendarStatus = document.querySelector("#calendar-status");
const calendarAgenda = document.querySelector("#calendar-agenda");
const calendarPicker = document.querySelector("#calendar-picker");
const calendarDateButton = document.querySelector("#calendar-date-button");
const calendarToday = document.querySelector("#calendar-today");
const monthHeading = document.querySelector("#calendar-month");
const monthDays = document.querySelector("#calendar-days");
const previousMonth = document.querySelector("#calendar-previous");
const nextMonth = document.querySelector("#calendar-next");
const calendarWeekday = new Intl.DateTimeFormat("en-GB", { timeZone: "Europe/Istanbul", weekday: "long" });
const calendarShortDate = new Intl.DateTimeFormat("en-GB", { timeZone: "Europe/Istanbul", day: "numeric", month: "short" });
const calendarFullDate = new Intl.DateTimeFormat("en-GB", { timeZone: "UTC", dateStyle: "full" });
const calendarMonth = new Intl.DateTimeFormat("en-GB", { timeZone: "UTC", month: "long", year: "numeric" });
let calendarSnapshot = null;
let calendarRenderedSnapshot;
let calendarRenderedDay;
let calendarTodayKey;
let calendarSelectedDate = null;
let pickerMonth;
let calendarRows = [];
let loadingCalendar = false;

function receiveCalendarData(snapshot) {
  if (snapshot?.updated !== calendarSnapshot?.updated) calendarSnapshot = snapshot;
}

function loadCalendarData() {
  if (loadingCalendar) return;
  loadingCalendar = true;
  const script = document.createElement("script");
  script.src = "calendar-data.js?at=" + Date.now();
  const finished = () => {
    script.remove();
    loadingCalendar = false;
  };
  script.addEventListener("load", finished, { once: true });
  script.addEventListener("error", finished, { once: true });
  document.head.append(script);
}

function shiftMonth(month, offset) {
  const date = new Date(month + "-01T00:00:00Z");
  date.setUTCMonth(date.getUTCMonth() + offset);
  return date.toISOString().slice(0, 7);
}

function renderMonthPicker() {
  const todayMonth = calendarTodayKey.slice(0, 7);
  const firstMonth = calendarSnapshot?.firstDate?.slice(0, 7) ?? todayMonth;
  const lastMonth = calendarSnapshot?.lastDate?.slice(0, 7) ?? todayMonth;
  if (pickerMonth < firstMonth) pickerMonth = firstMonth;
  if (pickerMonth > lastMonth) pickerMonth = lastMonth;

  const first = new Date(pickerMonth + "-01T00:00:00Z");
  const next = new Date(shiftMonth(pickerMonth, 1) + "-01T00:00:00Z");
  const length = (next - first) / DAY;
  const selected = calendarSelectedDate ?? calendarTodayKey;
  const focusedDate = monthDays.contains(document.activeElement) ? document.activeElement.dataset.date : undefined;
  const cells = document.createDocumentFragment();
  monthHeading.textContent = calendarMonth.format(first);
  previousMonth.disabled = pickerMonth <= firstMonth;
  nextMonth.disabled = pickerMonth >= lastMonth;

  const leading = (first.getUTCDay() + 6) % 7;
  for (let i = 0; i < leading; i++) cells.append(document.createElement("span"));
  for (let i = 0; i < length; i++) {
    const instant = new Date(+first + i * DAY);
    const date = instant.toISOString().slice(0, 10);
    const button = document.createElement("button");
    const hasEvents = Boolean(calendarSnapshot?.dates?.[date]?.length);
    button.type = "button";
    button.className = "month-day";
    button.dataset.date = date;
    button.textContent = i + 1;
    button.setAttribute("aria-label", calendarFullDate.format(instant) + (hasEvents ? ", with events" : ""));
    button.setAttribute("aria-pressed", String(date === selected));
    button.toggleAttribute("data-events", hasEvents);
    if (date === calendarTodayKey) button.setAttribute("aria-current", "date");
    cells.append(button);
  }
  monthDays.replaceChildren(cells);
  if (focusedDate) monthDays.querySelector('[data-date="' + focusedDate + '"]')?.focus({ preventScroll: true });
}

function showMonthPicker(open, restoreFocus = false) {
  calendarPicker.hidden = !open;
  calendarAgenda.hidden = open;
  calendarDateButton.setAttribute("aria-expanded", String(open));
  calendarToday.hidden = !open && !calendarSelectedDate;
  if (open) {
    pickerMonth = (calendarSelectedDate ?? calendarTodayKey).slice(0, 7);
    renderMonthPicker();
    calendarPicker.scrollTop = 0;
    monthDays.querySelector('[aria-pressed="true"]')?.focus({ preventScroll: true });
  } else if (restoreFocus) {
    calendarDateButton.focus({ preventScroll: true });
  }
}

function selectCalendarDay(date) {
  const now = Date.now();
  const today = dayKey.format(now);
  calendarSelectedDate = date === today ? null : date;
  showMonthPicker(false, true);
  renderCalendar(now, today);
}

calendarDateButton.addEventListener("click", () => showMonthPicker(calendarPicker.hidden));
calendarToday.addEventListener("click", () => selectCalendarDay(null));
previousMonth.addEventListener("click", () => {
  pickerMonth = shiftMonth(pickerMonth, -1);
  renderMonthPicker();
});
nextMonth.addEventListener("click", () => {
  pickerMonth = shiftMonth(pickerMonth, 1);
  renderMonthPicker();
});
monthDays.addEventListener("click", event => {
  const date = event.target.closest("button")?.dataset.date;
  if (date) selectCalendarDay(date);
});
calendarPanel.addEventListener("keydown", event => {
  if (event.key === "Escape" && !calendarPicker.hidden) showMonthPicker(false, true);
});

function createCalendarRow(event, dayStart) {
  const row = document.createElement("div");
  row.className = "calendar-event";
  const title = document.createElement("span");
  title.className = "calendar-event-name";
  title.textContent = event.title;
  const time = document.createElement("span");
  time.className = "calendar-event-time";
  if (event.allDay) time.textContent = "All day";
  else if (event.start < dayStart && event.end >= dayStart + DAY) time.textContent = "Ongoing";
  else if (event.start < dayStart) time.textContent = "Until " + timeLabel.format(event.end);
  else if (event.end >= dayStart + DAY) time.textContent = "From " + timeLabel.format(event.start);
  else if (event.start === event.end) time.textContent = timeLabel.format(event.start);
  else time.textContent = timeLabel.format(event.start) + "–" + timeLabel.format(event.end);
  row.append(title, time);
  return { event, row };
}

function renderCalendar(now, date) {
  const refreshPicker = !calendarPicker.hidden &&
    (calendarTodayKey !== date || calendarRenderedSnapshot !== calendarSnapshot);
  calendarTodayKey = date;
  const selected = calendarSelectedDate ?? date;
  const events = calendarSnapshot?.dates?.[selected];
  if (calendarRenderedDay !== selected || calendarRenderedSnapshot !== calendarSnapshot) {
    if (calendarRenderedDay !== selected) {
      const instant = new Date(selected + "T00:00:00Z");
      calendarDay.textContent = calendarWeekday.format(instant);
      calendarDate.textContent = calendarShortDate.format(instant);
      calendarDate.dateTime = selected;
      calendarDateButton.setAttribute("aria-label", "Choose a date, " + calendarFullDate.format(instant));
      calendarAgenda.scrollTop = 0;
    }
    calendarRenderedDay = selected;
    calendarRenderedSnapshot = calendarSnapshot;
    const dayStart = Date.parse(selected + "T00:00:00+03:00");
    calendarRows = (events ?? []).map(event => createCalendarRow(event, dayStart));
    calendarEvents.replaceChildren(...calendarRows.map(entry => entry.row));
  }
  if (refreshPicker) renderMonthPicker();

  let visible = 0;
  const showFinished = selected !== date || optionValue("calendarShowFinished");
  for (const { event, row } of calendarRows) {
    const hide = !event.allDay && !showFinished && event.end <= now;
    const current = !event.allDay && now >= event.start && now < event.end;
    if (row.hidden !== hide) row.hidden = hide;
    if (row.hasAttribute("data-current") !== current) row.toggleAttribute("data-current", current);
    if (!hide) visible++;
  }

  if (calendarStatus.hidden !== (visible > 0)) calendarStatus.hidden = visible > 0;
  if (visible === 0) {
    const status = !calendarSnapshot ? "Open widget settings to connect Google Calendar." :
      !events ? "Calendar data is unavailable for this date." :
      events.length ? "No events left today." :
      selected === date ? "No events today." : "No events on this date.";
    if (calendarStatus.textContent !== status) calendarStatus.textContent = status;
  }
}

loadCalendarData();
setInterval(loadCalendarData, 60_000);
