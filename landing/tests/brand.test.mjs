import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import test from 'node:test';
import sharp from 'sharp';

const root=new URL('../../',import.meta.url);
test('the website uses the original S path, without clipping its ink',async()=>{
  const original=readFileSync(new URL('assets/icon/Logo.svg',root),'utf8');
  const mark=readFileSync(new URL('landing/public/logo-mark.svg',root),'utf8');
  assert.equal(mark.match(/<path d="([^"]+)"/s)[1],original.match(/<path d="([^"]+)"/s)[1]);
  const {data,info}=await sharp(Buffer.from(mark)).resize(100,140,{fit:'contain',background:'#0d1220'}).removeAlpha().raw().toBuffer({resolveWithObject:true});
  let ink=0;
  for(let i=0;i<data.length;i+=info.channels)if(data[i]>180&&data[i+1]>100)ink++;
  assert.ok(ink/(info.width*info.height)>.25,'S is missing or cropped outside its viewBox');
});
test('launcher and browser icons contain an entirely gold mark with navy padding',async()=>{
  for(const path of ['assets/icon/app_icon.png','web/favicon.png','web/icons/Icon-512.png','ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png','landing/public/favicon.png']){
    const {data,info}=await sharp(fileURLToPath(new URL(path,root))).resize(64,64).removeAlpha().raw().toBuffer({resolveWithObject:true});
    let ink=0,white=0,gold=0;
    for(let i=0;i<data.length;i+=info.channels)if(data[i]>180&&data[i+1]>100){ink++;if(data[i+2]>180)white++;else if(data[i+2]<140)gold++;}
    assert.ok(white<10&&gold>150,`${path}: mark should be entirely gold`);
    // The Flutter generator's 16px favicon loses some edge coverage to AA.
    assert.ok(ink/4096>.06&&ink/4096<.45,`${path}: invalid logo coverage`);
    assert.deepEqual([...data.subarray(0,3)],[13,18,32],`${path}: navy corner`);
  }
});
