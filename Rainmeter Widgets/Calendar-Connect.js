'use strict';
const path = require('node:path');
const fs = require('node:fs');
const helper = require(path.join(process.env.LOCALAPPDATA, 'Sariyer Widgets', 'calendar-sync.js'));
let input = '';
process.stdin.setEncoding('utf8');
process.stdin.on('data', chunk => { input += chunk; if (input.length > 16384) process.exit(1); });
process.stdin.on('end', async () => {
  try { const request = JSON.parse(input); await helper.setCalendarSource(request.address); process.exitCode=0; }
  catch { process.exitCode=1; }
});
