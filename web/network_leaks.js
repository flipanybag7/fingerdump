function runNetworkTest() {
  const container = 'network-results';
  document.getElementById(container).innerHTML = '<div class="result-item">Running...</div>';

  try {
    addResult(container, 'WebRTC available', typeof RTCPeerConnection !== 'undefined' ? 'Yes' : 'No', null);

    if (typeof RTCPeerConnection !== 'undefined') {
      const pc = new RTCPeerConnection({
        iceServers: [{ urls: ['stun:stun.l.google.com:19302'] }]
      });

      pc.onicecandidate = (e) => {
        if (e.candidate && e.candidate.candidate) {
          const match = e.candidate.candidate.match(/(\d+\.\d+\.\d+\.\d+)/);
          if (match) {
            addResult(container, 'WebRTC ICE candidate IP', match[1], true);
          }
        }
      };

      pc.createDataChannel('test');
      pc.createOffer()
        .then(offer => pc.setLocalDescription(offer))
        .catch(e => {});

      setTimeout(() => {
        pc.close();
        addResult(container, 'WebRTC test completed', 'ICE gathering finished', null);
      }, 3000);
    }

    const xhr = new XMLHttpRequest();
    xhr.open('GET', 'https://httpbin.org/headers', true);
    xhr.timeout = 5000;
    xhr.onload = function() {
      try {
        const resp = JSON.parse(xhr.responseText);
        if (resp.headers) {
          addResult(container, 'HTTP headers sent', JSON.stringify(resp.headers, null, 2), null);
          if (resp.headers['User-Agent']) {
            addResult(container, 'User-Agent header', resp.headers['User-Agent'], true);
          }
          if (resp.headers['X-Forwarded-For']) {
            addResult(container, 'X-Forwarded-For', resp.headers['X-Forwarded-For'], true);
          }
        }
      } catch (e) {
        addResult(container, 'HTTP header test', 'Parse error: ' + e.message, null);
      }
    };
    xhr.onerror = function() {
      addResult(container, 'HTTP header test', 'Request failed (expected from WKWebView CORS)', null);
    };
    xhr.send();

  } catch (e) {
    addResult(container, 'Network test error', e.toString(), true);
  }
}

function runNavigatorTest() {
  const container = 'navigator-results';
  document.getElementById(container).innerHTML = '<div class="result-item">Running...</div>';

  try {
    const nav = navigator;
    const props = [
      'userAgent', 'appVersion', 'platform', 'vendor', 'vendorSub',
      'product', 'productSub', 'language', 'languages', 'cookieEnabled',
      'doNotTrack', 'hardwareConcurrency', 'deviceMemory', 'maxTouchPoints',
      'onLine', 'webdriver', 'pdfViewerEnabled',
    ];

    for (const prop of props) {
      try {
        let val = nav[prop];
        if (val === undefined) val = 'undefined';
        else if (val === null) val = 'null';
        else if (Array.isArray(val)) val = val.join(', ');
        addResult(container, 'navigator.' + prop, String(val), null);
      } catch (e) {
        addResult(container, 'navigator.' + prop, 'Error: ' + e.message, null);
      }
    }

    const connection = nav.connection || nav.mozConnection || nav.webkitConnection;
    if (connection) {
      addResult(container, 'Network type', connection.type || 'N/A', null);
      addResult(container, 'Network effective type', connection.effectiveType || 'N/A', null);
      addResult(container, 'Network downlink', connection.downlink + ' Mbps', null);
      addResult(container, 'Network rtt', connection.rtt + ' ms', null);
    }

    if (nav.plugins && nav.plugins.length > 0) {
      const plugins = [];
      for (let i = 0; i < nav.plugins.length; i++) {
        plugins.push(nav.plugins[i].name);
      }
      addResult(container, 'Browser plugins', plugins.join(', '), null);
    } else {
      addResult(container, 'Browser plugins', 'none or not accessible (WKWebView)', null);
    }

    if (nav.mimeTypes && nav.mimeTypes.length > 0) {
      addResult(container, 'MIME types count', nav.mimeTypes.length, null);
    }

    addResult(container, 'Screen resolution', screen.width + 'x' + screen.height, null);
    addResult(container, 'Screen avail', screen.availWidth + 'x' + screen.availHeight, null);
    addResult(container, 'Screen color depth', screen.colorDepth, null);
    addResult(container, 'Screen pixel depth', screen.pixelDepth, null);
    addResult(container, 'Window inner size', window.innerWidth + 'x' + window.innerHeight, null);
    addResult(container, 'Window outer size', window.outerWidth + 'x' + window.outerHeight, null);
    addResult(container, 'Device pixel ratio', window.devicePixelRatio, null);

    if (typeof Intl !== 'undefined') {
      addResult(container, 'Intl.DateTimeFormat locale', Intl.DateTimeFormat().resolvedOptions().locale, null);
      addResult(container, 'Intl.DateTimeFormat timeZone', Intl.DateTimeFormat().resolvedOptions().timeZone, null);
      addResult(container, 'Intl.DateTimeFormat calendar', Intl.DateTimeFormat().resolvedOptions().calendar, null);
      addResult(container, 'Intl.DateTimeFormat numberingSystem', Intl.DateTimeFormat().resolvedOptions().numberingSystem, null);
    }

    const dateStr = new Date().toLocaleString();
    addResult(container, 'Date locale string', dateStr, null);

    addResult(container, 'Timezone offset', new Date().getTimezoneOffset() + ' mins', null);

    const tzGuess = Intl.DateTimeFormat ? Intl.DateTimeFormat().resolvedOptions().timeZone : 'N/A';
    addResult(container, 'Timezone (Intl)', tzGuess, null);

  } catch (e) {
    addResult(container, 'Navigator test error', e.toString(), true);
  }
}
