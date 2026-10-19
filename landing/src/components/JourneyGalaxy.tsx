import { useEffect, useRef, useState } from 'react';
import { fragmentSource, supernovaFragmentSource, flareFragmentSource, vertexSource } from './journey-nebula';
import { add, mul, norm, ease, artworkAxes, supernovaDirections, supernovaOffsets, areas, areaNames, basis, cameraAt, clamp, journeyStage, mix, projectPoint, projects, projectsPerArea, starDirection, type Vec } from './galaxy-model';
import { paintEnergy } from './galaxy-energy';
import type { SiteLang as Lang } from '../i18n/types';
type Flare = { x:number; y:number; seed:number[]; count:number };
type FlareGroup = { radius:number; mode:number; stars:Flare[] };

function createSky(canvas: HTMLCanvasElement) {
  const gl = canvas.getContext('webgl2', { alpha: false, antialias: false, depth: false, powerPreference: 'low-power' });
  if (!gl) return null;
  const shaders: WebGLShader[] = [], programs: WebGLProgram[] = [];
  const buffer = gl.createBuffer(), texture = gl.createTexture(), lineTexture=gl.createTexture();
  const dispose = () => { shaders.forEach(s => gl.deleteShader(s)); programs.forEach(p => gl.deleteProgram(p)); gl.deleteBuffer(buffer); gl.deleteTexture(texture); gl.deleteTexture(lineTexture); };
  const compile = (source: string) => {
    const program = gl.createProgram(); if (!program) throw Error('No WebGL program'); programs.push(program);
    for (const [type, code] of [[gl.VERTEX_SHADER, vertexSource], [gl.FRAGMENT_SHADER, source]] as const) {
      const shader = gl.createShader(type); if (!shader) throw Error('No WebGL shader'); shaders.push(shader); gl.shaderSource(shader, code); gl.compileShader(shader);
      if (!gl.getShaderParameter(shader, gl.COMPILE_STATUS)) throw Error(gl.getShaderInfoLog(shader) || 'Galaxy shader compilation failed');
      gl.attachShader(program, shader);
    }
    gl.linkProgram(program); if (!gl.getProgramParameter(program, gl.LINK_STATUS)) throw Error(gl.getProgramInfoLog(program) || 'Galaxy shader link failed');
    return program;
  };
  try {
    const background = compile(fragmentSource), supernova = compile(supernovaFragmentSource), flares = compile(flareFragmentSource);
    const lines=compile(`#version 300 es
precision highp float;
uniform vec2 uResolution;
uniform sampler2D uLines;
out vec4 fragColor;
void main(){fragColor=texture(uLines,vec2(gl_FragCoord.x/uResolution.x,1.-gl_FragCoord.y/uResolution.y));}`);
    gl.bindBuffer(gl.ARRAY_BUFFER, buffer); gl.bufferData(gl.ARRAY_BUFFER, new Float32Array([-1, -1, 1, -1, -1, 1, -1, 1, 1, -1, 1, 1]), gl.STATIC_DRAW);
    gl.bindTexture(gl.TEXTURE_2D, texture); gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, 1, 1, 0, gl.RGBA, gl.UNSIGNED_BYTE, new Uint8Array([0, 0, 0, 0])); gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST);
    const locations = new Map<WebGLProgram, Map<string, WebGLUniformLocation | null>>();
    const loc = (p: WebGLProgram, n: string) => { let map = locations.get(p); if (!map) { map = new Map(); locations.set(p, map); } if (!map.has(n)) map.set(n, gl.getUniformLocation(p, n)); return map.get(n)!; };
    return {      
dispose, draw(time: number, stage: number, width: number, height: number, offsetX: number, offsetY: number, area: number, direction: Vec, groups:FlareGroup[], lineCanvas:HTMLCanvasElement) {
        const state = cameraAt(stage, area), camera = basis(direction);
        gl.viewport(0, 0, canvas.width, canvas.height);
        for (const [index, program] of [background, supernova].entries()) {
          gl.useProgram(program);
          const attr = gl.getAttribLocation(program, 'aPosition'); gl.enableVertexAttribArray(attr); gl.vertexAttribPointer(attr, 2, gl.FLOAT, false, 0, 0);
          gl.uniform2f(loc(program, 'uResolution'), canvas.width, canvas.height);
          gl.uniform2f(loc(program, 'uViewOffset'), offsetX / width * canvas.width, offsetY / height * canvas.height);
          gl.uniform1f(loc(program, 'uTime'), time);
          gl.uniform3fv(loc(program, 'uForward'), camera.forward); gl.uniform3fv(loc(program, 'uRight'), camera.right); gl.uniform3fv(loc(program, 'uUp'), camera.up);
          gl.uniform1f(loc(program, 'uZoom'), state.zoom);
          gl.uniform1f(loc(program, 'uMode'), 0); gl.uniform1f(loc(program, 'uShowGrid'), 0);
          gl.uniform1f(loc(program, 'uSupernovaLight'), .8*clamp(stage/2));
          gl.uniform3fv(loc(program, 'uSupernovas[0]'), areas.flat());
          gl.uniform4f(loc(program, 'uSupernovaLevels0'), 0, 0, .7, 0); gl.uniform4f(loc(program, 'uSupernovaLevels1'), 0, 0, 0, 0);
          gl.uniform1f(loc(program, 'uSize'), .9);
          // Let the close-up activity keep the visual focus; restore the app's
          // full area light as its supernova enters the narrative.
          gl.uniform1f(loc(program, 'uIntensity'), .8 * clamp((stage-.1)/1.9));
          gl.uniform1f(loc(program, 'uForeshorten'), .3);
          gl.uniform4fv(loc(program, 'uVerticalOffsets0'), supernovaOffsets.slice(0,4)); gl.uniform4fv(loc(program, 'uVerticalOffsets1'), supernovaOffsets.slice(4));
          gl.uniform4f(loc(program, 'uIntensityLevels0'), 0, 0, .7, 0); gl.uniform4f(loc(program, 'uIntensityLevels1'), 0, 0, 0, 0);
          if (index) { gl.enable(gl.BLEND); gl.blendFunc(gl.ONE, gl.ONE); } else gl.disable(gl.BLEND);
          gl.drawArrays(gl.TRIANGLES, 0, 6);
        }
        // Composite the app's connecting lines / energy before every star flare.
        gl.useProgram(lines);
        const lineAttr=gl.getAttribLocation(lines,'aPosition');gl.enableVertexAttribArray(lineAttr);gl.vertexAttribPointer(lineAttr,2,gl.FLOAT,false,0,0);
        gl.bindTexture(gl.TEXTURE_2D,lineTexture);gl.pixelStorei(gl.UNPACK_PREMULTIPLY_ALPHA_WEBGL,true);
        gl.texImage2D(gl.TEXTURE_2D,0,gl.RGBA,gl.RGBA,gl.UNSIGNED_BYTE,lineCanvas);
        gl.texParameteri(gl.TEXTURE_2D,gl.TEXTURE_MIN_FILTER,gl.LINEAR);gl.texParameteri(gl.TEXTURE_2D,gl.TEXTURE_MAG_FILTER,gl.LINEAR);gl.texParameteri(gl.TEXTURE_2D,gl.TEXTURE_WRAP_S,gl.CLAMP_TO_EDGE);gl.texParameteri(gl.TEXTURE_2D,gl.TEXTURE_WRAP_T,gl.CLAMP_TO_EDGE);
        gl.uniform2f(loc(lines,'uResolution'),canvas.width,canvas.height);gl.uniform1i(loc(lines,'uLines'),0);
        gl.enable(gl.BLEND);gl.blendFunc(gl.ONE,gl.ONE);gl.drawArrays(gl.TRIANGLES,0,6);
        // The production constellation shader, with bounded draw regions as in
        // ConstellationPainter. Coordinates stay in CSS pixels at every DPR.
        gl.useProgram(flares);
        const attr = gl.getAttribLocation(flares, 'aPosition'); gl.enableVertexAttribArray(attr); gl.vertexAttribPointer(attr, 2, gl.FLOAT, false, 0, 0);
        gl.uniform2f(loc(flares,'uResolution'),canvas.width,canvas.height);
        gl.uniform2f(loc(flares,'uViewOffset'),0,0);
        gl.uniform1f(loc(flares,'uTime'),time);
        gl.enable(gl.BLEND); gl.blendFunc(gl.ONE,gl.ONE); gl.enable(gl.SCISSOR_TEST);
        const rx=canvas.width/width, ry=canvas.height/height;
        for(const group of groups) {
          if(!group.stars.length)continue;
          const positions=new Float32Array(32).fill(-1),seeds=new Float32Array(32),counts=new Float32Array(16);
          let left=width,right=0,top=height,bottom=0;
          group.stars.slice(0,16).forEach((s,i)=>{
            positions[i*2]=s.x*rx; positions[i*2+1]=s.y*ry;
            seeds[i*2]=s.seed[0]; seeds[i*2+1]=s.seed[1]; counts[i]=s.count;
            left=Math.min(left,s.x-group.radius*1.2);right=Math.max(right,s.x+group.radius*1.2);
            top=Math.min(top,s.y-group.radius*1.2);bottom=Math.max(bottom,s.y+group.radius*1.2);
          });
          left=Math.max(0,Math.floor(left*rx));right=Math.min(canvas.width,Math.ceil(right*rx));
          top=Math.max(0,Math.floor(top*ry));bottom=Math.min(canvas.height,Math.ceil(bottom*ry));
          if(right<=left||bottom<=top)continue;
          gl.scissor(left,canvas.height-bottom,right-left,bottom-top);
          gl.uniform1f(loc(flares,'uFlareRadius'),group.radius*ry);
          gl.uniform1f(loc(flares,'uMode'),group.mode);
          gl.uniform3f(loc(flares,'uColor'),.43,.55,.85);
          gl.uniform2fv(loc(flares,'uPositions[0]'),positions);gl.uniform2fv(loc(flares,'uSeeds[0]'),seeds);gl.uniform1fv(loc(flares,'uCounts[0]'),counts);
          gl.drawArrays(gl.TRIANGLES,0,6);
        }
        gl.disable(gl.SCISSOR_TEST);
        gl.disable(gl.BLEND);
      }    
};
  } catch (error) { console.warn('Galaxy static fallback:', error); dispose(); return null; }
}

export default function Galaxy({ lang = 'it', closing = false, level, area = 2, interactive = false }: { lang?: Lang; closing?: boolean; level?: number; area?: number; interactive?: boolean }) {
  const rootRef = useRef<HTMLDivElement>(null), glRef = useRef<HTMLCanvasElement>(null), starsRef = useRef<HTMLCanvasElement>(null);
  const controls = useRef({ level, area });
  const redraw = useRef(() => { });
  useEffect(() => { controls.current = { level, area }; redraw.current(); }, [level, area]);
  useEffect(() => {
    const root = rootRef.current, canvas = glRef.current, overlay = starsRef.current, ctx = overlay?.getContext('2d');
    if (!root || !canvas || !overlay || !ctx) return;
    const lineCanvas=document.createElement('canvas'),lineCtx=lineCanvas.getContext('2d')!;
    let engine = createSky(canvas), w = 0, h = 0, raf = 0, visible = false, clock = 0, last = 0, lastPaint = -100, lastStage = -1, quality = 1, slow = 0;
    const media = matchMedia('(prefers-reduced-motion: reduce)'); let reduced = media.matches || !engine;
    if (!engine) canvas.style.opacity = '0';
    let renderedStage = closing ? 3 : controls.current.level ?? 0;
    let renderedDirection = cameraAt(renderedStage, controls.current.area).direction;
    const stageRoot = root.closest<HTMLElement>('.journey-stage');
    const images = areas.map((_, i) => { const image = new Image(); image.src = `${import.meta.env.BASE_URL}area-symbols/${String(i + 1).padStart(2, '0')}.webp`; image.onload = () => schedule(); return image; });
    function star(x: number, y: number, size: number, lit: boolean, time: number, index: number) {
      if (!ctx) return;
      const radius = Math.min(140, Math.max(6, size * 13));
      const glow = ctx.createRadialGradient(x, y, 0, x, y, radius);
      glow.addColorStop(0, lit ? '#fff5d5' : '#a5baf4'); glow.addColorStop(.04, lit ? '#f2b84b99' : '#6e8cd855'); glow.addColorStop(.25, lit ? '#f2b84b20' : '#6e8cd815'); glow.addColorStop(1, '#f2b84b00');
      ctx.fillStyle = glow; ctx.beginPath(); ctx.arc(x, y, radius, 0, Math.PI * 2); ctx.fill();
      ctx.strokeStyle = lit ? '#ffefb890' : '#91aff090'; ctx.lineWidth = Math.max(.5, size * .12); ctx.beginPath(); ctx.moveTo(x - size * 4, y); ctx.lineTo(x + size * 4, y); ctx.moveTo(x, y - size * 4); ctx.lineTo(x, y + size * 4); ctx.stroke();
      ctx.fillStyle = lit ? '#fff9e6' : '#9db6f1'; ctx.beginPath(); ctx.arc(x, y, Math.max(.65, size * .6), 0, Math.PI * 2); ctx.fill();
      if (lit && size > 1.5) { ctx.fillStyle = '#ffe8aa'; const a = time * .3 + index; ctx.beginPath(); ctx.arc(x + Math.cos(a) * size * 4, y + Math.sin(a) * size * 2.5, .8, 0, Math.PI * 2); ctx.fill(); }
    }
    function draw(now: number) {
      if (!ctx || !root) return;
      const rect = stageRoot?.getBoundingClientRect();
      // Progress counts whole chapters of scroll, so it stays put when a phone's address bar changes the viewport height.
      const chapterEls = stageRoot?.querySelectorAll<HTMLElement>('.chapter');
      const chapters = Math.max(1, (chapterEls?.length ?? 5) - 1);
      const unit = chapterEls && chapterEls.length > 1 ? Math.max(1, chapterEls[1].offsetTop - chapterEls[0].offsetTop) : Math.max(1, h);
      const step = Math.min(chapters, Math.max(0, -(rect?.top ?? 0) / unit));
      const target = closing ? 3 : controls.current.level ?? journeyStage(step);
      if (reduced) renderedStage = controls.current.level ?? 3;
      else renderedStage += (target - renderedStage) * (interactive ? .09 : 1);
      const p = renderedStage, state = cameraAt(p, controls.current.area);
      if(!reduced&&Math.abs(p-lastStage)<.004&&now-lastPaint<40)return;
      const lightAmount=interactive||reduced?1:clamp((p+.8)/1.3);
      canvas!.style.filter=`brightness(${interactive||reduced?1:.18+.82*clamp(p+1)})`;
      renderedDirection = reduced ? state.direction : mix(renderedDirection, state.direction, interactive ? .12 : 1);
      const camera = basis(renderedDirection);
      const ox = interactive || closing ? 0 : w * (w < 600 ? .02 : .19), oy = interactive || closing ? 0 : h * (w < 600 ? .22 : 0);
      const project = (v: typeof starDirection) => projectPoint(v, camera, state.zoom, w, h, ox, oy);
      const flareGroups:FlareGroup[]=[];
      ctx.clearRect(0, 0, w, h);
      lineCtx.clearRect(0,0,w,h);
      areas.forEach((v, i) => {
        const point = project(v); if (!point) return;
        const diameter = .30 * state.zoom * h * point.scale;
        if (diameter < 12 || point.x + diameter < 0 || point.x - diameter > w || point.y + diameter < 0 || point.y - diameter > h) return;
        const probe=project(norm(add(v,mul(artworkAxes(v).axisA,.01))));
        const rotation=probe?Math.atan2(probe.y-point.y,probe.x-point.x):0;
        // Keep each artwork upright on screen, turning it about its own supernova so the two stay aligned.
        const light=project(supernovaDirections[i]);
        let cx=point.x,cy=point.y;
        if(light){const dx=point.x-light.x,dy=point.y-light.y,c=Math.cos(-rotation),n=Math.sin(-rotation);cx=light.x+dx*c-dy*n;cy=light.y+dx*n+dy*c;}
        if (images[i].complete && images[i].naturalWidth && p>.6) { ctx.save(); ctx.translate(cx,cy); ctx.globalCompositeOperation = 'screen'; ctx.globalAlpha = .1*clamp(p-.6); ctx.drawImage(images[i], -diameter / 2, -diameter / 2, diameter, diameter); ctx.restore(); }
      });
      projects.forEach((projectData, k) => {
        if(lightAmount<=0)return;
        if (interactive && !(projectData.area === 2 && projectData.index === 0) && !(projectData.area === 0 && projectData.index === 0)) return;
        const center = project(projectData.center); if (!center) return;
        const size = .1 * state.zoom * h * center.scale;
        // Narrative only: one lone star first, its constellation blooms around it, neighbouring projects follow.
        const isMain = projectData.area === controls.current.area && projectData.index === 0;
        const bloom = interactive || closing ? 1 : isMain ? ease(clamp(p / .6)) : ease(clamp((p - .9) / .7));
        if (bloom <= 0 && !isMain) return;
        if (size < 3 || center.x + size < 0 || center.x - size > w || center.y + size < 0 || center.y - size > h) return;
        const pts = projectData.points.map(project);
        const groups=[0,1,2].map(mode=>({mode,radius:Math.max(3,size*.42)*Math.max(.001,bloom),stars:[] as Flare[]}));
        const soloStar:FlareGroup={mode:0,radius:Math.max(3,size*.42)*(1+.9*(1-bloom)),stars:[]};
        lineCtx.strokeStyle = `rgba(242,184,75,${.9*lightAmount*bloom})`; lineCtx.lineWidth = Math.max(.12, 4.2 * size / 1000);
        for (const [a, b] of bloom>.02?projectData.edges:[]) { const aa = pts[a], bb = pts[b]; if (!aa || !bb) continue; lineCtx.beginPath(); lineCtx.moveTo(aa.x, aa.y); lineCtx.lineTo(bb.x, bb.y); lineCtx.stroke(); }
        if(bloom>.5&&projectData.completed&&!reduced&&p>.45&&pts.every(Boolean))paintEnergy(lineCtx,pts as NonNullable<typeof pts[number]>[],projectData.edges,size,clock,k*.71);
        pts.forEach((point, i) => {
          if (!point) return;
          const populated = projectData.area === 2 && projectData.index === 0;
          const lit = interactive ? populated && i < 2 : projectData.completed || i < 2+(k%3);
          const nascent = interactive ? !populated || i > 2 : !lit&&i>3;
          const s = Math.min(13, Math.max(.7, size * (lit ? .019 : .012)));
          const flare={x:point.x,y:point.y,seed:[i/pts.length,k/32],count:lit?(i===0?4:3):0};
          if(isMain&&i===0&&bloom<1)soloStar.stars.push(flare);
          else if(bloom>.03)groups[nascent?2:lit?0:1].stars.push(flare);
          if(!engine&&(i===0||bloom>.3)) {
            if (nascent) { ctx.fillStyle = '#e9eefb'; ctx.beginPath(); ctx.arc(point.x, point.y, Math.max(.8, s * .55), 0, Math.PI * 2); ctx.fill(); }
            else star(point.x, point.y, s, lit, 0, i + k);
          }
        });
        if(soloStar.stars.length)flareGroups.push(soloStar);
        for(const group of groups)for(let start=0;start<group.stars.length;start+=16)flareGroups.push({...group,stars:group.stars.slice(start,start+16)});
        if (projectData.area === 2 && projectData.index === 0 && bloom > .3) { const pulse = projectData.points[1], a = project(pulse); if (a) { const x=a.x+size*.13,y=a.y+size*.06; flareGroups.push({mode:1,radius:Math.max(3,size*.42*.55),stars:[{x,y,seed:[.31,.72],count:3}]}); if(!engine)star(x,y,Math.max(.8,size*.012),false,0,k); } }
      });
      if (!engine){ctx.save();ctx.globalCompositeOperation='destination-over';ctx.drawImage(lineCanvas,0,0,w,h);ctx.restore();}
      if (now - lastPaint > 40 || Math.abs(p - lastStage) > .004) { engine?.draw(reduced ? 0 : clock, p, w, h, ox, oy, controls.current.area, renderedDirection,flareGroups,lineCanvas); lastPaint = now; lastStage = p; }
      root.dataset.stage = p.toFixed(2); root.dataset.renderer = engine ? 'galaxy-webgl2' : 'static'; root.classList.add('is-ready');
    }
    function frame(now: number) { raf = 0; if (!visible || document.hidden) { last = 0; return; } if (last) { clock += Math.min(.1, (now - last) / 1000); slow = now - last > 55 ? slow + 1 : Math.max(0, slow - 1); if (slow > 45 && quality > .55) { quality *= .8; slow = 0; resize(); } } last = now; draw(now); if (!reduced) raf = requestAnimationFrame(frame); }
    function schedule() { if (visible && !document.hidden && !raf) raf = requestAnimationFrame(frame); }
    function resize() { if (!root || !canvas || !overlay || !ctx) return; w = root.clientWidth; h = root.clientHeight; const dpr = Math.min(devicePixelRatio || 1, 2); lineCanvas.width=Math.round(w*dpr);lineCanvas.height=Math.round(h*dpr);lineCtx.setTransform(dpr,0,0,dpr,0,0); overlay.width = Math.round(w * dpr); overlay.height = Math.round(h * dpr); ctx.setTransform(dpr, 0, 0, dpr, 0, 0); // Render the sky at the screen's own density (not a fixed 1100px that CSS then stretches), within a pixel budget; `quality` backs off if frames stall.
      const ratio = Math.min(dpr * quality, Math.sqrt(2_400_000 / Math.max(1, w * h))); canvas.width = Math.max(1, Math.round(w * ratio)); canvas.height = Math.max(1, Math.round(h * ratio)); lastStage = -1; schedule(); }
    function visibility() { if (document.hidden) { cancelAnimationFrame(raf); raf = 0; last = 0; } else schedule(); }
    function changeMotion() { reduced = media.matches || !engine; lastStage = -1; schedule(); }
    function lost(event: Event) { event.preventDefault(); engine = null; canvas!.style.opacity = '0'; reduced = true; schedule(); }
    function restored() { engine = createSky(canvas!); canvas!.style.opacity = engine ? '1' : '0'; reduced = media.matches || !engine; lastStage = -1; schedule(); }
    const observer = new IntersectionObserver(([entry]) => { visible = entry.isIntersecting; if (visible) schedule(); else { cancelAnimationFrame(raf); raf = 0; last = 0; } }); observer.observe(root);
    const resizer = new ResizeObserver(resize); resizer.observe(root); resize(); redraw.current = schedule;
    window.addEventListener('scroll', schedule, { passive: true }); document.addEventListener('visibilitychange', visibility); media.addEventListener('change', changeMotion); canvas.addEventListener('webglcontextlost', lost); canvas.addEventListener('webglcontextrestored', restored);
    return () => { cancelAnimationFrame(raf); observer.disconnect(); resizer.disconnect(); engine?.dispose(); images.forEach(image => { image.onload = null; }); window.removeEventListener('scroll', schedule); document.removeEventListener('visibilitychange', visibility); media.removeEventListener('change', changeMotion); canvas.removeEventListener('webglcontextlost', lost); canvas.removeEventListener('webglcontextrestored', restored); redraw.current = () => { }; };
  }, [closing, interactive, lang]);
  return <div ref={rootRef} className={`galaxy-scene${closing ? ' is-closing' : ''}${interactive ? ' is-interactive' : ''}`} aria-hidden="true"><svg className="galaxy-fallback" viewBox="0 0 1000 800"><g fill="none" stroke="#f2b84b" strokeWidth=".8"><circle cx="650" cy="360" r="55" /><circle cx="650" cy="360" r="80" /><path d="M450 440 500 400 550 440 550 500 450 500Z M790 300 820 250 860 310 830 340Z" /></g><g fill="#f4f1e8">{[[450, 440], [500, 400], [550, 440], [550, 500], [450, 500], [650, 360], [790, 300], [820, 250], [860, 310], [830, 340]].map(([x, y], i) => <circle key={i} cx={x} cy={y} r="2" />)}</g></svg><canvas ref={glRef} className="galaxy-nebula" /><canvas ref={starsRef} className="galaxy-stars" /></div>;
}

export function GalaxyExplorer({ lang = 'it', shots }: { lang?: Lang; shots: string[] }) {
  const [level, setLevel] = useState(0);
  const [selectedArea, setSelectedArea] = useState(2);
  const [ready, setReady] = useState(false);
  useEffect(() => setReady(true), []);
  const labels = lang === 'it' ? ['Attività', 'Progetto', 'Area', 'Tutto il cielo'] : ['Activity', 'Project', 'Area', 'The whole sky'];
  const details = lang === 'it' ? ['Ho fatto il primo passo', 'Un progetto mio', 'Professionale', 'Otto aree di vita'] : ['I took the first step', 'A project of my own', 'Professional', 'Eight areas of life'];
  const shotIndex = level === 0 ? 2 : level === 1 ? 1 : 0;
  return <div className="explorer">
    <div className="level-controls" role="group" aria-label={lang === 'it' ? 'Scegli la prospettiva' : 'Choose a perspective'}>{labels.map((name, i) => <button key={name} type="button" disabled={!ready} aria-label={name} aria-pressed={level === i} onClick={() => { setLevel(i); if (i < 2) setSelectedArea(2); }}><span aria-hidden="true">0{i + 1}</span>{name}</button>)}</div>
    {level >= 2 && <div className="area-controls" role="group" aria-label={lang === 'it' ? 'Esplora le otto aree' : 'Explore the eight areas'}>{areaNames[lang].map((name, i) => <button key={name} type="button" aria-pressed={selectedArea === i} onClick={() => setSelectedArea(i)}>{name}</button>)}</div>}
    <div className="comparison"><div className="comparison-galaxy"><div className="pane-heading"><span>Galaxy</span><small>{lang === 'it' ? 'Lo stesso percorso, nel cielo' : 'The same journey, in the sky'}</small></div><div className="explorer-sky"><Galaxy lang={lang} level={level} area={selectedArea} interactive /></div><div className="explorer-caption" role="status">{level === 2 ? areaNames[lang][selectedArea] : details[level]}</div></div><figure className="comparison-sky"><div className="pane-heading"><span>Sky</span><small>{lang === 'it' ? 'Gli stessi dati, da cercare e rileggere' : 'The same data, to search and revisit'}</small></div><img src={shots[shotIndex]} alt={`${labels[level]} — Sky`} width="430" height="932" loading="lazy" /></figure></div><p className="demo-note">{lang === 'it' ? 'Anteprima interattiva di Galaxy e schermate attuali di Sky, con dati di esempio.' : 'An interactive preview of Galaxy and current Sky screens, with example data.'}</p>
  </div>;
}
