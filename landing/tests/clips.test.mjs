import assert from 'node:assert/strict';
import {readFileSync,existsSync} from 'node:fs';
import test from 'node:test';
import sharp from 'sharp';
import {fileURLToPath} from 'node:url';
test('the navigation guide ships three real animated clips with lightweight still posters',async()=>{
  for(const [name,frames] of [['fly',48],['widen',48],['energy',84]]){
    const path=new URL(`../public/clips/${name}.webp`,import.meta.url);
    const metadata=await sharp(fileURLToPath(path)).metadata();
    assert.equal(metadata.pages,frames);
    assert.equal(metadata.width,512);
    assert.ok(readFileSync(path).length<600_000);
    assert.equal((await sharp(fileURLToPath(new URL(`../public/clips/${name}-poster.webp`,import.meta.url))).metadata()).pages,undefined);
  }
  // The guide pages are hidden for now; check their clips only when they are built.
  for(const path of ['scopri/navigazione','en/explore/navigation'].filter(path=>existsSync(new URL(`../dist/${path}/index.html`,import.meta.url)))){
    const html=readFileSync(new URL(`../dist/${path}/index.html`,import.meta.url),'utf8');
    assert.equal([...html.matchAll(/data-clip /g)].length,3);
    assert.equal([...html.matchAll(/<button hidden type="button" aria-pressed="false"/g)].length,3);
  }
});
