import fs from 'node:fs/promises';
import path from 'node:path';

const repoRoot = path.resolve(process.cwd(), '..');
const stopsPath = path.join(repoRoot, 'lib', 'stops.ts');
const schedulesPath = path.join(repoRoot, 'lib', 'scheduleData.ts');
const outDir = path.join(process.cwd(), 'assets', 'data');

const stopsSource = await fs.readFile(stopsPath, 'utf8');
const schedulesSource = await fs.readFile(schedulesPath, 'utf8');

const routeNames = ['BLUE', 'GOLD', 'GREEN', 'BROWN', 'ORANGE', 'RED', 'PURPLE'];

function parseStops(source) {
  const output = {};

  for (const routeName of routeNames) {
    const marker = `export const ${routeName}_STOPS: Stop[] = [`;
    const start = source.indexOf(marker);
    if (start === -1) continue;
    const bodyStart = start + marker.length;
    const bodyEnd = source.indexOf('\n];', bodyStart);
    if (bodyEnd === -1) continue;

    const body = source.slice(bodyStart, bodyEnd);
    output[routeName.toLowerCase()] = Function(`return [${body}];`)();
  }

  return output;
}

function parseSchedules(source) {
  const output = {};

  for (const routeName of routeNames) {
    const marker = `const ${routeName}_SCHEDULE: RouteSchedule = {`;
    const start = source.indexOf(marker);
    if (start === -1) continue;
    const stopsMarker = 'stops: [';
    const tripsMarker = 'trips: [';
    const stopsStart = source.indexOf(stopsMarker, start);
    const tripsStart = source.indexOf(tripsMarker, start);
    if (stopsStart === -1 || tripsStart === -1) continue;

    const stopsBodyStart = stopsStart + stopsMarker.length;
    const stopsBodyEnd = source.indexOf('\n  ],', stopsBodyStart);
    const tripsBodyStart = tripsStart + tripsMarker.length;
    const tripsBodyEnd = source.indexOf('\n  ],\n};', tripsBodyStart);
    if (stopsBodyEnd === -1 || tripsBodyEnd === -1) continue;

    const stops = Function(
      `return [${source.slice(stopsBodyStart, stopsBodyEnd)}];`,
    )();
    const trips = Function(
      `return [${source.slice(tripsBodyStart, tripsBodyEnd)}];`,
    )();
    output[routeName.toLowerCase()] = { stops, trips };
  }

  return output;
}

await fs.mkdir(outDir, { recursive: true });
await fs.writeFile(
  path.join(outDir, 'stops.json'),
  JSON.stringify(parseStops(stopsSource), null, 2) + '\n',
);
await fs.writeFile(
  path.join(outDir, 'schedules.json'),
  JSON.stringify(parseSchedules(schedulesSource), null, 2) + '\n',
);

console.log('Generated assets/data/stops.json and assets/data/schedules.json');
