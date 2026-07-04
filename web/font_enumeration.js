function runFontTest() {
  const container = 'font-results';
  document.getElementById(container).innerHTML = '<div class="result-item">Running...</div>';

  try {
    const fontCheck = [
      'Arial', 'Arial Black', 'Arial Narrow', 'Arimo', 'Baskerville',
      'Big Caslon', 'Bodoni MT', 'Book Antiqua', 'Bookman', 'Calibri',
      'Cambria', 'Candara', 'Century Gothic', 'Century Schoolbook',
      'Charcoal', 'Chalkboard', 'Chalkduster', 'Cochin', 'Comic Sans MS',
      'Consolas', 'Constantia', 'Copperplate', 'Corbel', 'Courier New',
      'Didot', 'DIN Alternate', 'DIN Next', 'Futura', 'Garamond',
      'Geneva', 'Georgia', 'Gill Sans', 'Goudy Old Style', 'Helvetica',
      'Helvetica Neue', 'Hoefler Text', 'Impact', 'Lucida Bright',
      'Lucida Console', 'Lucida Grande', 'Lucida Sans', 'Marker Felt',
      'Menlo', 'Microsoft Sans Serif', 'Monaco', 'Montserrat',
      'MS Gothic', 'MS PGothic', 'Myanmar Text', 'Noto Sans',
      'Noto Serif', 'Open Sans', 'Optima', 'Palatino', 'Palatino Linotype',
      'Papyrus', 'Perpetua', 'Playfair Display', 'Poppins', 'Raleway',
      'Roboto', 'Rockwell', 'San Francisco', 'Segoe UI', 'Skia',
      'Snell Roundhand', 'Source Sans Pro', 'STIX', 'Tahoma', 'Times',
      'Times New Roman', 'Trebuchet MS', 'Ubuntu', 'Verdana',
      'Zapfino', 'Apple Color Emoji', 'Apple SD Gothic Neo',
      'Apple Symbols', 'SF Mono', 'SF Pro', 'SF Compact',
    ];

    const baseFonts = ['monospace', 'sans-serif', 'serif'];
    const testString = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!@#$%^&*()_+-=[]{}|;:,.<>?/~`';
    const testSize = '72px';

    const testDiv = document.createElement('div');
    testDiv.style.position = 'absolute';
    testDiv.style.left = '-9999px';
    testDiv.style.visibility = 'hidden';
    document.body.appendChild(testDiv);

    const defaultWidths = {};
    const defaultHeight = {};

    for (const base of baseFonts) {
      testDiv.style.fontFamily = base;
      testDiv.style.fontSize = testSize;
      testDiv.textContent = testString;
      defaultWidths[base] = testDiv.offsetWidth;
      defaultHeight[base] = testDiv.offsetHeight;
    }

    const available = [];
    for (const font of fontCheck) {
      let detected = false;
      for (const base of baseFonts) {
        testDiv.style.fontFamily = `"${font}", ${base}`;
        testDiv.style.fontSize = testSize;
        testDiv.textContent = testString;
        if (testDiv.offsetWidth !== defaultWidths[base] || testDiv.offsetHeight !== defaultHeight[base]) {
          detected = true;
          break;
        }
      }
      if (detected) available.push(font);
    }

    document.body.removeChild(testDiv);

    addResult(container, 'Font enumeration method', 'Width/height comparison', null);
    addResult(container, 'Detected fonts', available.length + ' found out of ' + fontCheck.length + ' tested', null);
    addResult(container, 'Available fonts', available.join(', '), null);

    const missing = fontCheck.filter(f => !available.includes(f));
    addResult(container, 'Missing fonts', missing.length + ' not found: ' + missing.join(', '), null);

  } catch (e) {
    addResult(container, 'Font test error', e.toString(), true);
  }
}
