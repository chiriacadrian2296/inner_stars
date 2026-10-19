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
  for(const p of model.projects)assert.ok(Math.abs(Math.acos(model.dot(model.supernovaDirections[p.area],p.center))-.18)<1e-9);
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

test('the whole sky is a flat map: centre area, seven evenly spaced neighbours, upright constellations',()=>{
  const camera=model.basis(model.cameraAt(3,2).direction);
  const at=v=>{const pt=model.projectPoint(v,camera,1,1000,1000,0,0);assert.ok(pt);return pt;};
  const centre=at(model.areasFlat[2]);
  assert.ok(Math.abs(centre.x-500)<1e-6&&Math.abs(centre.y-500)<1e-6);
  const dist=[],angles=[];
  for(let i=0;i<8;i++){ if(i===2)continue; const pt=at(model.areasFlat[i]); dist.push(Math.hypot(pt.x-500,pt.y-500)); angles.push(Math.atan2(pt.y-500,pt.x-500)); }
  for(const d of dist)assert.ok(Math.abs(d-dist[0])<1e-6);
  angles.sort((a,b)=>a-b);
  for(let k=0;k<7;k++){ const gap=(angles[(k+1)%7]-angles[k]+2*Math.PI)%(2*Math.PI); assert.ok(Math.abs(gap-2*Math.PI/7)<1e-6); }
  // Every constellation keeps its drawn orientation: unit y runs down the screen, x to the right.
  for(const [k,pr] of model.projects.entries()){
    const flat=model.projectsFlat[k], c=at(flat.center);
    const sx=[],sy=[];
    pr.unit.forEach(([x,y],j)=>{const pt=at(flat.points[j]); sx.push([x-.5,pt.x-c.x]); sy.push([y-.5,pt.y-c.y]);});
    const corr=pairs=>{const n=pairs.length,ma=pairs.reduce((s,p)=>s+p[0],0)/n,mb=pairs.reduce((s,p)=>s+p[1],0)/n;let num=0,da=0,db=0;for(const [a,b] of pairs){num+=(a-ma)*(b-mb);da+=(a-ma)**2;db+=(b-mb)**2;}return num/Math.sqrt(da*db||1);};
    assert.ok(corr(sx)>.97&&corr(sy)>.97,'project '+k);
  }
  assert.equal(model.layoutAt(0).artCentres,model.areas);
  assert.ok(model.layoutAt(1).artCentres.every((v,i)=>model.dot(v,model.areasFlat[i])>1-1e-9));
});
test('the flat map zoom fits narrow phones and wide screens, and applies only from the area level on',()=>{
  const phone=model.flatMapUnitPx(390,800),desk=model.flatMapUnitPx(1280,768);
  assert.ok(phone*(model.flatRing+.27)<=390/2);
  assert.ok(desk*(model.flatRing+.27)<=1280*.25);
  assert.equal(model.wholeSkyBoost(1,390,800),1);
  assert.ok(Math.abs(model.skyZoom(0,2,390,800)-model.cameraAt(0,2).zoom)<1e-12);
  assert.ok(Math.abs(model.skyZoom(3,2,390,800)-phone/800)<1e-12);
});

test('the shader is handed the finished lights, so it can never disagree with the artwork anchored to them',()=>{
  for(const t of [0,.25,.5,.75,1]){
    const layout=model.layoutAt(t);
    assert.ok(layout.shaderOffsets.every(o=>o===0),'t='+t);
    layout.shaderPositions.forEach((v,i)=>assert.ok(model.dot(v,layout.lights[i])>1-1e-12,'t='+t+' area '+i));
  }
  // At t = 0 those lights are exactly where the app's shader puts them: area centre plus its own vertical offset.
  const base=model.layoutAt(0);
  for(let i=0;i<8;i++){
    const {axisB}=model.artworkAxes(model.areas[i]);
    const appLight=model.norm(model.add(model.areas[i],model.mul(axisB,model.supernovaOffsets[i])));
    assert.ok(model.dot(appLight,base.lights[i])>1-1e-12,'area '+i);
  }
});
