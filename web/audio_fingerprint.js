function runAudioTest() {
  const container = 'audio-results';
  document.getElementById(container).innerHTML = '<div class="result-item">Running...</div>';

  try {
    const AudioContext = window.AudioContext || window.webkitAudioContext;
    if (!AudioContext) {
      addResult(container, 'AudioContext', 'Not available', true);
      return;
    }

    const ctx = new AudioContext();
    addResult(container, 'AudioContext sample rate', ctx.sampleRate, null);
    addResult(container, 'AudioContext base latency', ctx.baseLatency || 'N/A', null);
    addResult(container, 'AudioContext output latency', ctx.outputLatency || 'N/A', null);
    addResult(container, 'AudioContext state', ctx.state, null);
    addResult(container, 'AudioContext max channels', ctx.destination.maxChannelCount || 'N/A', null);

    const oscillator = ctx.createOscillator();
    oscillator.type = 'sawtooth';
    oscillator.frequency.value = 440;

    const analyser = ctx.createAnalyser();
    analyser.fftSize = 2048;
    oscillator.connect(analyser);

    const gain = ctx.createGain();
    gain.gain.value = 0;
    analyser.connect(gain);
    gain.connect(ctx.destination);

    oscillator.start(0);

    const timeDomain = new Float32Array(analyser.fftSize);
    analyser.getFloatTimeDomainData(timeDomain);

    let sum = 0, sumSq = 0;
    for (let i = 0; i < timeDomain.length; i++) {
      sum += timeDomain[i];
      sumSq += timeDomain[i] * timeDomain[i];
    }
    const mean = sum / timeDomain.length;
    const rms = Math.sqrt(sumSq / timeDomain.length);

    addResult(container, 'Audio time domain mean', mean.toFixed(8), null);
    addResult(container, 'Audio time domain RMS', rms.toFixed(8), null);
    addResult(container, 'Audio time domain length', timeDomain.length, null);

    let hash = 0;
    for (let i = 0; i < Math.min(timeDomain.length, 500); i++) {
      hash = ((hash << 5) - hash) + Math.floor(timeDomain[i] * 1000);
      hash |= 0;
    }
    addResult(container, 'Audio fingerprint hash', '0x' + (hash >>> 0).toString(16).padStart(8, '0'), null);

    oscillator.stop(0);
    oscillator.disconnect();

    ctx.close();
  } catch (e) {
    addResult(container, 'Audio test error', e.toString(), true);
  }
}
