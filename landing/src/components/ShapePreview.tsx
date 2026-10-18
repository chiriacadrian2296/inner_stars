import { useState } from 'react';
import type { Lang } from '../i18n/types';
// Exact grids and edges from the app's constellation_presets.dart.
const shapes = [
  { it: 'Montagna', en: 'Mountain', points: [[0, 10], [3, 3], [5, 6], [7, 1], [10, 10]], edges: [[0, 1], [1, 2], [2, 3], [3, 4], [4, 0]] },
  { it: 'Albero', en: 'Tree', points: [[5, 10], [5, 7], [2, 7], [8, 7], [3, 4], [7, 4], [5, 1]], edges: [[0, 1], [1, 2], [2, 4], [4, 6], [6, 5], [5, 3], [3, 1]] },
];
export default function ShapePreview({ lang = 'it' }: { lang?: Lang }) {
  const [selected, setSelected] = useState(0); const shape = shapes[selected];
  return <div className="shape-demo"><div className="shape-controls" role="group" aria-label={lang === 'it' ? 'Scegli una forma' : 'Choose a shape'}>{shapes.map((s, i) => <button type="button" key={s.en} onClick={() => setSelected(i)} aria-pressed={selected === i}>{s[lang]}</button>)}</div><svg viewBox="-1 -1 12 13" role="img" aria-label={shape[lang]}>{shape.edges.map(([a, b], i) => <line key={i} x1={shape.points[a][0]} y1={shape.points[a][1]} x2={shape.points[b][0]} y2={shape.points[b][1]} stroke="#7c8699" strokeWidth=".035" />)}{shape.points.map(([x, y], i) => <circle key={i} cx={x} cy={y} r=".095" fill={i < 2 ? '#f2b84b' : '#e9eefb'} />)}</svg><p className="shape-note" role="status">{lang === 'it' ? `Anteprima: ${shape.it}. Nell’app scegli una forma o disegna la tua.` : `Preview: ${shape.en}. In the app, choose a shape or draw your own.`}</p></div>;
}
