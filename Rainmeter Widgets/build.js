"use strict";

const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");

const destination = process.argv[2];
if (!destination) throw new Error("Provide the installed SariyerWidgets skin folder.");
const resources = path.join(destination, "@Resources");
fs.mkdirSync(resources, { recursive: true });
writeIni(path.join(resources, "Widget.lua"), fs.readFileSync(path.join(__dirname, "Widget.lua"), "utf8"));
const scheduleSource = fs.readFileSync(path.join(__dirname, "..", "Prayer Wallpaper", "schedule.js"), "utf8");
const schedule = vm.runInNewContext(scheduleSource + "\nISTANBUL_SCHEDULE");
const scheduleLua = Object.entries(schedule).map(([date, times]) =>
  '["' + date + '"]={' + times.map(time => '"' + time + '"').join(",") + "}"
);
fs.writeFileSync(path.join(resources, "Schedule.lua"), "return {" + scheduleLua.join(",\n") + "}\n");

const palettes = ["Midnight", "Ocean", "Plum", "Sand"];
function section(name, values) {
  return "[" + name + "]\n" + Object.entries(values).map(([key, value]) => key + "=" + value).join("\n") + "\n\n";
}
function writeIni(file, value) {
  fs.writeFileSync(file, Buffer.concat([Buffer.from([255, 254]), Buffer.from(value, "utf16le")]));
}
function text(name, x, y, width, size = 12, extra = {}) {
  const values = {
    Meter: "String", MeterStyle: "TextStyle", X: "(Round(" + x + "*#S#))", Y: "(Round(" + y + "*#S#))",
    W: "(Round(" + width + "*#S#))", H: "(Round(26*#S#))",
    FontSize: "(Round(" + size + "*#S#*4/3)*3/4)", Text: "", ...extra
  };
  if (width === null) delete values.W;
  return section(name, values);
}
function shape(name, x, y, width, height, radius, color, extra = {}) {
  return section(name, {
    Meter: "Shape", X: "(" + x + "*#S#)", Y: "(" + y + "*#S#)",
    Shape: "Rectangle 0,0,(" + width + "*#S#),(" + height + "*#S#),(" + radius + "*#S#)" +
      " | Fill Color " + color + " | StrokeWidth 0",
    DynamicVariables: 1, UpdateDivider: -1, ...extra
  });
}

for (const kind of ["Prayer"]) {
  const folder = path.join(destination, kind);
  fs.mkdirSync(folder, { recursive: true });
  const settings = path.join(resources, kind + ".inc");
  if (!fs.existsSync(settings)) {
    fs.writeFileSync(settings, "[Variables]\nS=" + (kind === "Prayer" ? "1.17" : "1.25") +
      "\nBackground=15,16,18\nText=250,250,250\nMuted=169,171,176\nAccent=158,230,168\nOpacity=" + (kind === "Prayer" ? "209" : "245") + "\n" +
      "ShowSeconds=1\nShowFinished=1\nDemoMode=0\nDemoSeconds=20\n");
  }
  const header = {
    Update: 1000, AccurateText: 1, DynamicWindowSize: kind === "Prayer" ? 0 : 1, Draggable: kind === "Prayer" ? 0 : 1,
    OnRefreshAction: kind === "Prayer"
      ? '[!CommandMeasure Logic "Update()"][!CommandMeasure Logic "CenterIsland()"]'
      : '[!CommandMeasure Logic "Update()"]',
    ContextTitle: "Widget settings", ContextAction: '[!EditSkin]',
    ContextTitle2: "Larger", ContextAction2: '[!CommandMeasure Logic "Resize(0.05)"]',
    ContextTitle3: "Smaller", ContextAction3: '[!CommandMeasure Logic "Resize(-0.05)"]',
    ContextTitle4: kind === "Prayer" ? "Center beneath camera" : "Show / hide finished events",
    ContextAction4: kind === "Prayer" ? '[!CommandMeasure Logic "CenterIsland()"]' : '[!CommandMeasure Logic "ToggleDetail()"]'
  };
  let index = 5;
  for (const both of [false, true]) {
    for (const palette of palettes) {
      header["ContextTitle" + index] = palette + (both ? " - both widgets" : " - this widget");
      header["ContextAction" + index] = '[!CommandMeasure Logic "Palette(\'' + palette + '\',' + String(both) + ')"]';
      index++;
    }
  }
  header["ContextTitle" + index] = "Edit colors and size";
  header["ContextAction" + index] = '["notepad.exe" "#@#' + kind + '.inc"]';
  if (kind === "Calendar") {
    index++;
    header["ContextTitle" + index] = "Connect Google Calendar";
    header["ContextAction" + index] = '["wscript.exe" "//B" "//NoLogo" "#@#ConnectCalendar.vbs"]';
  }
  let skin = section("Rainmeter", header) +
    section("Metadata", { Name: "Sariyer " + kind, Author: "Islam", Information: kind === "Prayer" ? "Pinned at the top center. Right-click for settings." : "Drag to move. Right-click for settings." }) +
    section("Variables", { Kind: kind, "@Include": "#@#" + kind + ".inc" });
  if (kind === "Prayer") {
    // The native prayer skin now supplies data only. No legacy pill meters exist.
    skin = skin.replace("Kind=Prayer\n", "Kind=Prayer\nHeadless=1\n");
    skin +=
      section("Logic", { Measure: "Script", ScriptFile: "#@#Widget.lua" }) +
      section("DataCanvas", { Meter: "Image", W: 1, H: 1, SolidColor: "0,0,0,0" });
    writeIni(path.join(folder, kind + ".ini"), skin);
    continue;
  }
  if (kind === "Prayer") {
    skin += section("Animator", {
      Measure: "Plugin", Plugin: "ActionTimer", UpdateDivider: -1, IgnoreWarnings: 1,
      ActionList1: "Repeat Frame, 8, 180",
      ActionList2: "Repeat Frame, 8, 150",
      Frame: '[!CommandMeasure Logic "AnimatePrayer()"]'
    });
  }
  skin +=
    section("Logic", { Measure: "Script", ScriptFile: "#@#Widget.lua" }) +
    section("TextStyle", { FontFace: "Segoe UI", FontColor: "#Text#", AntiAlias: 1, ClipString: 1, DynamicVariables: 1, UpdateDivider: -1 });
  if (kind === "Prayer") {
    skin += section("Canvas", {
      Meter: "Image", X: 0, Y: 0, W: "(Round(480*#S#))", H: "(Round(50*#S#))",
      SolidColor: "0,0,0,0", UpdateDivider: -1
    }) +
      shape("Panel", 0, 0, 400, 42, 21, "0,0,0,255", { LeftMouseUpAction: '[!CommandMeasure Logic "OpenPrayerPanel()"]' }) +
      shape("PrayerNameMask", 10, 4, 94, 34, 0, "255,255,255,255") +
      text("CurrentPrayer", 0, 0, null, 10.5, {
        H: "(22*#S#)", Container: "PrayerNameMask", ClipString: 0, StringStyle: "Bold", FontColor: "0,0,0,0"
      }) +
      ["Previous", "Incoming"].map(layer =>
        text(layer + "PrayerBlur", 206, 6, 120, 10.5, {
          H: "(22*#S#)", Container: "PrayerNameMask", ClipString: 0,
          StringStyle: "Bold", FontColor: "#Accent#", Hidden: 1,
          InlineSetting: "Shadow | (-200*#S#) | 0 | 0 | #Accent#,0",
          InlinePattern: ".*"
        }) + text(layer + "PrayerSharp", 6, 6, 120, 10.5, {
          H: "(22*#S#)", Container: "PrayerNameMask", ClipString: 0,
          StringStyle: "Bold", FontColor: "#Accent#", Hidden: layer === "Previous" ? 1 : 0
        })
      ).join("") +
      text("PrayerStart", 148, 11, 46, 10.5, { H: "(22*#S#)", StringAlign: "Right" }) +
      shape("PrayerTrack", 164, 19, 150, 4, 2, "40,43,48") +
      shape("PrayerClip", 164, 19, 0, 4, 2, "255,255,255,255") +
      section("PrayerProgress", {
        Meter: "Shape", X: 0, Y: 0, Container: "PrayerClip",
        Shape: "Rectangle 0,0,(150*#S#),(4*#S#),(2*#S#) | Fill LinearGradient ProgressGradient | StrokeWidth 0",
        ProgressGradient: "180 | 77,229,77 ; 0.0 | 229,229,77 ; 0.5 | 229,77,77 ; 1.0",
        DynamicVariables: 1, UpdateDivider: -1
      }) +
      text("PrayerEnd", 384, 11, 54, 10.5, { H: "(22*#S#)", StringAlign: "Right" });
  } else {
    skin += shape("Panel", 0, 0, 440, 463, 22, "#Background#,#Opacity#") +
      text("Title", 34, 34, 180, 17, { StringStyle: "Bold" }) +
      text("Date", 406, 40, 106, 11, {
      StringAlign: "Right", FontColor: "#Muted#", LeftMouseUpAction: '[!CommandMeasure Logic "TogglePicker()"]',
      ToolTipText: "Choose a date"
    }) + text("Today", 246, 40, 47, 10, {
      Text: "Today", FontColor: "#Accent#", LeftMouseUpAction: '[!CommandMeasure Logic "Today()"]'
    }) + shape("Divider", 34, 79, 372, 1, 0, "55,58,62") +
      section("ScrollArea", {
        Meter: "Image", X: "(32*#S#)", Y: "(90*#S#)", W: "(375*#S#)", H: "(338*#S#)", SolidColor: "0,0,0,1",
        MouseScrollUpAction: '[!CommandMeasure Logic "Scroll(-1)"]',
        MouseScrollDownAction: '[!CommandMeasure Logic "Scroll(1)"]'
      }) + text("Status", 34, 102, 370, 11, { FontColor: "#Muted#" });
    for (let i = 0; i < 8; i++) {
      const y = 94 + i * 39;
      skin += shape("EventBg" + i, 34, y, 372, 34, 7, "25,27,30", { Group: "Agenda", LeftMouseUpAction: '[!CommandMeasure Logic "OpenCalendarEvent(' + i + ')"]', ToolTipText: "Open in Google Calendar" }) +
        text("EventName" + i, 44, y + 7, 240, 11, { Group: "Agenda", LeftMouseUpAction: '[!CommandMeasure Logic "OpenCalendarEvent(' + i + ')"]', ToolTipText: "Open in Google Calendar" }) +
        text("EventTime" + i, 395, y + 8, 100, 10, { StringAlign: "Right", FontColor: "#Muted#", Group: "Agenda", LeftMouseUpAction: '[!CommandMeasure Logic "OpenCalendarEvent(' + i + ')"]', ToolTipText: "Open in Google Calendar" });
    }
    skin += text("Month", 34, 98, 260, 14, { Group: "Picker", Hidden: 1 }) +
      text("Previous", 340, 98, 30, 16, { Text: "‹", Group: "Picker", Hidden: 1, LeftMouseUpAction: '[!CommandMeasure Logic "ChangeMonth(-1)"]' }) +
      text("Next", 378, 98, 30, 16, { Text: "›", Group: "Picker", Hidden: 1, LeftMouseUpAction: '[!CommandMeasure Logic "ChangeMonth(1)"]' });
    for (let i = 0; i < 7; i++) {
      skin += text("Weekday" + i, 61 + i * 53, 142, 48, 9, {
        StringAlign: "Center", Text: ["MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"][i],
        Group: "Picker", Hidden: 1, FontColor: "#Muted#"
      });
    }
    for (let i = 0; i < 42; i++) {
      const x = 44 + (i % 7) * 53;
      const y = 172 + Math.floor(i / 7) * 39;
      skin += shape("DayBg" + i, x, y, 34, 34, 17, "0,0,0,0", { Group: "Picker", Hidden: 1 }) +
        text("Day" + i, x + 17, y + 6, 34, 11, {
          StringAlign: "Center", Group: "Picker", Hidden: 1,
          LeftMouseUpAction: '[!CommandMeasure Logic "ChooseDay(' + i + ')"]'
        });
    }
  }
  writeIni(path.join(folder, kind + ".ini"), skin);
}
