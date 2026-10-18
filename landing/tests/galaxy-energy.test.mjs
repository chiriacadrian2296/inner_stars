import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {transpileModule,ModuleKind,ScriptTarget} from 'typescript';
import test from 'node:test';
const js=transpileModule(readFileSync(new URL('../src/components/galaxy-energy.ts',import.meta.url),'utf8'),{compilerOptions:{module:ModuleKind.ESNext,target:ScriptTarget.ES2022}}).outputText;
const {pathDistances,waveBrightness}=await import(`data:text/javascript;base64,${Buffer.from(js).toString('base64')}`);
test('energy follows the connected path through branches and loops, not straight-line proximity',()=>{
  const points=[{x:0,y:0},{x:100,y:0},{x:100,y:100},{x:0,y:100},{x:0,y:1}];
  assert.deepEqual(pathDistances(points,[[0,1],[1,2],[2,3],[1,3]],0).map(n=>Number.isFinite(n)?Math.round(n):null),[0,100,200,241,null]);
  assert.equal(waveBrightness(100,100,1),1);
  assert.equal(waveBrightness(100,55,1),0);
  assert.equal(waveBrightness(100,250,1),0);
  assert.ok(waveBrightness(100,150,1)>0);
  assert.equal(waveBrightness(200,300,2),waveBrightness(100,150,1));
});
