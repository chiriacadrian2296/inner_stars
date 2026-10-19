// SVG sources from assets/mascots, embedded so the Moon lab can be removed
// from public builds together with its artwork. Keep in sync with the SVG files.

const moonBodyOriginalSvg =
    r'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024">
  <defs>
    <radialGradient id="bodyGradient" cx="47%" cy="39%" r="61%">
      <stop offset="0%" stop-color="#E9FEFF"/>
      <stop offset="30%" stop-color="#9DEEFF"/>
      <stop offset="62%" stop-color="#4B9EF4"/>
      <stop offset="84%" stop-color="#2860CF"/>
      <stop offset="100%" stop-color="#173982"/>
    </radialGradient>
    <linearGradient id="rimGradient" x1="18%" y1="10%" x2="82%" y2="91%">
      <stop offset="0%" stop-color="#C9FAFF"/>
      <stop offset="38%" stop-color="#51CFFF"/>
      <stop offset="75%" stop-color="#386FE2"/>
      <stop offset="100%" stop-color="#162F73"/>
    </linearGradient>
    <linearGradient id="shineGradient" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#FFFFFF" stop-opacity="0.78"/>
      <stop offset="100%" stop-color="#C4F9FF" stop-opacity="0"/>
    </linearGradient>
  </defs>
  <circle cx="512" cy="512" r="424" fill="url(#rimGradient)"/>
  <circle cx="512" cy="512" r="411" fill="url(#bodyGradient)"/>
  <ellipse cx="649" cy="231" rx="151" ry="75" fill="url(#shineGradient)" transform="rotate(19 649 231)"/>
</svg>''';

const moonBodyAppSvg =
    r'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024">
  <defs>
    <radialGradient id="bodyGradient" cx="43%" cy="36%" r="66%">
      <stop offset="0%" stop-color="#7C8FC4"/>
      <stop offset="34%" stop-color="#44568A"/>
      <stop offset="70%" stop-color="#232C44"/>
      <stop offset="100%" stop-color="#0D1220"/>
    </radialGradient>
    <linearGradient id="rimGradient" x1="18%" y1="10%" x2="82%" y2="91%">
      <stop offset="0%" stop-color="#E9EEFB"/>
      <stop offset="30%" stop-color="#7C8FC4"/>
      <stop offset="72%" stop-color="#44568A"/>
      <stop offset="100%" stop-color="#161D30"/>
    </linearGradient>
    <linearGradient id="shineGradient" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#F4F1E8" stop-opacity="0.30"/>
      <stop offset="100%" stop-color="#F4F1E8" stop-opacity="0"/>
    </linearGradient>
  </defs>
  <circle cx="512" cy="512" r="424" fill="url(#rimGradient)"/>
  <circle cx="512" cy="512" r="411" fill="url(#bodyGradient)"/>
  <ellipse cx="649" cy="231" rx="151" ry="75" fill="url(#shineGradient)" transform="rotate(19 649 231)"/>
</svg>''';

const moonBodyGoldSvg =
    r'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024">
  <defs>
    <radialGradient id="bodyGradient" cx="47%" cy="39%" r="61%">
      <stop offset="0%" stop-color="#FFF8E7"/>
      <stop offset="30%" stop-color="#FBE6B0"/>
      <stop offset="62%" stop-color="#F2B84B"/>
      <stop offset="84%" stop-color="#CE8427"/>
      <stop offset="100%" stop-color="#75420E"/>
    </radialGradient>
    <linearGradient id="rimGradient" x1="18%" y1="10%" x2="82%" y2="91%">
      <stop offset="0%" stop-color="#FFF4D4"/>
      <stop offset="38%" stop-color="#F6C65F"/>
      <stop offset="75%" stop-color="#D88B29"/>
      <stop offset="100%" stop-color="#6D3B0B"/>
    </linearGradient>
    <linearGradient id="shineGradient" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#FFFFFF" stop-opacity="0.72"/>
      <stop offset="100%" stop-color="#FFF4D4" stop-opacity="0"/>
    </linearGradient>
  </defs>
  <circle cx="512" cy="512" r="424" fill="url(#rimGradient)"/>
  <circle cx="512" cy="512" r="411" fill="url(#bodyGradient)"/>
  <ellipse cx="649" cy="231" rx="151" ry="75" fill="url(#shineGradient)" transform="rotate(19 649 231)"/>
</svg>''';
