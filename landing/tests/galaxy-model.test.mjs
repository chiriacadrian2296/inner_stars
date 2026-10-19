import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { transpileModule,ModuleKind } from 'typescript';
import test from 'node:test';
const source=readFileSync(new URL('../src/components/galaxy-model.ts',import.meta.url),'utf8');
const bundled=source.replace("import presets from './galaxy-presets.json';",`const presets = ${readFileSync(new URL('../src/components/galaxy-presets.json',import.meta.url),'utf8')};`);
const js=transpileModule(bundled,{compilerOptions:{module:ModuleKind.ESNext}}).outputText;
const model=await import(`data:text/javascript;base64,${Buffer.from(js).toString('base64')}`);

test('artwork offsets match the app and projected labels follow each shifted light',()=>{
  const dart=readFileSync(new URL('../../lib/widgets/constellation_field.dart',import.meta.url),'utf8');
  for(const [area,index] of [['psychological',1],['professional',2],['personal',4],['philanthropic',7]]){
    const value=Number(dart.match(new RegExp(`LifeArea\\.${area} => ([\\d.]+)`))[1]);
    assert.equal(model.supernovaOffsets[index],value);
  }
  for(let i=0;i<8;i++)for(const stage of [0,1,2,3]){
    const camera=model.basis(model.cameraAt(stage,i).direction);
    const {axisA,axisB}=model.artworkAxes(model.areas[i]);
    assert.ok(Math.abs(model.dot(axisA,axisB))<1e-9);
    const light=model.projectPoint(model.supernovaDirections[i],camera,1,1200,800,0,0);
    assert.ok(light&&Number.isFinite(light.x)&&Number.isFinite(light.y));
  }
});

test('every area, project and activity stays on the same unit sky sphere',()=>{
  assert.equal(model.areas.length,8);
  for(const vector of [...model.areas,...model.projects.flatMap(p=>[p.center,...p.points])])assert.ok(Math.abs(Math.hypot(...vector)-1)<1e-9);
  for(const p of model.projects)assert.ok(Math.abs(Math.acos(model.dot(model.areas[p.area],p.center))-.18)<1e-9);
});
test('all four perspectives focus their target and widen continuously',()=>{
  for(let area=0;area<8;area++){
    let previous=Infinity;
    for(let stage=0;stage<=3;stage+=.05){
      const state=model.cameraAt(stage,area);
      assert.ok(Number.isFinite(state.zoom));assert.ok(state.zoom<=previous+1e-9);previous=state.zoom;
      const camera=model.basis(state.direction);
      assert.ok(Math.abs(model.dot(camera.forward,camera.right))<1e-9);
      const point=model.projectPoint(state.direction,camera,state.zoom,1200,800,0,0);
      assert.ok(Math.abs(point.x-600)<1e-8&&Math.abs(point.y-400)<1e-8);
    }
    assert.ok(Math.abs(model.cameraAt(3,area).zoom-.3)<1e-9);
  }
});
test('the far side is culled and a foreground target keeps the shader viewport offset',()=>{
  const camera=model.basis(model.areas[2]);
  assert.equal(model.projectPoint(model.mul(model.areas[2],-1),camera,1,1200,800,0,0),null);
  const point=model.projectPoint(model.areas[2],camera,1,1200,800,200,60);
  assert.ok(Math.abs(point.x-800)<1e-8&&Math.abs(point.y-460)<1e-8);
});
test('a flight between opposite polar areas leaves its starting direction',()=>{
  const start=model.areas[0],end=model.areas[7],step=model.mix(start,end,.12);
  assert.ok(Math.abs(Math.hypot(...step)-1)<1e-9);
  assert.ok(model.dot(step,start)<.99);
});
test('the narrative opens in an empty dark patch, then holds one star, then reveals every larger level',()=>{
  assert.deepEqual([0,1,2,3,4,5].map(model.journeyStage),[-1,-.8,0,1,2,3]);
  assert.ok(Math.abs(model.journeyStage(1-1e-5)-model.journeyStage(1+1e-5))<1e-4);
  const camera=model.basis(model.cameraAt(-1).direction);
  // No area/project center in the opening's central field of view.
  for(const direction of [...model.areas,...model.projects.map(p=>p.center)]){
    const point=model.projectPoint(direction,camera,3.2,390,844,0,0);
    assert.ok(!point||point.x<0||point.x>390||point.y<0||point.y>844);
  }
  assert.ok(new Set(model.projects.map(p=>p.shape)).size>25);
});

test('the whole sky draws its neighbours closer, most on tall narrow screens, and only from the area level on',()=>{
  assert.ok(model.wholeSkyBoost(3,390,800)<model.wholeSkyBoost(3,1280,768));
  assert.ok(model.wholeSkyBoost(3,1280,768)<.9);
  assert.equal(model.wholeSkyBoost(1,390,800),1);
  assert.ok(Math.abs(model.skyZoom(0,2,390,800)-model.cameraAt(0,2).zoom)<1e-12);
  assert.ok(model.skyZoom(3,2,390,800)<model.cameraAt(3,2).zoom*.6);
  // On a phone the nearest neighbouring supernova now lands within the screen width.
  const camera=model.basis(model.areas[2]);let nearest=Infinity;
  for(const [i,area] of model.areas.entries()){ if(i===2)continue; const pt=model.projectPoint(area,camera,model.skyZoom(3,2,390,800),390,800,0,0); if(pt)nearest=Math.min(nearest,Math.hypot(pt.x-195,pt.y-400)); }
  assert.ok(nearest<330);
});
