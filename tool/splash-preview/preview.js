const canvas = document.querySelector('#sky');
const ctx = canvas.getContext('2d');
const mark = document.querySelector('.mark');
const identity = document.querySelector('.identity');
const veil = document.querySelector('.veil');
const label = document.querySelector('.galaxy-label');
const menu = document.querySelector('.menu-star');
const phase = document.querySelector('#phase');
const reduced = document.querySelector('#reduced');
const loading = document.querySelector('#loading');
const descriptions = {
  ignition: 'Logo originale, un alone radiale e una dissolvenza. La proposta più semplice da portare nell’app.',
  nebula: 'Aloni blu e oro sullo sfondo. Un bagliore dorato segue la sagoma del logo e cresce durante l’attesa; tutto sfuma quando Galaxy è pronto.',
  constellation: 'Dodici punti convergono nel logo originale. Più narrativo: negli avvii rapidi il gesto viene abbreviato.',
};
const motionPreference = matchMedia('(prefers-reduced-motion: reduce)');
reduced.checked = motionPreference.matches;
motionPreference.addEventListener('change', e => { reduced.checked = e.matches; play(); });
let variant = 'nebula', frame = 0;
const clamp = x => Math.max(0, Math.min(1, x));
const ease = x => { x = clamp(x); return x * x * (3 - 2 * x); };
// Fixed layout makes changes of direction comparable on every replay.
const stars = Array.from({length: 95}, (_, i) => ({x: ((i * 137.508 + 39) % 390), y: ((i * 213.73 + 71) % 790), r: i % 11 === 0 ? 1.5 : .55, a: .18 + (i % 7) * .09}));
function glow(x, y, radius, color, alpha) {
  ctx.save(); ctx.globalAlpha = clamp(alpha);
  const g = ctx.createRadialGradient(x,y,0,x,y,radius);
  g.addColorStop(0,color); g.addColorStop(1,'transparent');
  ctx.fillStyle = g; ctx.fillRect(x-radius,y-radius,radius*2,radius*2); ctx.restore();
}
function paint(t, reveal, quiet) {
  ctx.clearRect(0,0,390,790);
  const atmosphere = variant === 'nebula' ? ease(t / 1000) * (1-reveal) : 0;
  glow(110,330,270,'#34538b',atmosphere*.75 + reveal*.5);
  glow(285,430,220,'#72512e',atmosphere*.5 + reveal*.3);
  for (const s of stars) {
    ctx.globalAlpha = s.a * (reveal + atmosphere*.6);
    ctx.fillStyle = '#e9e4d9'; ctx.beginPath(); ctx.arc(s.x,s.y,s.r,0,Math.PI*2);ctx.fill();
  }
  ctx.globalAlpha = 1;
  if (variant === 'ignition') {
    const ignition = quiet ? .35 : ease(t/650) * (.62 + .06*Math.sin(t/850));
    glow(195,335,135,'#bd812f',ignition*(1-reveal));
    glow(195,335,47,'#f2b84b',ignition*.22*(1-reveal));
  }
  if (variant === 'constellation') {
    const p = quiet ? 1 : ease(t/1400);
    for(let i=0;i<12;i++){
      const angle = i*2.399;
      const radius = 135*(1-p)+22;
      const x = 195+Math.cos(angle)*radius;
      const y = 335+Math.sin(angle)*radius*1.3;
      glow(x,y,13,'#f2b84b',ease(t/300)*(1-ease((p-.7)/.3))*(1-reveal));
      ctx.globalAlpha = (1-p)*(1-reveal); ctx.fillStyle='#f2b84b';
      ctx.beginPath();ctx.arc(x,y,1.6,0,Math.PI*2);ctx.fill();
    }
  }
  // Illustrative destination only; integration will reveal the actual Galaxy.
  const points = [[80,235],[142,195],[206,250],[254,199],[302,275]];
  ctx.globalAlpha = reveal*.3;ctx.strokeStyle='#e0b56f';ctx.lineWidth=.6;ctx.beginPath();
  points.forEach(([x,y],i) => i ? ctx.lineTo(x,y) : ctx.moveTo(x,y));ctx.stroke();ctx.globalAlpha=1;
  for(const [x,y] of points){glow(x,y,24,'#e3a84b',reveal*.5);ctx.globalAlpha=reveal;ctx.fillStyle='#f5d49b';ctx.beginPath();ctx.arc(x,y,1.8,0,Math.PI*2);ctx.fill();}
  ctx.globalAlpha=1;
}
function play(){
  cancelAnimationFrame(frame);
  const bounds=canvas.getBoundingClientRect(), dpr=Math.min(devicePixelRatio||1,2);
  canvas.width=Math.round(bounds.width*dpr);canvas.height=Math.round(bounds.height*dpr);
  ctx.setTransform(canvas.width/390,0,0,canvas.height/790,0,0);
  const start=performance.now(), ready=Number(loading.value), quiet=reduced.checked;
  let lastPhase='';
  const tick=now=>{
    const t=now-start, reveal=ease((t-ready)/(quiet?200:500));
    veil.style.opacity=String(1-reveal);
    // Paint the effects above the solid veil without another compositing layer.
    canvas.style.zIndex='1';veil.style.zIndex='0';
    identity.style.opacity=String(1-reveal);
    const entrance=quiet?1:ease(t/650);
    const logoIn=variant==='constellation'&&!quiet?ease((t-450)/850):entrance;
    mark.style.opacity=String(logoIn);
    mark.style.transform=quiet?'none':`scale(${.92+.08*logoIn+.035*reveal})`;
    // Shadows use the SVG alpha silhouette, preserving the original logo shape.
    // The simulated ready time drives this study, not a measured load percentage.
    const charge=quiet ? .65 : ease(t/ready);
    mark.style.filter=variant==='nebula'
      ? `drop-shadow(0 0 ${2+5*charge}px rgba(255,204,112,${.2+.65*charge})) drop-shadow(0 0 ${6+19*charge}px rgba(242,184,75,${.08+.62*charge}))`
      : 'none';
    document.querySelector('.wordmark').style.opacity=String(entrance);
    document.querySelector('.tagline').style.opacity=String(quiet?1:ease((t-200)/600));
    label.style.opacity=String(reveal);menu.style.opacity=String(reveal);
    paint(t,reveal,quiet);
    const current=t<ready?(t<700?'Accensione':'In attesa di Galaxy'):reveal<1?'Ingresso in Galaxy':'Galaxy pronto';
    if(current!==lastPhase){phase.textContent=current;lastPhase=current;}
    if(reveal<1)frame=requestAnimationFrame(tick);
  };
  frame=requestAnimationFrame(tick);
}
document.querySelectorAll('[data-variant]').forEach(button=>button.addEventListener('click',()=>{
  variant=button.dataset.variant;
  document.querySelectorAll('[data-variant]').forEach(b=>b.setAttribute('aria-pressed',String(b===button)));
  document.querySelector('#description').textContent=descriptions[variant];play();
}));
document.querySelector('#replay').addEventListener('click',play);
loading.addEventListener('change',play);reduced.addEventListener('change',play);
document.addEventListener('visibilitychange',()=>{if(document.hidden)cancelAnimationFrame(frame);else play();});
let resizeTimer;window.addEventListener('resize',()=>{clearTimeout(resizeTimer);resizeTimer=setTimeout(play,150);});
document.querySelector('#description').textContent=descriptions[variant];
document.fonts.ready.then(play);
