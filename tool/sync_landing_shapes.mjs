import {readFile,writeFile} from 'node:fs/promises';
const source=await readFile(new URL('../lib/data/constellation_presets.dart',import.meta.url),'utf8');
const shapes={};
for(const block of source.split('StarsShapePreset(')){
  const id=block.match(/id: '([^']+)'/), grid=block.match(/grid: \[([\s\S]*?)\]/), edges=block.match(/edges: \[([\s\S]*?)\]/);
  if(!id||!grid||!edges)continue;
  const pairs=text=>[...text.matchAll(/\((\d+),\s*(\d+)\)/g)].map(m=>[Number(m[1]),Number(m[2])]);
  const points=pairs(grid[1]), xs=points.map(p=>p[0]),ys=points.map(p=>p[1]);
  const loX=Math.min(...xs),hiX=Math.max(...xs),loY=Math.min(...ys),hiY=Math.max(...ys);
  const scale=.8/Math.max(hiX-loX||1,hiY-loY||1);
  shapes[id[1]]={points:points.map(([x,y])=>[.5+(x-(loX+hiX)/2)*scale,.5+(y-(loY+hiY)/2)*scale]),edges:pairs(edges[1])};
}
await writeFile(new URL('../landing/src/components/galaxy-presets.json',import.meta.url),JSON.stringify(shapes));
console.log(`Synced ${Object.keys(shapes).length} original Galaxy shapes.`);
