local daySeconds = 86400
local weekdays = {"Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"}
local months = {"January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"}
local calendar = {}
local selected = nil
local picker = false
local offset = 0
local lastRead = 0
local kind, resources, schedule, monthYear, monthNumber
local cells = {}
local changed = {}
local prayerPeriods, prayerDate
local demoPeriods = {}
local frame = 0
local dirty = false
local islandWidth, nameSpan, nameTarget, measureAfter
local nameVelocity = 0
local shownPeriod
local demoStarted
local lastPrayerRead = 0
local prayerSnapshotUpdated
local displayProgress, progressRate, progressCorrection
local displayedName, nameTransition
local homeIntro

local function smooth(value)
  value = math.max(0, math.min(1, value))
  return value * value * (3 - 2 * value)
end

local function option(meter, key, value)
  local id = meter .. ":" .. key
  value = tostring(value)
  if changed[id] ~= value then
    SKIN:Bang("!SetOption", meter, key, value)
    changed[id] = value
    dirty = true
  end
end

local function text(meter, value)
  option(meter, "Text", value or "—")
end

local function hidden(meter, hide)
  option(meter, "Hidden", hide and "1" or "0")
end

local function istanbul(instant)
  return os.date("!*t", instant + 10800)
end

local function dateKey(instant)
  return os.date("!%Y-%m-%d", instant + 10800)
end

local function clock(instant)
  return os.date("!%H:%M", instant + 10800)
end

local function startOfDay(instant)
  local t = istanbul(instant)
  return instant - t.hour * 3600 - t.min * 60 - t.sec
end

local function midnightFor(year, month, day)
  -- os.time uses Windows local time. The UTC difference makes this independent of its time zone.
  local localInstant = os.time({year=year, month=month, day=day, hour=12})
  local actual = istanbul(localInstant)
  return localInstant - actual.hour * 3600 - actual.min * 60 - actual.sec
end

local function dayTimes(instant)
  local source = schedule[dateKey(instant)]
  if not source then return nil end
  local start = startOfDay(instant)
  local result = {}
  for i, value in ipairs(source) do
    local hour, minute = value:match("(%d+):(%d+)")
    result[i] = start + tonumber(hour) * 3600 + tonumber(minute) * 60
  end
  return result
end

function Initialize()
  kind = SKIN:GetVariable("Kind")
  resources = SKIN:GetVariable("@")
  if kind == "Prayer" then
    demoStarted = os.time()
    schedule = dofile(resources .. "Schedule.lua")
    local today = dayTimes(os.time())
    local tomorrow = dayTimes(os.time() + daySeconds)
    local names = {"Fajr", "Sunrise", "Dhuhr", "Asr", "Maghrib", "Isha"}
    if today and tomorrow then
      for i, start in ipairs(today) do
        if i ~= 2 then
          local finish = i == 6 and (today[5] + tomorrow[1]) / 2 or today[i + 1]
          demoPeriods[#demoPeriods + 1] = {name=names[i], start=start, finish=finish}
        end
      end
    end
  end
end

local function realPrayerPeriod(now)
  local date = dateKey(now)
  if prayerDate ~= date then
    prayerDate = date
    prayerPeriods = {}
    local names = {"Fajr", "Sunrise", "Dhuhr", "Asr", "Maghrib", "Isha"}
    for offset = -1, 1 do
      local day = now + offset * daySeconds
      local times = dayTimes(day)
      local nextDay = dayTimes(day + daySeconds)
      if times then
        for i, start in ipairs(times) do
          local finish = times[i + 1]
          if i == 6 and nextDay then finish = (times[5] + nextDay[1]) / 2 end
          if i ~= 2 and finish then
            prayerPeriods[#prayerPeriods + 1] = {name=names[i], start=start, finish=finish}
          end
        end
      end
    end
  end
  for _, candidate in ipairs(prayerPeriods) do
    if now < candidate.finish then
      return candidate
    end
  end
end

local function animatePrayerLayout()
  local scale = tonumber(SKIN:GetVariable("S"))
  if measureAfter and frame >= measureAfter then
    local measured = SKIN:GetMeter("CurrentPrayer"):GetW() + 4 * scale
    nameSpan = nameSpan or measured
    nameTarget = measured
    measureAfter = nil
  end
  if not nameSpan then return end

  -- A damped spring retains its velocity when a new name changes the target.
  local acceleration = 95 * (nameTarget - nameSpan) - 12 * nameVelocity
  nameVelocity = nameVelocity + acceleration * 0.008
  nameSpan = nameSpan + nameVelocity * 0.008
  if math.abs(nameTarget - nameSpan) < 0.05 and math.abs(nameVelocity) < 0.2 then
    nameSpan = nameTarget
    nameVelocity = 0
  end
  local squash = math.max(-3 * scale, math.min(4 * scale, -nameVelocity * 0.02))
  local height = 42 * scale + squash
  local textY = math.floor((height - 22 * scale) / 2 + 0.5)
  local barY = math.floor(height / 2 - 2 * scale + 0.5)

  local nameRight = 16 * scale + nameSpan
  local startX = nameRight + math.floor(8 * scale + 0.5)
  local startRight = startX + math.floor(46 * scale + 0.5)
  local trackX = startRight + math.floor(16 * scale + 0.5)
  local trackRight = trackX + math.floor(150 * scale + 0.5)
  local endX = trackRight + math.floor(16 * scale + 0.5)
  local endRight = endX + math.floor(54 * scale + 0.5)
  islandWidth = endRight + math.floor(16 * scale + 0.5)
  local offset = (480 * scale - islandWidth) / 2
  -- Padding lets the Gaussian dissolve extend beyond the glyphs without clipping.
  option("PrayerNameMask", "X", math.floor(offset + 10 * scale + 0.5))
  option("PrayerNameMask", "Shape", string.format(
    "Rectangle 0,0,%d,(34*#S#) | Fill Color 255,255,255,255 | StrokeWidth 0", math.max(1, math.floor(nameSpan + 12 * scale + 0.5))))
  option("PrayerNameMask", "Y", textY - math.floor(6 * scale + 0.5))
  option("PrayerStart", "X", math.floor(offset + startRight + 0.5))
  option("PrayerStart", "Y", textY)
  option("PrayerTrack", "X", math.floor(offset + trackX + 0.5))
  option("PrayerTrack", "Y", barY)
  option("PrayerClip", "X", math.floor(offset + trackX + 0.5))
  option("PrayerClip", "Y", barY)
  option("PrayerEnd", "X", math.floor(offset + endRight + 0.5))
  option("PrayerEnd", "Y", textY)
  option("Panel", "Shape", string.format(
    "Rectangle %.3f,0,%.3f,%.3f,%.3f | Fill Color 0,0,0,255 | StrokeWidth 0",
    offset, islandWidth, height, height / 2))
end

local function nameLayer(layer, opacity, blur)
  local scale = tonumber(SKIN:GetVariable("S"))
  local accent = SKIN:GetVariable("Accent")
  local sharp = (1 - blur / 3) ^ 2
  local sharpAlpha = math.floor(255 * opacity * sharp + 0.5)
  local blurAlpha = math.floor(255 * opacity * (1 - sharp) + 0.5)
  hidden(layer .. "PrayerSharp", sharpAlpha == 0)
  hidden(layer .. "PrayerBlur", blurAlpha == 0)
  option(layer .. "PrayerSharp", "FontColor", accent .. "," .. sharpAlpha)
  -- Put the source glyphs outside the container and offset only their Gaussian
  -- shadow back into view. The visible result is true blur, without a sharp core.
  option(layer .. "PrayerBlur", "InlineSetting", string.format(
    "Shadow | %.3f | 0 | %.3f | %s,%d", -200 * scale, blur * scale, accent, blurAlpha))
end

local function animatePrayerName()
  if not nameTransition then return end
  nameTransition = math.min(1, nameTransition + 0.016 / 0.85)
  local outgoing = smooth(nameTransition / 0.60)
  local incoming = smooth((nameTransition - 0.16) / 0.84)
  nameLayer("Previous", 1 - outgoing, 3 * outgoing)
  nameLayer("Incoming", incoming, 3 * (1 - incoming))
  if nameTransition == 1 then nameTransition = nil end
end

local function setProgressWidth(progress)
  local width = 150 * tonumber(SKIN:GetVariable("S")) * progress
  option("PrayerClip", "Shape", string.format(
    "Rectangle 0,0,%.3f,(4*#S#),(2*#S#) | Fill Color 255,255,255,255 | StrokeWidth 0", width))
end

function AnimatePrayer()
  if homeIntro then
    homeIntro = math.min(1, homeIntro + 0.016 / 0.30)
    local scale = tonumber(SKIN:GetVariable("S"))
    local screenWidth = tonumber(SKIN:GetVariable("SCREENAREAWIDTH"))
    local left = tonumber(SKIN:GetVariable("SCREENAREAX")) + (screenWidth - 480 * scale) / 2
    local top = tonumber(SKIN:GetVariable("SCREENAREAY"))
    local eased = 1 - (1 - homeIntro) ^ 3
    SKIN:Bang("!Move", math.floor(left), math.floor(top - 50 * scale * (1 - eased)))
    if homeIntro == 1 then homeIntro = nil end
  end
  frame = frame + 1
  dirty = false
  animatePrayerLayout()
  animatePrayerName()
  local layoutChanged = dirty
  if SKIN:GetVariable("DemoMode") == "1" and displayProgress then
    local predicted = displayProgress + progressRate * 0.016 + progressCorrection * 0.1
    displayProgress = math.max(displayProgress, math.min(1, predicted))
    progressCorrection = progressCorrection * 0.9
    setProgressWidth(displayProgress)
  end
  if dirty then
    if layoutChanged then
      SKIN:Bang("!UpdateMeter", "*")
    else
      SKIN:Bang("!UpdateMeter", "PrayerClip")
      SKIN:Bang("!UpdateMeter", "PrayerProgress")
    end
    SKIN:Bang("!Redraw")
  end
end

function OpenPrayerPanel()
  local file = io.open(resources .. "PanelRequest.txt", "w")
  if file then file:write(tostring(os.time())); file:close() end
end

local function prayer(now)
  if islandWidth then
    local file = io.open(resources .. "IslandGeometry.txt", "w")
    if file then file:write(string.format("%.3f", islandWidth)); file:close() end
  end
  local times = dayTimes(now)
  local export = io.open(resources .. "PrayerTimes.txt", "w")
  if export then
    export:write(dateKey(now), "\n")
    local names = {"Fajr", "Sunrise", "Dhuhr", "Asr", "Maghrib", "Isha"}
    if times then for i, instant in ipairs(times) do export:write(names[i], "|", clock(instant), "\n") end end
    export:close()
  end
  frame = frame + 1
  if now - lastPrayerRead >= 60 then
    lastPrayerRead = now
    local load = loadfile(resources .. "ScheduleAPI.lua")
    if load then
      local ok, snapshot = pcall(load)
      if ok and type(snapshot) == "table" and type(snapshot.dates) == "table" and snapshot.updated ~= prayerSnapshotUpdated then
        for date, times in pairs(snapshot.dates) do schedule[date] = times end
        prayerSnapshotUpdated = snapshot.updated
        prayerDate = nil
      end
    end
  end
  local period
  local demo = SKIN:GetVariable("DemoMode") == "1" and #demoPeriods > 0
  local seconds = math.max(2, tonumber(SKIN:GetVariable("DemoSeconds")) or 20)
  if demo then
    local elapsed = math.max(0, now - demoStarted)
    period = demoPeriods[math.floor(elapsed / seconds) % #demoPeriods + 1]
    now = period.start + (period.finish - period.start) * (elapsed % seconds) / seconds
  else
    period = realPrayerPeriod(now)
  end
  if SKIN:GetVariable("Headless") == "1" then
    local progress = period and math.max(0, math.min(1, (now - period.start) / (period.finish - period.start))) or 0
    local home = io.open(resources .. "PrayerHome.txt", "w")
    if home then
      home:write((period and period.name or "Unavailable") .. "\n" .. (period and clock(period.start) or "—") .. "\n" .. (period and clock(period.finish) or "—") .. "\n" .. tostring(progress))
      home:close()
    end
    return
  end
  local identity = period and period.name .. period.start or "unavailable"
  local periodChanged = shownPeriod ~= identity
  if periodChanged then
    local nextName = period and period.name or "Unavailable"
    if displayedName then
      text("PreviousPrayerSharp", displayedName)
      text("PreviousPrayerBlur", displayedName)
      nameTransition = 0
      nameLayer("Previous", 1, 0)
      nameLayer("Incoming", 0, 3)
    else
      nameLayer("Previous", 0, 0)
      nameLayer("Incoming", 1, 0)
    end
    text("IncomingPrayerSharp", nextName)
    text("IncomingPrayerBlur", nextName)
    displayedName = nextName
    shownPeriod = identity
    measureAfter = frame + 1
    if not demo then SKIN:Bang("!CommandMeasure", "Animator", "Execute 1") end
  end
  text("CurrentPrayer", period and period.name or "Unavailable")
  text("PrayerStart", period and clock(period.start))
  text("PrayerEnd", period and clock(period.finish))
  local progress = period and math.max(0, math.min(1, (now - period.start) / (period.finish - period.start))) or 0
  local home = io.open(resources .. "PrayerHome.txt", "w")
  if home then
    home:write((period and period.name or "Unavailable") .. "\n" .. (period and clock(period.start) or "—") .. "\n" .. (period and clock(period.finish) or "—") .. "\n" .. tostring(progress))
    home:close()
  end
  if demo then
    progressRate = 1 / seconds
    if periodChanged or not displayProgress then displayProgress = progress end
    progressCorrection = progress - displayProgress
    setProgressWidth(displayProgress)
    SKIN:Bang("!CommandMeasure", "Animator", "Stop 2")
    SKIN:Bang("!CommandMeasure", "Animator", "Execute 2")
  else
    setProgressWidth(progress)
  end
end

function BeginHomeIntro()
  homeIntro = 0
  AnimatePrayer()
  SKIN:Bang("!UpdateMeter", "*")
  SKIN:Bang("!Redraw")
  SKIN:Bang("!CommandMeasure", "Animator", "Stop 1")
  SKIN:Bang("!CommandMeasure", "Animator", "Execute 1")
end

function AnimateHomeWidth(fromWidth)
  if not islandWidth or not nameSpan then return end
  local scale = tonumber(SKIN:GetVariable("S"))
  nameSpan = math.max(8 * scale, nameSpan + fromWidth - islandWidth)
  nameVelocity = 0
  SKIN:Bang("!CommandMeasure", "Animator", "Stop 1")
  SKIN:Bang("!CommandMeasure", "Animator", "Execute 1")
end

function CenterIsland()
  if SKIN:GetVariable("Headless") == "1" then return end
  local width = math.floor(480 * tonumber(SKIN:GetVariable("S")) + 0.5)
  local left = tonumber(SKIN:GetVariable("SCREENAREAX"))
  local screenWidth = tonumber(SKIN:GetVariable("SCREENAREAWIDTH"))
  local top = tonumber(SKIN:GetVariable("SCREENAREAY"))
  SKIN:Bang("!Move", math.floor(left + (screenWidth - width) / 2), top)
  SKIN:Bang("!Draggable", "0")
  SKIN:Bang("!ZPos", "-2")
  SKIN:Bang("!SetTransparency", "255")
end

local function readCalendar(now)
  if now - lastRead < 60 then return end
  lastRead = now
  local load, error = loadfile(resources .. "CalendarData.lua")
  if load then
    local ok, data = pcall(load)
    if ok and type(data) == "table" then calendar = data end
  end
end

local function labelFor(event, day)
  if event.allDay then return "All day" end
  local start, finish = event.start / 1000, event["end"] / 1000
  if start < day and finish >= day + daySeconds then return "Ongoing" end
  if start < day then return "Until " .. clock(finish) end
  if finish >= day + daySeconds then return "From " .. clock(start) end
  if start == finish then return clock(start) end
  return clock(start) .. "–" .. clock(finish)
end

local function monthGrid(now)
  text("Month", months[monthNumber] .. " " .. monthYear)
  local first = midnightFor(monthYear, monthNumber, 1)
  local firstParts = istanbul(first)
  local leading = (firstParts.wday + 5) % 7
  local nextYear, nextMonth = monthYear, monthNumber + 1
  if nextMonth == 13 then nextMonth = 1 nextYear = nextYear + 1 end
  local days = math.floor((midnightFor(nextYear, nextMonth, 1) - first) / daySeconds)
  local current = selected or startOfDay(now)
  for i = 0, 41 do
    local number = i - leading + 1
    local valid = number >= 1 and number <= days
    cells[i] = valid and first + (number - 1) * daySeconds or nil
    hidden("Day" .. i, not valid)
    hidden("DayBg" .. i, not valid)
    if valid then
      local day = cells[i]
      local chosen = dateKey(day) == dateKey(current)
      local today = dateKey(day) == dateKey(now)
      local accent = SKIN:GetVariable("Accent")
      local fill = chosen and accent or "0,0,0,0"
      local stroke = today and accent or "0,0,0,0"
      option("DayBg" .. i, "Shape", string.format(
        "Rectangle 0,0,(34*#S#),(34*#S#),(17*#S#) | Fill Color %s | Stroke Color %s | StrokeWidth 1", fill, stroke))
      text("Day" .. i, number)
      option("Day" .. i, "FontColor", chosen and SKIN:GetVariable("Background") or SKIN:GetVariable("Text"))
    end
  end
end

local function agenda(now)
  readCalendar(now)
  local day = selected or startOfDay(now)
  local date = istanbul(day)
  text("Title", weekdays[date.wday])
  text("Date", date.day .. " " .. months[date.month]:sub(1, 3) .. (picker and "  ˄" or "  ˅"))
  for i = 0, 6 do hidden("Weekday" .. i, not picker) end
  for _, meter in ipairs({"Month", "Previous", "Next"}) do hidden(meter, not picker) end
  for i = 0, 41 do
    hidden("Day" .. i, not picker)
    hidden("DayBg" .. i, not picker)
  end
  if picker then
    hidden("Status", true)
    for i = 0, 7 do
      hidden("EventBg" .. i, true)
      hidden("EventName" .. i, true)
      hidden("EventTime" .. i, true)
    end
    monthGrid(now)
    return
  end
  local events = calendar[dateKey(day)]
  local visible = {}
  for _, event in ipairs(events or {}) do
    if selected or SKIN:GetVariable("ShowFinished") == "1" or event.allDay or event["end"] / 1000 > now then
      visible[#visible + 1] = event
    end
  end
  offset = math.max(0, math.min(offset, #visible - 8))
  hidden("Status", #visible > 0)
  text("Status", not events and "Calendar data unavailable for this date." or (#visible == 0 and "No events on this date." or ""))
  for i = 0, 7 do
    local event = visible[offset + i + 1]
    for _, name in ipairs({"EventBg", "EventName", "EventTime"}) do hidden(name .. i, not event) end
    if event then
      text("EventName" .. i, event.title:gsub("[\r\n]", " "))
      text("EventTime" .. i, labelFor(event, day))
      local active = not event.allDay and now >= event.start / 1000 and now < event["end"] / 1000
      option("EventName" .. i, "FontColor", active and SKIN:GetVariable("Accent") or SKIN:GetVariable("Text"))
    end
  end
end

function Update()
  dirty = false
  local accentFile = io.open(resources .. "SystemAccent.txt", "r")
  if accentFile then
    local accent = accentFile:read("*l")
    accentFile:close()
    if accent and accent:match("^%d+,%d+,%d+$") and accent ~= SKIN:GetVariable("Accent") then
      SKIN:Bang("!SetVariable", "Accent", accent)
      if kind == "Prayer" and SKIN:GetVariable("Headless") ~= "1" and not nameTransition then
        nameLayer("Incoming", 1, 0)
        nameLayer("Previous", 0, 0)
      end
    end
  end
  local now = os.time()
  if kind == "Prayer" then prayer(now) else agenda(now) end
  if dirty then
    SKIN:Bang("!UpdateMeter", "*")
    SKIN:Bang("!Redraw")
  end
  return 0
end

function TogglePicker()
  picker = not picker
  if picker then
    local t = istanbul(selected or os.time())
    monthYear, monthNumber = t.year, t.month
  end
  Update()
end

function Today()
  selected = nil
  picker = false
  offset = 0
  Update()
end

function ChangeMonth(delta)
  monthNumber = monthNumber + delta
  if monthNumber < 1 then monthNumber = 12 monthYear = monthYear - 1 end
  if monthNumber > 12 then monthNumber = 1 monthYear = monthYear + 1 end
  local now = istanbul(os.time())
  local monthIndex = monthYear * 12 + monthNumber
  local currentIndex = now.year * 12 + now.month
  if monthIndex < currentIndex - 6 or monthIndex > currentIndex + 12 then
    local t = istanbul(selected or os.time())
    monthYear, monthNumber = t.year, t.month
  end
  Update()
end

function ChooseDay(index)
  if not cells[index] then return end
  selected = cells[index]
  if dateKey(selected) == dateKey(os.time()) then selected = nil end
  picker = false
  offset = 0
  Update()
end

function Scroll(delta)
  if picker then return end
  offset = math.max(0, offset + delta)
  Update()
end

local function save(name, value, file)
  SKIN:Bang("!WriteKeyValue", "Variables", name, tostring(value), file or resources .. kind .. ".inc")
end

function Resize(delta)
  local scale = math.max(0.6, math.min(2, tonumber(SKIN:GetVariable("S")) + delta))
  save("S", string.format("%.2f", scale))
  SKIN:Bang("!Refresh")
end

function ToggleDetail()
  local name = kind == "Prayer" and "ShowSeconds" or "ShowFinished"
  local value = SKIN:GetVariable(name) == "1" and "0" or "1"
  save(name, value)
  SKIN:Bang("!SetVariable", name, value)
  Update()
end

function Palette(name, both)
  local presets = {
    Midnight = {"15,16,18", "250,250,250", "158,230,168", "169,171,176"},
    Ocean = {"16,25,35", "240,247,255", "138,211,255", "159,176,192"},
    Plum = {"28,20,34", "250,242,255", "213,176,255", "181,163,192"},
    Sand = {"33,26,19", "255,246,232", "255,208,140", "190,173,149"}
  }
  local colors = presets[name]
  if not colors then return end
  local targets = both and {"Prayer", "Calendar"} or {kind}
  for _, target in ipairs(targets) do
    for i, key in ipairs({"Background", "Text", "Accent", "Muted"}) do
      save(key, colors[i], resources .. target .. ".inc")
    end
    SKIN:Bang("!Refresh", "SariyerWidgets\\" .. target)
  end
end
