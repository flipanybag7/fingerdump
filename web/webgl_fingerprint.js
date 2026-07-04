function runWebGLTest() {
  const container = 'webgl-results';
  document.getElementById(container).innerHTML = '<div class="result-item">Running...</div>';

  try {
    const canvas = document.getElementById('webgl-canvas');
    const gl = canvas.getContext('webgl2') || canvas.getContext('webgl') || canvas.getContext('experimental-webgl');

    if (!gl) {
      addResult(container, 'WebGL', 'Not available', true);
      return;
    }

    addResult(container, 'WebGL type', gl instanceof WebGL2RenderingContext ? 'WebGL 2' : 'WebGL 1', null);

    const params = {
      'RENDERER': gl.RENDERER,
      'VENDOR': gl.VENDOR,
      'VERSION': gl.VERSION,
      'SHADING_LANGUAGE_VERSION': gl.SHADING_LANGUAGE_VERSION,
      'MAX_TEXTURE_SIZE': gl.MAX_TEXTURE_SIZE,
      'MAX_CUBE_MAP_TEXTURE_SIZE': gl.MAX_CUBE_MAP_TEXTURE_SIZE,
      'MAX_RENDERBUFFER_SIZE': gl.MAX_RENDERBUFFER_SIZE,
      'MAX_TEXTURE_IMAGE_UNITS': gl.MAX_TEXTURE_IMAGE_UNITS,
      'MAX_VERTEX_TEXTURE_IMAGE_UNITS': gl.MAX_VERTEX_TEXTURE_IMAGE_UNITS,
      'MAX_COMBINED_TEXTURE_IMAGE_UNITS': gl.MAX_COMBINED_TEXTURE_IMAGE_UNITS,
      'MAX_VERTEX_ATTRIBS': gl.MAX_VERTEX_ATTRIBS,
      'MAX_VARYING_VECTORS': gl.MAX_VARYING_VECTORS,
      'MAX_VERTEX_UNIFORM_VECTORS': gl.MAX_VERTEX_UNIFORM_VECTORS,
      'MAX_FRAGMENT_UNIFORM_VECTORS': gl.MAX_FRAGMENT_UNIFORM_VECTORS,
      'MAX_VIEWPORT_DIMS': gl.MAX_VIEWPORT_DIMS,
      'ALIASED_POINT_SIZE_RANGE': gl.ALIASED_POINT_SIZE_RANGE,
      'ALIASED_LINE_WIDTH_RANGE': gl.ALIASED_LINE_WIDTH_RANGE,
      'MAX_TEXTURE_MAX_ANISOTROPY_EXT': 0x84FF,
    };

    for (const [name, param] of Object.entries(params)) {
      try {
        let value;
        if (name === 'MAX_TEXTURE_MAX_ANISOTROPY_EXT') {
          const ext = gl.getExtension('EXT_texture_filter_anisotropic');
          if (ext) value = gl.getParameter(ext.MAX_TEXTURE_MAX_ANISOTROPY_EXT);
          else value = 'N/A (extension not supported)';
        } else {
          value = gl.getParameter(param);
        }
        addResult(container, name, Array.isArray(value) ? value.join(', ') : value, null);
      } catch (e) {
        addResult(container, name, 'Error: ' + e.message, null);
      }
    }

    const extensions = gl.getSupportedExtensions();
    if (extensions) {
      addResult(container, 'Supported extensions', extensions.length + ' extensions', null);
      addResult(container, 'Extensions (first 20)', Array.from(extensions).slice(0, 20).join(', '), null);
    }

    const vertexSrc = 'attribute vec3 pos;void main(){gl_Position=vec4(pos,1.0);}';
    const fragmentSrc = 'precision mediump float;uniform vec4 color;void main(){gl_FragColor=color;}';

    const vs = gl.createShader(gl.VERTEX_SHADER);
    gl.shaderSource(vs, vertexSrc);
    gl.compileShader(vs);

    const fs = gl.createShader(gl.FRAGMENT_SHADER);
    gl.shaderSource(fs, fragmentSrc);
    gl.compileShader(fs);

    const prog = gl.createProgram();
    gl.attachShader(prog, vs);
    gl.attachShader(prog, fs);
    gl.linkProgram(prog);

    addResult(container, 'Shader compile (VS)', gl.getShaderInfoLog(vs) || 'OK', null);
    addResult(container, 'Shader compile (FS)', gl.getShaderInfoLog(fs) || 'OK', null);
    addResult(container, 'Program link', gl.getProgramInfoLog(prog) || 'OK', null);

    const verts = new Float32Array([-1,-1,0, 1,-1,0, 0,1,0]);
    const buf = gl.createBuffer();
    gl.bindBuffer(gl.ARRAY_BUFFER, buf);
    gl.bufferData(gl.ARRAY_BUFFER, verts, gl.STATIC_DRAW);

    gl.useProgram(prog);
    const posAttr = gl.getAttribLocation(prog, 'pos');
    gl.enableVertexAttribArray(posAttr);
    gl.vertexAttribPointer(posAttr, 3, gl.FLOAT, false, 0, 0);
    gl.uniform4f(gl.getUniformLocation(prog, 'color'), 1, 0, 0, 1);
    gl.viewport(0, 0, 256, 256);
    gl.clearColor(0, 0, 0, 1);
    gl.clear(gl.COLOR_BUFFER_BIT);
    gl.drawArrays(gl.TRIANGLES, 0, 3);

    const pixels = new Uint8Array(4);
    gl.readPixels(0, 0, 1, 1, gl.RGBA, gl.UNSIGNED_BYTE, pixels);
    addResult(container, 'WebGL render test pixel (0,0)', Array.from(pixels).join(', '), null);

  } catch (e) {
    addResult(container, 'WebGL test error', e.toString(), true);
  }
}
