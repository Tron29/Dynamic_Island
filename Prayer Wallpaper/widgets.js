"use strict";

const root = document.documentElement;
const handles = document.querySelector("#resize-handles");
let activeDrag;

function readStored(key, fallback) {
  try {
    return JSON.parse(localStorage.getItem(key)) ?? fallback;
  } catch {
    return fallback;
  }
}

function writeStored(key, value) {
  try {
    localStorage.setItem(key, JSON.stringify(value));
  } catch {
    // Keep settings available for the current session.
  }
}

function positionFromPixels(offset, travel) {
  return travel > 0 ? Math.max(0, Math.min(100, 100 * offset / travel)) : 0;
}

function createWidget(panel, target, key, minimumHeight) {
  const style = target.style;
  const initial = getComputedStyle(target);
  const base = {
    x: parseFloat(initial.getPropertyValue("--position-x")),
    y: parseFloat(initial.getPropertyValue("--position-y")),
    width: 0,
    height: 0,
    scale: parseFloat(initial.getPropertyValue("--panel-scale")) * 100
  };
  let saved = readStored(key, {});
  if (typeof saved !== "object" || Array.isArray(saved)) saved = {};
  const axes = ["x", "y"];
  const dimensions = ["width", "height"];
  const dimensionBase = { width: "widthBase", height: "heightBase" };

  function showPosition(axis, value) {
    style.setProperty("--position-" + axis, value + "%");
  }

  function showDimension(dimension, value) {
    if (value > 0) style.setProperty("--panel-" + dimension, value + "px");
    else style.removeProperty("--panel-" + dimension);
  }

  function restorePosition(axis, value) {
    base[axis] = value;
    const stored = saved[axis];
    if (stored?.base === value && Number.isFinite(stored.position)) {
      showPosition(axis, stored.position);
    } else {
      showPosition(axis, value);
      if (stored) {
        delete saved[axis];
        save();
      }
    }
  }

  function restoreDimension(dimension, value) {
    base[dimension] = value;
    const stored = saved.size;
    if (stored?.[dimension] > 0 && (stored[dimensionBase[dimension]] ?? 0) === value) {
      showDimension(dimension, stored[dimension]);
    } else {
      const minimum = dimension === "height" ? Math.min(220, minimumHeight) : 220;
      showDimension(dimension, value > 0 ? Math.max(minimum, value) : 0);
      if (stored?.[dimension]) {
        delete stored[dimension];
        save();
      }
    }
  }

  function restoreScale(value) {
    base.scale = value;
    style.setProperty("--panel-scale", value / 100);
    if (saved.size && saved.size.base !== value) {
      delete saved.size;
      for (const dimension of dimensions) restoreDimension(dimension, base[dimension]);
      save();
    }
  }

  function save() {
    writeStored(key, saved);
  }

  function place(left, top, bounds, size) {
    const position = {
      x: positionFromPixels(left - bounds.left, bounds.width - size.width),
      y: positionFromPixels(top - bounds.top, bounds.height - size.height)
    };
    for (const axis of axes) {
      showPosition(axis, position[axis]);
      saved[axis] = { base: base[axis], position: position[axis] };
    }
  }

  function update(event) {
    const { x, y, start, bounds, horizontal, vertical, mode } = activeDrag;
    const deltaX = event.clientX - x;
    const deltaY = event.clientY - y;
    const moving = mode === "move";
    const changedX = deltaX !== 0 && (moving || horizontal !== 0);
    const changedY = deltaY !== 0 && (moving || vertical !== 0);
    if (!activeDrag.started && !changedX && !changedY) return;
    activeDrag.started = true;

    if (moving) {
      place(start.left + deltaX, start.top + deltaY, bounds, start);
      return;
    }

    const width = horizontal === 0 ? start.width : Math.min(
      horizontal < 0 ? start.right - bounds.left : bounds.right - start.left,
      Math.max(Math.min(280, start.width), start.width + horizontal * deltaX)
    );
    const height = vertical === 0 ? start.height : Math.min(
      vertical < 0 ? start.bottom - bounds.top : bounds.bottom - start.top,
      Math.max(Math.min(minimumHeight, start.height), start.height + vertical * deltaY)
    );
    showDimension("width", width);
    showDimension("height", height);
    const left = horizontal < 0 ? start.right - width : start.left;
    const top = vertical < 0 ? start.bottom - height : start.top;
    place(left, top, bounds, { width, height });
    saved.size = { base: base.scale, width, height, widthBase: base.width, heightBase: base.height };
  }

  function restore() {
    saved = {};
    for (const axis of axes) restorePosition(axis, base[axis]);
    for (const dimension of dimensions) restoreDimension(dimension, base[dimension]);
    save();
  }

  function layout() {
    const computed = getComputedStyle(target);
    return {
      x: Math.round(parseFloat(computed.getPropertyValue("--position-x"))),
      y: Math.round(parseFloat(computed.getPropertyValue("--position-y"))),
      width: Math.round(parseFloat(style.getPropertyValue("--panel-width"))) || 0,
      height: Math.round(parseFloat(style.getPropertyValue("--panel-height"))) || 0
    };
  }

  for (const axis of axes) {
    if (Number.isFinite(saved[axis]?.position)) showPosition(axis, saved[axis].position);
  }
  for (const dimension of dimensions) {
    if (saved.size?.[dimension] > 0) showDimension(dimension, saved.size[dimension]);
  }

  panel.append(handles.content.cloneNode(true));
  panel.addEventListener("mousedown", event => {
    if (event.button !== 0 || event.target.closest("button, input, a")) return;
    const scroll = event.target.closest(".calendar-agenda");
    if (scroll && event.clientX >= scroll.getBoundingClientRect().left + scroll.clientWidth) return;
    endWidgetDrag();
    document.querySelector("[data-front]")?.removeAttribute("data-front");
    panel.dataset.front = "";
    const edge = event.target.closest("[data-resize]")?.dataset.resize ?? "";
    activeDrag = {
      mode: edge || "move",
      x: event.clientX,
      y: event.clientY,
      start: panel.getBoundingClientRect(),
      bounds: document.body.getBoundingClientRect(),
      horizontal: edge.includes("w") ? -1 : Number(edge.includes("e")),
      vertical: edge.includes("n") ? -1 : Number(edge.includes("s")),
      started: false,
      update,
      save
    };
    root.dataset.dragging = activeDrag.mode;
    event.preventDefault();
  });

  return { restorePosition, restoreDimension, restoreScale, restore, layout };
}

function endWidgetDrag() {
  if (!activeDrag) return;
  if (activeDrag.started) activeDrag.save();
  activeDrag = undefined;
  delete root.dataset.dragging;
}

window.addEventListener("mousemove", event => activeDrag?.update(event));
window.addEventListener("mouseup", event => {
  if (event.button !== 0) return;
  activeDrag?.update(event);
  endWidgetDrag();
});
window.addEventListener("blur", endWidgetDrag);
window.addEventListener("resize", endWidgetDrag);
document.documentElement.addEventListener("mouseleave", endWidgetDrag);

const prayerPanel = document.querySelector("#prayer-widget");
const calendarPanel = document.querySelector("#calendar-widget");
const prayerLayout = createWidget(prayerPanel, root, "istanbul-prayer-dashboard-position-v1", 320);
const calendarLayout = createWidget(calendarPanel, calendarPanel, "sariyer-calendar-position-v1", 180);

const settingKey = "sariyer-widget-options-v1";
const savedOptions = readStored(settingKey, {});
const optionOverrides = savedOptions && typeof savedOptions === "object" ? savedOptions : {};
const options = {
  panelOpacity: { base: 96, target: root, property: "--panel-opacity" },
  calendarOpacity: { base: 96, target: calendarPanel, property: "--panel-opacity" },
  clockSeconds: { base: true },
  calendarShowFinished: { base: true },
  panelBackground: { base: "#0F1012", target: prayerPanel, property: "--panel-surface" },
  panelText: { base: "#FAFAFA", target: prayerPanel, property: "--panel-ink" },
  accent: { base: "#9EE6A8", target: prayerPanel, property: "--accent" },
  calendarBackground: { base: "#0F1012", target: calendarPanel, property: "--panel-surface" },
  calendarText: { base: "#FAFAFA", target: calendarPanel, property: "--panel-ink" },
  calendarAccent: { base: "#9EE6A8", target: calendarPanel, property: "--accent" }
};

function optionValue(name) {
  return optionOverrides[name]?.value ?? options[name].base;
}

function paintOption(name) {
  const { target, property } = options[name];
  const value = optionValue(name);
  target?.style.setProperty(property, typeof value === "number" ? value / 100 : value);
}

function applyWidgetOption(name, value) {
  options[name].base = value;
  if (optionOverrides[name] && optionOverrides[name].base !== value) {
    delete optionOverrides[name];
    writeStored(settingKey, optionOverrides);
  }
  paintOption(name);
}

function changeWidgetOption(name, value) {
  changeWidgetOptions({ [name]: value });
}

function changeWidgetOptions(changes) {
  for (const [name, value] of Object.entries(changes)) {
    optionOverrides[name] = { base: options[name].base, value };
    paintOption(name);
  }
  writeStored(settingKey, optionOverrides);
}

for (const name of Object.keys(options)) paintOption(name);

function widgetEditorValues() {
  const prayer = prayerLayout.layout();
  const calendar = calendarLayout.layout();
  return {
    positionX: prayer.x, positionY: prayer.y, panelWidth: prayer.width, panelHeight: prayer.height,
    calendarX: calendar.x, calendarY: calendar.y, calendarWidth: calendar.width, calendarHeight: calendar.height,
    ...Object.fromEntries(Object.keys(options).map(name => [name, optionValue(name)]))
  };
}

const widgetMenu = document.querySelector("#widget-options");
const widgetMenuTitle = document.querySelector("#widget-options-title");
const widgetOpacity = document.querySelector("#widget-opacity");
const widgetToggle = document.querySelector("#widget-toggle");
const widgetToggleLabel = document.querySelector("#widget-toggle-label");
const widgetCalendarSettings = document.querySelector("#widget-calendar-settings");
let menuWidget;

function openWidgetOptions(event, widget) {
  event.preventDefault();
  endWidgetDrag();
  menuWidget = widget;
  widgetMenuTitle.textContent = widget.title;
  widgetOpacity.value = optionValue(widget.opacity);
  widgetToggle.checked = optionValue(widget.toggle);
  widgetToggleLabel.textContent = widget.toggleLabel;
  widgetCalendarSettings.hidden = widget.layout !== calendarLayout;
  widgetMenu.hidden = false;
  const { width, height } = widgetMenu.getBoundingClientRect();
  const bounds = event.currentTarget.getBoundingClientRect();
  const x = event.clientX || bounds.left + 12;
  const y = event.clientY || bounds.top + 12;
  widgetMenu.style.left = Math.max(4, Math.min(x, window.innerWidth - width - 4)) + "px";
  widgetMenu.style.top = Math.max(4, Math.min(y, window.innerHeight - height - 4)) + "px";
}

function closeWidgetOptions() {
  widgetMenu.hidden = true;
}

const widgets = [
  {
    panel: prayerPanel, layout: prayerLayout, title: "Prayer settings", opacity: "panelOpacity",
    toggle: "clockSeconds", toggleLabel: "Show clock seconds",
    palette: { background: "panelBackground", text: "panelText", accent: "accent" }
  },
  {
    panel: calendarPanel, layout: calendarLayout, title: "Calendar settings", opacity: "calendarOpacity",
    toggle: "calendarShowFinished", toggleLabel: "Show finished events",
    palette: { background: "calendarBackground", text: "calendarText", accent: "calendarAccent" }
  }
];

for (const widget of widgets) {
  widget.panel.addEventListener("contextmenu", event => openWidgetOptions(event, widget));
  widget.panel.querySelector(".widget-settings-trigger").addEventListener("click", event => openWidgetOptions(event, widget));
}

document.addEventListener("mousedown", event => {
  if (!widgetMenu.contains(event.target)) closeWidgetOptions();
});
document.addEventListener("keydown", event => {
  if (event.key === "Escape") closeWidgetOptions();
});
widgetOpacity.addEventListener("input", () => changeWidgetOption(menuWidget.opacity, Number(widgetOpacity.value)));
widgetToggle.addEventListener("change", () => changeWidgetOption(menuWidget.toggle, widgetToggle.checked));
document.querySelector("#widget-reset").addEventListener("click", () => {
  menuWidget.layout.restore();
  closeWidgetOptions();
});
widgetCalendarSettings.addEventListener("click", () => {
  closeWidgetOptions();
  document.querySelector("#calendar-setup").showModal();
});

const paletteDialog = document.querySelector("#widget-palette");
const palettePresets = document.querySelector("#palette-presets");
const paletteInputs = [...paletteDialog.querySelectorAll("[data-palette-color]")];
const paletteScopes = [...paletteDialog.querySelectorAll('[name="palette-scope"]')];
const palettes = [
  { label: "Midnight", background: "#0F1012", text: "#FAFAFA", accent: "#9EE6A8" },
  { label: "Ocean", background: "#101923", text: "#F0F7FF", accent: "#8AD3FF" },
  { label: "Plum", background: "#1C1422", text: "#FAF2FF", accent: "#D5B0FF" },
  { label: "Sand", background: "#211A13", text: "#FFF6E8", accent: "#FFD08C" }
];

function paletteTargets() {
  return paletteScopes[1].checked ? widgets : [menuWidget];
}

function refreshPaletteControls() {
  for (const input of paletteInputs) input.value = optionValue(menuWidget.palette[input.dataset.paletteColor]);
  for (const [i, button] of [...palettePresets.children].entries()) {
    const matches = paletteTargets().every(widget => Object.entries(widget.palette).every(
      ([color, name]) => optionValue(name).toLowerCase() === palettes[i][color].toLowerCase()
    ));
    button.setAttribute("aria-pressed", String(matches));
  }
}

function setPaletteColors(colors) {
  const changes = {};
  for (const widget of paletteTargets()) {
    for (const [color, value] of Object.entries(colors)) changes[widget.palette[color]] = value;
  }
  changeWidgetOptions(changes);
  refreshPaletteControls();
}

for (const { label, ...colors } of palettes) {
  const button = document.createElement("button");
  button.type = "button";
  button.className = "palette-preset";
  button.textContent = label;
  button.style.setProperty("--preview-accent", colors.accent);
  button.addEventListener("click", () => setPaletteColors(colors));
  palettePresets.append(button);
}
for (const input of paletteInputs) {
  input.addEventListener("input", () => setPaletteColors({ [input.dataset.paletteColor]: input.value }));
}
for (const scope of paletteScopes) scope.addEventListener("change", refreshPaletteControls);
document.querySelector("#widget-palette-settings").addEventListener("click", () => {
  closeWidgetOptions();
  paletteScopes[0].checked = true;
  refreshPaletteControls();
  paletteDialog.showModal();
});
