const sharp = require('C:/Users/chiri/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp');
const names = ['physical', 'psychological', 'professional', 'financial', 'personal', 'social', 'spiritual', 'philanthropic'];
(async () => {
  const items = [];
  for (let i = 0; i < names.length; i++) {
    const x = (i % 4) * 180, y = Math.floor(i / 4) * 200;
    for (const size of [24, 96]) {
      items.push({input: await sharp(`assets/images/area_icons/${names[i]}.svg`).resize(size, size).png().toBuffer(), left: x + (180-size)/2, top: y + (size===24?40:84)});
    }
    items.push({input: Buffer.from(`<svg width="180" height="30"><text x="90" y="22" text-anchor="middle" fill="#ddd" font-size="14">${names[i]}</text></svg>`), left:x, top:y});
  }
  await sharp({create:{width:720,height:400,channels:4,background:'#111521'}}).composite(items).png().toFile('output/imagegen/area-vectors-check.png');
})();
