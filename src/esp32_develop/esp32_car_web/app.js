/* ============================================================================
 * RoboCar-A Web Console
 * Standalone browser controller — local WebSocket control + MJPEG + OTA.
 * Protocol mirrors the Flutter app (lib/models/car_state.dart).
 * ========================================================================== */
'use strict';

/* ── Tunables ────────────────────────────────────────────────────────────── */
// Default encoder pulses (avg per wheel) for a 180° in-place turn. This is sent
// to the firmware so the turn is closed-loop on the encoders. Calibrate live in
// the 设备管理 panel — no firmware reflash needed.
const DEFAULT_TURN_COUNTS_180 = 10500;

/* ── DOM helpers ─────────────────────────────────────────────────────────── */
const $ = (id) => document.getElementById(id);

/* ── Persistent settings ─────────────────────────────────────────────────── */
const LS = {
  get: (k, d) => { try { const v = localStorage.getItem(k); return v === null ? d : v; } catch { return d; } },
  set: (k, v) => { try { localStorage.setItem(k, v); } catch {} },
};

/* ── Global state ────────────────────────────────────────────────────────── */
const state = {
  ws: null,
  connected: false,
  connecting: false,
  manualDisconnect: false,
  gen: 0,                 // connection generation — rejects stale async callbacks
  ip: '',
  camIp: '',
  // telemetry
  battery: 0,             // raw voltage
  voltMult: parseFloat(LS.get('voltMult', '1')) || 1,
  dist: 0, rssi: 0, ssid: '--', mac: '--', fw: '--', camFw: '--',
  uptimeSec: 0,
  latency: 0,
  // control
  speed: parseInt(LS.get('speed', '80'), 10) || 80,
  light: false, horn: false, auto: false,
  pan: 90, tilt: 35,
  rotVal: 0,              // -1..1 rotation (vw), combined with translation
  turning: false,         // one-key turnaround in progress
  turnTimer: null,
  turnCounts: parseInt(LS.get('turnCounts', String(DEFAULT_TURN_COUNTS_180)), 10) || DEFAULT_TURN_COUNTS_180,
  speedDebounce: null,
  // camera
  camActive: false, camUrl: '', camRetryTimer: null,
  camQuality: LS.get('camQuality', 'low'),
  // timers
  pollTimer: null, uptimeTimer: null, reconnectTimer: null, timeoutTimer: null,
  latencyStart: 0,
};

/* ── Toast ───────────────────────────────────────────────────────────────── */
let toastTimer = null;
function toast(msg) {
  const t = $('toast');
  t.textContent = msg;
  t.classList.add('show');
  clearTimeout(toastTimer);
  toastTimer = setTimeout(() => t.classList.remove('show'), 2600);
}

/* ── Connection ──────────────────────────────────────────────────────────── */
function connect() {
  const ip = $('ipInput').value.trim();
  if (!ip) { toast('请输入小车 IP 地址'); return; }
  state.ip = ip;
  state.camIp = $('camIpInput').value.trim();
  LS.set('ip', ip);
  LS.set('camIp', state.camIp);

  cleanupConnection();
  state.manualDisconnect = false;
  state.connecting = true;
  state.connected = false;
  state.latency = 0;
  updateConnUI();

  const myGen = ++state.gen;
  const url = `ws://${ip}:80/ws`;

  // connection timeout (10s)
  clearTimeout(state.timeoutTimer);
  state.timeoutTimer = setTimeout(() => {
    if (state.gen !== myGen) return;
    if (state.connecting && !state.connected) {
      console.warn('[WS] connect timeout');
      handleUnexpectedDisconnect('timeout');
    }
  }, 10000);

  try {
    state.ws = new WebSocket(url);
  } catch (e) {
    handleUnexpectedDisconnect('setup_failed');
    return;
  }

  state.ws.onopen = () => {
    if (state.gen !== myGen) return;
    console.log('[WS] open', url);
    sendStatus();          // trigger handshake
  };
  state.ws.onmessage = (ev) => {
    if (state.gen !== myGen) return;
    handleMessage(ev.data);
  };
  state.ws.onclose = () => {
    if (state.gen !== myGen) return;
    console.log('[WS] close');
    if (!state.manualDisconnect) handleUnexpectedDisconnect('close');
    else cleanupConnection();
  };
  state.ws.onerror = (e) => {
    if (state.gen !== myGen) return;
    console.warn('[WS] error', e);
    if (!state.manualDisconnect) handleUnexpectedDisconnect('error');
  };
}

function disconnect() {
  state.manualDisconnect = true;
  state.gen++;                       // invalidate pending callbacks
  const ws = state.ws;
  state.ws = null;
  try { ws && ws.close(); } catch {}
  cleanupConnection();
  toast('已断开连接');
}

function cleanupConnection() {
  try { state.ws && state.ws.close(); } catch {}
  state.ws = null;
  state.connected = false;
  state.connecting = false;
  clearTimeout(state.timeoutTimer);
  clearTimeout(state.reconnectTimer);
  clearInterval(state.pollTimer);
  clearInterval(state.uptimeTimer);
  state.pollTimer = state.uptimeTimer = null;
  state.latency = 0;
  state.uptimeSec = 0;
  stopCamera();
  updateConnUI();
  renderTelemetry();
}

function handleUnexpectedDisconnect(reason) {
  console.warn('[Connection] unexpected disconnect:', reason);
  cleanupConnection();
  if (!state.manualDisconnect && state.ip) {
    clearTimeout(state.reconnectTimer);
    state.reconnectTimer = setTimeout(() => {
      if (!state.manualDisconnect && state.ip) {
        toast('正在重连…');
        connect();
      }
    }, 3000);
  }
}

function confirmConnected() {
  if (state.connected) return;
  state.connecting = false;
  state.connected = true;
  clearTimeout(state.timeoutTimer);
  startPolling();
  startUptime();
  startCamera();
  sendSpeed(state.speed);            // sync firmware max speed with slider
  updateConnUI();
  toast('连接成功');
}

/* ── Messaging ───────────────────────────────────────────────────────────── */
function handleMessage(raw) {
  let data;
  try { data = JSON.parse(raw); } catch { return; }

  // latency from any reply
  if (state.latencyStart) {
    state.latency = Date.now() - state.latencyStart;
    state.latencyStart = 0;
  }

  // handshake: accept welcome / status / any telemetry payload
  if (state.connecting) {
    if (data.mac || data.type === 'welcome' || data.type === 'status' || data.bat != null || data.v_car != null) {
      confirmConnected();
    }
  }

  // telemetry
  if (data.mac != null) state.mac = data.mac;
  if (data.bat != null) state.battery = Number(data.bat);
  if (data.v_car != null) state.battery = Number(data.v_car);
  if (data.dist != null) state.dist = Number(data.dist);
  if (data.rssi != null) state.rssi = Number(data.rssi);
  if (data.ssid && data.ssid !== 'Unknown') state.ssid = data.ssid;
  if (data.version != null) state.fw = data.version;
  if (data.cam_version != null) state.camFw = data.cam_version;
  const camIp = data.cam_ip || data.camIP;
  if (camIp && camIp !== 'null' && !$('camIpInput').value.trim()) {
    const newCam = String(camIp);
    // Only (re)start the stream when the camera IP actually changes,
    // otherwise the 2s status poll would reset the MJPEG stream constantly.
    if (newCam !== state.camIp) {
      state.camIp = newCam;
      if (state.connected) startCamera(true);
    }
  }

  // special types
  if (data.type === 'scan_results') {
    renderWifiList(data.networks || []);
  } else if (data.type === 'wifi_status' || data.type === 'status_reset') {
    if (data.res === 'ok') $('wifiStatus').textContent = '✅ WiFi 配置成功，设备正在切换网络…';
    else if (data.res === 'error') $('wifiStatus').textContent = '❌ WiFi 连接失败：' + (data.msg || '未知错误');
  }

  renderTelemetry();
}

function send(obj) {
  if (!state.connected || !state.ws) return false;
  try { state.ws.send(JSON.stringify(obj)); return true; }
  catch { return false; }
}
function sendStatus() {
  if ((state.connected || state.connecting) && state.ws) {
    state.latencyStart = Date.now();
    try { state.ws.send(JSON.stringify({ cmd: 'status' })); } catch {}
  }
}

function startPolling() {
  clearInterval(state.pollTimer);
  sendStatus();
  state.pollTimer = setInterval(sendStatus, 2000);
}
function startUptime() {
  clearInterval(state.uptimeTimer);
  state.uptimeTimer = setInterval(() => {
    if (state.connected) { state.uptimeSec++; renderTelemetry(); }
  }, 1000);
}

/* ── Telemetry rendering ─────────────────────────────────────────────────── */
function batteryPct() {
  const v = state.battery * state.voltMult;
  if (!v) return 0;
  return Math.min(100, Math.max(0, Math.round((v - 10.5) / 2.1 * 100)));
}
function fmtUptime(s) {
  const h = String(Math.floor(s / 3600)).padStart(2, '0');
  const m = String(Math.floor((s % 3600) / 60)).padStart(2, '0');
  const sec = String(s % 60).padStart(2, '0');
  return `${h}:${m}:${sec}`;
}
function renderTelemetry() {
  const pct = batteryPct();
  const v = (state.battery * state.voltMult).toFixed(1);
  $('batPct').textContent = state.connected ? pct : '--';
  $('batVolt').textContent = state.connected ? `${v} V` : '-- V';
  const fill = $('batFill');
  fill.style.width = (state.connected ? pct : 0) + '%';
  fill.style.background = pct <= 20
    ? 'linear-gradient(90deg,#FB7185,#EF4444)'
    : 'linear-gradient(90deg,#4ADE80,#22C55E)';

  $('tmDist').textContent = state.connected ? `${state.dist} cm` : '-- cm';
  $('tmRssi').textContent = state.connected ? `${state.rssi} dBm` : '-- dBm';
  $('tmLatency').textContent = state.connected ? `${state.latency} ms` : '-- ms';
  $('tmUptime').textContent = state.connected ? fmtUptime(state.uptimeSec) : '00:00:00';
  $('tmSsid').textContent = state.ssid;
  $('tmMac').textContent = state.mac;
  $('tmFw').textContent = state.fw;
  $('tmCamFw').textContent = state.camFw;
  $('calibCurrent').textContent = `当前系数 ×${state.voltMult.toFixed(3)}`;
}

function updateConnUI() {
  const pill = $('connPill');
  const text = $('connText');
  pill.classList.toggle('connected', state.connected);
  text.textContent = state.connected ? '已连接' : (state.connecting ? '连接中…' : '未连接');
  $('connectBtn').textContent = (state.connected || state.connecting) ? '断开' : '连接';
}

/* ── Camera ──────────────────────────────────────────────────────────────── */
function camStreamUrl() {
  const cam = state.camIp || state.ip;
  return cam ? `http://${cam}:81/stream` : '';
}
// ESP32-CAM /control presets. Lower framesize + higher quality number = less
// data per frame = lower latency. framesize: 5=QVGA(320x240) 8=VGA 9=SVGA.
// quality: bigger number = more JPEG compression (smaller/faster), range ~10-30.
const CAM_PRESETS = {
  low:  { framesize: 5, quality: 18 },  // 流畅 · 低延时
  mid:  { framesize: 8, quality: 12 },  // 均衡
  high: { framesize: 9, quality: 10 },  // 清晰
};
// Fire-and-forget GET to the cam control endpoint (port 80). no-cors: we don't
// need the response, just the side effect — this sidesteps CORS entirely.
function camControl(varName, val) {
  const cam = state.camIp || state.ip;
  if (!cam) return;
  fetch(`http://${cam}/control?var=${varName}&val=${val}`, { mode: 'no-cors' }).catch(() => {});
}
function applyCamPreset(name, restart) {
  const p = CAM_PRESETS[name];
  if (!p) return;
  LS.set('camQuality', name);
  camControl('framesize', p.framesize);
  setTimeout(() => camControl('quality', p.quality), 120);
  if (restart) setTimeout(() => startCamera(true), 500);
}
// `force` = restart even if already streaming the same camera (manual refresh / IP change).
function startCamera(force) {
  const url = camStreamUrl();
  if (!url) return;
  // Already streaming this camera and not forced → leave the live stream untouched.
  if (!force && state.camActive && state.camUrl === url) return;
  clearTimeout(state.camRetryTimer);
  state.camActive = true;
  state.camUrl = url;
  // Nudge the camera to the chosen latency preset before opening the stream.
  camControl('framesize', (CAM_PRESETS[state.camQuality] || CAM_PRESETS.low).framesize);
  camControl('quality', (CAM_PRESETS[state.camQuality] || CAM_PRESETS.low).quality);
  const img = $('camImg');
  img.src = url + '?t=' + Date.now();   // cache-buster only on (re)start
  img.style.display = 'block';
  $('camPlaceholder').style.display = 'none';
}
function stopCamera() {
  state.camActive = false;
  state.camUrl = '';
  clearTimeout(state.camRetryTimer);
  const img = $('camImg');
  img.removeAttribute('src');
  img.style.display = 'none';
  $('camPlaceholder').style.display = 'flex';
}
// MJPEG streams can drop (ESP32-CAM hiccup, single-client limit). Auto-reconnect.
function onCameraError() {
  if (!state.camActive || !state.connected) return;
  clearTimeout(state.camRetryTimer);
  state.camRetryTimer = setTimeout(() => {
    if (state.camActive && state.connected) {
      const img = $('camImg');
      img.src = camStreamUrl() + '?t=' + Date.now();
    }
  }, 1500);
}
function snapshot() {
  const img = $('camImg');
  if (!img.src || img.style.display === 'none') { toast('暂无画面可截图'); return; }
  try {
    const c = $('snapCanvas');
    c.width = img.naturalWidth || 640;
    c.height = img.naturalHeight || 480;
    c.getContext('2d').drawImage(img, 0, 0, c.width, c.height);
    c.toBlob((blob) => {
      const a = document.createElement('a');
      a.href = URL.createObjectURL(blob);
      a.download = `robocar_${Date.now()}.png`;
      a.click();
      URL.revokeObjectURL(a.href);
    });
  } catch (e) {
    toast('截图失败（跨域限制）');
  }
}

/* ── Movement (omni-directional mecanum) ─────────────────────────────────────
 * Firmware move_car(vx, vy, vw):  vx = forward/back, vy = strafe, vw = rotate.
 * The joystick (and W/S/A/D) drive translation; Q/E and the rotate buttons
 * drive vw. All three are combined and sent together so the car can translate
 * and rotate simultaneously. Speed is governed firmware-side via the `speed`
 * command, so joystick magnitudes are sent raw (-1..1).
 * ------------------------------------------------------------------------- */
let moveSendTimer = null;
let moveVec = { x: 0, y: 0 };       // normalized -1..1, y up = forward, x right = strafe right

function cancelTurnUI() {
  if (!state.turning) return;
  state.turning = false;
  clearTimeout(state.turnTimer);
  $('turnAroundBtn').classList.remove('active');
}
function applyMove() {
  send({
    cmd: 'move',
    vx: +moveVec.y.toFixed(3),   // forward / back
    vy: +moveVec.x.toFixed(3),   // strafe left / right (mecanum)
    vw: +state.rotVal.toFixed(3) // rotate
  });
}
function moveIsIdle() {
  return moveVec.x === 0 && moveVec.y === 0 && state.rotVal === 0;
}
function refreshMoveLoop() {
  if (moveIsIdle()) {
    if (moveSendTimer) { clearInterval(moveSendTimer); moveSendTimer = null; }
    applyMove();                      // send a single stop frame
  } else if (!moveSendTimer) {
    applyMove();
    moveSendTimer = setInterval(applyMove, 80);
  }
}
function setMoveVec(x, y) {
  if (state.turning && (x !== 0 || y !== 0)) cancelTurnUI(); // manual override cancels firmware turn
  moveVec.x = x; moveVec.y = y;
  refreshMoveLoop();
}
function setRot(v) {
  if (state.turning && v !== 0) cancelTurnUI();
  state.rotVal = v;
  refreshMoveLoop();
}

/* One-key turnaround: encoder-based closed-loop 180° spin done ON the car.
 * Firmware ({"cmd":"turn"}) reads the wheel encoders and stops at the exact
 * pulse count, so accuracy doesn't depend on battery/floor. `counts` is sent so
 * it can be calibrated live (no reflash). The button just shows feedback for an
 * estimated duration; the real stop happens on the car. */
function oneKeyTurn(dir = 1) {
  if (!state.connected) { toast('请先连接'); return; }
  if (state.turning) return;
  // make sure we're not also sending translation
  moveVec.x = 0; moveVec.y = 0; state.rotVal = 0;
  if (moveSendTimer) { clearInterval(moveSendTimer); moveSendTimer = null; }
  send({ cmd: 'move', vx: 0, vy: 0, vw: 0 });

  state.turning = true;
  send({ cmd: 'turn', counts: state.turnCounts, dir });
  $('turnAroundBtn').classList.add('active');
  toast('掉头中（编码器闭环）…');

  // UI feedback only — estimate spin time from counts (~120 counts / 50ms).
  const estMs = Math.min(8000, Math.max(800, Math.round(state.turnCounts / 2.4)));
  clearTimeout(state.turnTimer);
  state.turnTimer = setTimeout(() => {
    state.turning = false;
    $('turnAroundBtn').classList.remove('active');
  }, estMs);
}

/* ── Servo joystick ──────────────────────────────────────────────────────── */
let servoTimer = null;
let servoVec = { x: 0, y: 0 };
function sendServo() {
  send({ cmd: 'servo', channel: 0, angle: Math.round(state.pan) });
  send({ cmd: 'servo', channel: 1, angle: Math.round(state.tilt) });
  $('panVal').textContent = Math.round(state.pan) + '°';
  $('tiltVal').textContent = Math.round(state.tilt) + '°';
}
function setServoVec(x, y) {
  servoVec.x = x; servoVec.y = y;
  if (x === 0 && y === 0) {
    clearInterval(servoTimer); servoTimer = null;
  } else if (!servoTimer) {
    servoTimer = setInterval(() => {
      state.pan = Math.min(180, Math.max(0, state.pan - servoVec.x * 3));
      state.tilt = Math.min(70, Math.max(0, state.tilt - servoVec.y * 3));
      sendServo();
    }, 50);
  }
}
// Camera tilt presets. tilt range 0–70°. "看近处" points the lens down toward the
// ground in front of the car; "看远处" points it up toward the horizon.
// If your gimbal is wired the opposite way, just swap the two buttons' feel.
function setTilt(angle) {
  if (!state.connected) { toast('请先连接'); return; }
  state.tilt = Math.min(70, Math.max(0, angle));
  sendServo();
}
function camNear()   { setTilt(70); toast('已下俯 · 查看近处地面'); }
function camFar()    { setTilt(10); toast('已抬头 · 查看远处'); }
function camCenter() { state.pan = 90; setTilt(35); }

/* ── Generic virtual joystick (pointer + touch) ──────────────────────────── */
function makeJoystick(baseId, stickId, onChange) {
  const base = $(baseId), stick = $(stickId);
  let active = false, pid = null;
  const radius = () => base.clientWidth / 2 - stick.clientWidth / 2;

  function move(clientX, clientY) {
    const r = base.getBoundingClientRect();
    const cx = r.left + r.width / 2, cy = r.top + r.height / 2;
    let dx = clientX - cx, dy = clientY - cy;
    const max = radius();
    const dist = Math.hypot(dx, dy);
    if (dist > max) { dx = dx / dist * max; dy = dy / dist * max; }
    stick.style.transform = `translate(calc(-50% + ${dx}px), calc(-50% + ${dy}px))`;
    onChange(+(dx / max).toFixed(3), +(-dy / max).toFixed(3)); // y up positive
  }
  function reset() {
    stick.style.transform = 'translate(-50%, -50%)';
    onChange(0, 0);
  }
  base.addEventListener('pointerdown', (e) => {
    active = true; pid = e.pointerId; base.setPointerCapture(pid);
    move(e.clientX, e.clientY); e.preventDefault();
  });
  base.addEventListener('pointermove', (e) => {
    if (active && e.pointerId === pid) move(e.clientX, e.clientY);
  });
  const end = (e) => {
    if (active && e.pointerId === pid) { active = false; reset(); }
  };
  base.addEventListener('pointerup', end);
  base.addEventListener('pointercancel', end);
  return { reset };
}

/* ── Keyboard control ────────────────────────────────────────────────────── */
const keys = new Set();
function updateKeyboardMove() {
  let x = 0, y = 0;
  if (keys.has('w')) y += 1;          // forward
  if (keys.has('s')) y -= 1;          // back
  if (keys.has('a')) x -= 1;          // strafe left
  if (keys.has('d')) x += 1;          // strafe right
  // normalize diagonal
  if (x && y) { x *= 0.7071; y *= 0.7071; }
  setMoveVec(x, y);
}
function updateKeyboardRot() {
  let r = 0;
  if (keys.has('q')) r -= 1;          // rotate left (CCW)
  if (keys.has('e')) r += 1;          // rotate right (CW)
  setRot(r);
}
function updateKeyboardServo() {
  let x = 0, y = 0;
  if (keys.has('arrowleft')) x -= 1;
  if (keys.has('arrowright')) x += 1;
  if (keys.has('arrowup')) y += 1;
  if (keys.has('arrowdown')) y -= 1;
  setServoVec(x, y);
}
document.addEventListener('keydown', (e) => {
  const tag = document.activeElement && document.activeElement.tagName;
  if (tag === 'INPUT' || tag === 'SELECT' || tag === 'TEXTAREA') return;
  const k = e.key.toLowerCase();
  if (['w','a','s','d','q','e','arrowup','arrowdown','arrowleft','arrowright',' '].includes(k)) e.preventDefault();
  if (keys.has(k)) return;
  keys.add(k);
  if (['w','a','s','d'].includes(k)) updateKeyboardMove();
  if (k === 'q' || k === 'e') updateKeyboardRot();
  if (k.startsWith('arrow')) updateKeyboardServo();
  if (k === ' ') emergencyStop();
  if (k === 'l') toggleLight();
  if (k === 'h') hornPress();
});
document.addEventListener('keyup', (e) => {
  const k = e.key.toLowerCase();
  keys.delete(k);
  if (['w','a','s','d'].includes(k)) updateKeyboardMove();
  if (k === 'q' || k === 'e') updateKeyboardRot();
  if (k.startsWith('arrow')) updateKeyboardServo();
});

/* ── Speed (firmware-side max speed) ─────────────────────────────────────── */
function sendSpeed(n) {
  // firmware: motor_set_max_speed(value * 10), clamped to 1023
  send({ cmd: 'speed', value: n });
}

/* ── Toggle actions ──────────────────────────────────────────────────────── */
function emergencyStop() {
  // cancel any turnaround + rotation + translation, force a hard stop
  state.turning = false;
  state.rotVal = 0;
  clearTimeout(state.turnTimer);
  $('turnAroundBtn').classList.remove('active');
  moveVec.x = 0; moveVec.y = 0;
  if (moveSendTimer) { clearInterval(moveSendTimer); moveSendTimer = null; }
  send({ cmd: 'move', vx: 0, vy: 0, vw: 0 });
  toast('已急停');
}
function toggleLight() {
  if (!state.connected) { toast('请先连接'); return; }
  state.light = !state.light;
  send({ cmd: 'light', val: state.light ? 1 : 0 });
  $('lightBtn').classList.toggle('active', state.light);
}
function hornPress() {
  if (!state.connected) { toast('请先连接'); return; }
  send({ cmd: 'horn', val: 1 });
  $('hornBtn').classList.add('active');
  setTimeout(() => { send({ cmd: 'horn', val: 0 }); $('hornBtn').classList.remove('active'); }, 500);
}
function toggleAuto() {
  if (!state.connected) { toast('请先连接'); return; }
  state.auto = !state.auto;
  // firmware expects {"cmd":"mode","value":"AUTO"|"MANUAL"}; include "auto" too for compat
  send({ cmd: 'mode', value: state.auto ? 'AUTO' : 'MANUAL', auto: state.auto ? 1 : 0 });
  $('autoBtn').classList.toggle('active', state.auto);
  toast(state.auto ? '自动避障已开启' : '自动避障已关闭');
}

/* ── WiFi config ─────────────────────────────────────────────────────────── */
function scanWifi() {
  if (!state.connected) { toast('请先连接'); return; }
  $('wifiList').innerHTML = '<li class="muted">扫描中…</li>';
  send({ cmd: 'scan_wifi' });
  setTimeout(() => {
    if ($('wifiList').innerHTML.includes('扫描中')) $('wifiList').innerHTML = '<li class="muted">未发现网络或超时</li>';
  }, 10000);
}
function renderWifiList(nets) {
  const ul = $('wifiList');
  if (!nets.length) { ul.innerHTML = '<li class="muted">未发现网络</li>'; return; }
  ul.innerHTML = '';
  nets.forEach((n) => {
    const ssid = n.ssid || 'Unknown';
    const rssi = n.rssi != null ? n.rssi : -100;
    const secure = (typeof n.secure === 'number') ? n.secure !== 0 : (n.secure !== false);
    const li = document.createElement('li');
    li.innerHTML = `<span>${secure ? '🔒 ' : ''}${escapeHtml(ssid)}</span><span class="wifi-rssi">${rssi} dBm</span>`;
    li.onclick = () => { $('wifiSsid').value = ssid; $('wifiPass').focus(); };
    ul.appendChild(li);
  });
}
function connectWifi() {
  if (!state.connected) { toast('请先连接'); return; }
  const ssid = $('wifiSsid').value.trim();
  const password = $('wifiPass').value;
  if (!ssid) { toast('请输入 WiFi 名称'); return; }
  $('wifiStatus').textContent = '正在验证 WiFi（最长 15 秒）…';
  send({ cmd: 'wifi_config', ssid, password, test: true });
}

/* ── OTA ─────────────────────────────────────────────────────────────────── */
async function startOTA() {
  if (!state.ip) { toast('请先填写小车 IP'); return; }
  const fileEl = $('otaFile');
  if (!fileEl.files.length) { toast('请选择固件 .bin 文件'); return; }
  const target = $('otaTarget').value;
  const file = fileEl.files[0];
  const buf = new Uint8Array(await file.arrayBuffer());
  const total = buf.length;
  const chunkSize = 8192;
  const base = `http://${state.ip}`;
  const setProg = (p, msg) => { $('otaProgress').style.width = (p * 100).toFixed(1) + '%'; if (msg) $('otaStatus').textContent = msg; };

  $('otaUploadBtn').disabled = true;
  try {
    setProg(0, '通知设备准备 OTA…');
    let r = await fetch(`${base}/update?target=${target}&size=${total}`, { method: 'POST' });
    if (!r.ok) throw new Error('设备拒绝 OTA 请求');

    setProg(0, '正在上传固件…');
    for (let offset = 0; offset < total; offset += chunkSize) {
      const end = Math.min(offset + chunkSize, total);
      const chunk = buf.subarray(offset, end);
      r = await fetch(`${base}/upload`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/octet-stream', 'X-Offset': String(offset) },
        body: chunk,
      });
      if (!r.ok) throw new Error(`分块上传失败 @${offset}`);
      setProg(end / total, `上传中 ${(end / total * 100).toFixed(0)}%`);
    }

    setProg(1, '完成上传，正在写入…');
    r = await fetch(`${base}/finalize`, { method: 'POST' });
    if (!r.ok) throw new Error('固件写入失败');
    setProg(1, '✅ 升级成功，设备正在重启…');
    toast('OTA 升级成功');
    setTimeout(disconnect, 4000);
  } catch (e) {
    $('otaStatus').textContent = '❌ ' + e.message + '（如为跨域错误，请确认固件已开启 CORS）';
    toast('OTA 失败');
  } finally {
    $('otaUploadBtn').disabled = false;
  }
}

/* ── Voltage calibration ─────────────────────────────────────────────────── */
function calibrate() {
  const actual = parseFloat($('calibInput').value);
  if (!actual || state.battery <= 0) { toast('需已连接且读到电压，再输入实测值'); return; }
  state.voltMult = actual / state.battery;
  LS.set('voltMult', String(state.voltMult));
  renderTelemetry();
  toast(`已校准：系数 ×${state.voltMult.toFixed(3)}`);
}

/* ── Device actions ──────────────────────────────────────────────────────── */
function reboot() {
  if (!state.connected) { toast('请先连接'); return; }
  if (!confirm('确定要重启设备吗？')) return;
  send({ cmd: 'reboot' });
  toast('已发送重启命令');
}
function factoryReset() {
  if (!state.connected) { toast('请先连接'); return; }
  if (!confirm('确定恢复出厂设置？所有配置将被清除！')) return;
  send({ cmd: 'factory_reset' });
  toast('已发送恢复出厂命令');
}

/* ── Utils ───────────────────────────────────────────────────────────────── */
function escapeHtml(s) {
  return String(s).replace(/[&<>"']/g, (c) => ({ '&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;' }[c]));
}

/* Press-and-hold button: fires onDown while pressed, onUp on release/leave. */
function holdButton(id, onDown, onUp) {
  const el = $(id);
  let held = false;
  const start = (e) => { e.preventDefault(); if (held) return; held = true; el.classList.add('active'); onDown(); };
  const stop = () => { if (!held) return; held = false; el.classList.remove('active'); onUp(); };
  el.addEventListener('pointerdown', start);
  el.addEventListener('pointerup', stop);
  el.addEventListener('pointerleave', stop);
  el.addEventListener('pointercancel', stop);
}

/* ── Wire up ─────────────────────────────────────────────────────────────── */
function init() {
  // restore inputs
  $('ipInput').value = LS.get('ip', '192.168.4.1');
  $('camIpInput').value = LS.get('camIp', '');
  $('speedSlider').value = state.speed;
  $('speedVal').textContent = state.speed + '%';

  $('connectBtn').onclick = () => (state.connected || state.connecting) ? disconnect() : connect();
  $('camRefreshBtn').onclick = () => startCamera(true);
  $('camSnapBtn').onclick = snapshot;
  $('camImg').addEventListener('error', onCameraError);
  $('camQuality').value = state.camQuality;
  $('camQuality').onchange = (e) => {
    state.camQuality = e.target.value;
    applyCamPreset(state.camQuality, true);
    toast('已切换画质：' + e.target.selectedOptions[0].text);
  };

  $('lightBtn').onclick = toggleLight;
  $('hornBtn').onclick = hornPress;
  $('autoBtn').onclick = toggleAuto;
  $('estopBtn').onclick = emergencyStop;

  // rotation: hold to rotate; one-key turnaround
  holdButton('rotLeftBtn', () => setRot(-1), () => setRot(0));
  holdButton('rotRightBtn', () => setRot(1), () => setRot(0));
  $('turnAroundBtn').onclick = () => oneKeyTurn(1);

  // camera angle presets
  $('camNearBtn').onclick = camNear;
  $('camFarBtn').onclick = camFar;
  $('camCenterBtn').onclick = camCenter;

  // speed → firmware max-speed (live, debounced)
  $('speedSlider').oninput = (e) => {
    state.speed = parseInt(e.target.value, 10);
    $('speedVal').textContent = state.speed + '%';
    LS.set('speed', String(state.speed));
    clearTimeout(state.speedDebounce);
    state.speedDebounce = setTimeout(() => sendSpeed(state.speed), 120);
  };

  $('scanWifiBtn').onclick = scanWifi;
  $('wifiConnectBtn').onclick = connectWifi;
  $('otaUploadBtn').onclick = startOTA;
  $('calibBtn').onclick = calibrate;
  $('rebootBtn').onclick = reboot;
  $('factoryBtn').onclick = factoryReset;

  // turnaround calibration
  $('turnCountsInput').value = state.turnCounts;
  $('turnSaveBtn').onclick = () => {
    const n = parseInt($('turnCountsInput').value, 10);
    if (!n || n < 200) { toast('请输入有效脉冲数'); return; }
    state.turnCounts = n;
    LS.set('turnCounts', String(n));
    toast('掉头脉冲数已保存：' + n);
  };
  $('turnTestBtn').onclick = () => oneKeyTurn(1);

  makeJoystick('moveBase', 'moveStick', setMoveVec);
  makeJoystick('servoBase', 'servoStick', setServoVec);

  renderTelemetry();
  updateConnUI();
}

document.addEventListener('DOMContentLoaded', init);
