function runCanvasTest() {
  const container = 'canvas-results';
  document.getElementById(container).innerHTML = '<div class="result-item">Running...</div>';

  try {
    const canvas = document.getElementById('canvas');
    const ctx = canvas.getContext('2d');

    ctx.textBaseline = 'alphabetic';
    ctx.fillStyle = '#f60';
    ctx.fillRect(125, 1, 62, 20);
    ctx.fillStyle = '#069';
    ctx.fillText('Cwm fjordbank glyphs vext quiz, \ud83d\udca8', 2, 15);
    ctx.fillStyle = 'rgba(102, 204, 0, 0.7)';
    ctx.font = '18pt Arial';
    ctx.fillText('Cwm fjordbank glyphs vext quiz, \ud83d\udca8', 4, 45);
    ctx.globalCompositeOperation = 'multiply';
    ctx.fillStyle = 'rgb(255,0,255)';
    ctx.beginPath();
    ctx.arc(50, 50, 50, 0, Math.PI * 2, true);
    ctx.fill();
    ctx.fillStyle = 'rgb(0,255,255)';
    ctx.beginPath();
    ctx.arc(100, 50, 50, 0, Math.PI * 2, false);
    ctx.fill();
    ctx.fillStyle = 'rgb(255,255,0)';
    ctx.beginPath();
    ctx.arc(75, 100, 50, 0, Math.PI * 2, true);
    ctx.fill();

    ctx.fillStyle = '#0af';
    ctx.font = 'bold 12pt Courier';
    ctx.fillText('ABCDEFGHIJKLMNOPQRSTUVWXYZ', 2, 85);
    ctx.fillText('abcdefghijklmnopqrstuvwxyz', 2, 100);
    ctx.fillText('0123456789.,:;!?@#$%^&*()', 2, 115);

    const dataUrl = canvas.toDataURL();

    addResult(container, 'Canvas data URL length', dataUrl.length + ' chars', null);
    addResult(container, 'Canvas hash (first 64 chars)', dataUrl.substring(0, 64) + '...', null);

    let hash = 0;
    for (let i = 0; i < dataUrl.length; i++) {
      const char = dataUrl.charCodeAt(i);
      hash = ((hash << 5) - hash) + char;
      hash |= 0;
    }
    addResult(container, 'Canvas fingerprint hash', '0x' + (hash >>> 0).toString(16).padStart(8, '0'), null);

    const imageData = ctx.getImageData(0, 0, 256, 256);
    let pixelSum = 0;
    for (let i = 0; i < 1000; i++) pixelSum += imageData.data[i];
    addResult(container, 'Canvas pixel data checksum', pixelSum.toString(), null);

    toDataURL = canvas.toDataURL.bind(canvas)();
    addResult(container, 'Canvas fingerprint (full)', toDataURL.length > 200 ? toDataURL.substring(0, 200) + '...' : toDataURL, null);

    const glCanvas = document.getElementById('webgl-canvas');
    const gl = glCanvas.getContext('webgl') || glCanvas.getContext('experimental-webgl');
    if (gl) {
      addResult(container, 'WebGL available', 'Yes', null);
      addResult(container, 'WebGL renderer', gl.getParameter(gl.RENDERER), null);
      addResult(container, 'WebGL vendor', gl.getParameter(gl.VENDOR), null);
      addResult(container, 'WebGL version', gl.getParameter(gl.VERSION), null);
      addResult(container, 'WebGL shading language version', gl.getParameter(gl.SHADING_LANGUAGE_VERSION), null);
    }
  } catch (e) {
    addResult(container, 'Canvas test error', e.toString(), true);
  }
}
