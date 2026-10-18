export type Point={x:number;y:number};
// ConstellationPainter's Dijkstra wave: distance follows connections, including
// branches and loops. Separate components start their own wave.
export function pathDistances(points:Point[],edges:number[][],start:number) {
  const distances=points.map(()=>Infinity),open=new Set([start]);distances[start]=0;
  while(open.size){
    const u=[...open].reduce((a,b)=>distances[a]<distances[b]?a:b);open.delete(u);
    for(const [a,b] of edges){const v=a===u?b:b===u?a:-1;if(v<0||!points[v])continue;
      const d=distances[u]+Math.hypot(points[u].x-points[v].x,points[u].y-points[v].y);
      if(d<distances[v]-1e-6){distances[v]=d;open.add(v);}
    }
  }
  return distances;
}
export function waveBrightness(distance:number,head:number,scale:number){
  const behind=head-distance,front=45*scale,tail=150*scale;
  if(behind<=-front||behind>=tail)return 0;
  if(behind<0){const t=(behind+front)/front;return t*t*(3-2*t);}
  return (1-behind/tail)**2;
}
export function paintEnergy(ctx:CanvasRenderingContext2D,points:Point[],edges:number[][],size:number,time:number,phase:number){
  const scale=size/1000;if(scale<=0)return;
  const visited=new Set<number>();
  ctx.save();ctx.globalCompositeOperation='lighter';ctx.lineCap='round';
  for(let start=0;start<points.length;start++){
    if(visited.has(start))continue;
    const distances=pathDistances(points,edges,start);
    const connected=distances.map((d,i)=>Number.isFinite(d)?i:-1).filter(i=>i>=0);
    connected.forEach(i=>visited.add(i));
    const reach=Math.max(...connected.map(i=>distances[i]))/scale;
    const cycle=(reach+150+45)/260+2.2;
    const head=(((time+phase)%cycle)*260-45)*scale;
    const glow=(d:number)=>waveBrightness(d,head,scale);
    for(const [a,b] of edges){
      if(!Number.isFinite(distances[a])||!Number.isFinite(distances[b]))continue;
      const aa=points[a],bb=points[b],length=Math.hypot(aa.x-bb.x,aa.y-bb.y);
      const core=ctx.createLinearGradient(aa.x,aa.y,bb.x,bb.y),halo=ctx.createLinearGradient(aa.x,aa.y,bb.x,bb.y);
      for(let j=0;j<=12;j++){const u=j/12,g=glow(Math.min(distances[a]+u*length,distances[b]+(1-u)*length));core.addColorStop(u,`rgba(255,234,194,${g})`);halo.addColorStop(u,`rgba(242,184,75,${g*.35})`);}
      for(const [gradient,width] of [[halo,7],[core,2.6]] as const){ctx.strokeStyle=gradient;ctx.lineWidth=width*scale*3.5;ctx.beginPath();ctx.moveTo(aa.x,aa.y);ctx.lineTo(bb.x,bb.y);ctx.stroke();}
    }
    for(const i of connected){const g=glow(distances[i]);if(g<.02)continue;
      const point=points[i],r=26*scale*1.8,gradient=ctx.createRadialGradient(point.x,point.y,0,point.x,point.y,r);
      gradient.addColorStop(0,`rgba(255,255,255,${g*.9})`);gradient.addColorStop(.35,`rgba(242,184,75,${g*.4})`);gradient.addColorStop(1,'rgba(242,184,75,0)');ctx.fillStyle=gradient;ctx.beginPath();ctx.arc(point.x,point.y,r,0,Math.PI*2);ctx.fill();
    }
  }
  ctx.restore();
}
