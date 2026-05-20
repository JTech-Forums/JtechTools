function _typeof(o) { "@babel/helpers - typeof"; return _typeof = "function" == typeof Symbol && "symbol" == typeof Symbol.iterator ? function (o) { return typeof o; } : function (o) { return o && "function" == typeof Symbol && o.constructor === Symbol && o !== Symbol.prototype ? "symbol" : typeof o; }, _typeof(o); }
function ownKeys(e, r) { var t = Object.keys(e); if (Object.getOwnPropertySymbols) { var o = Object.getOwnPropertySymbols(e); r && (o = o.filter(function (r) { return Object.getOwnPropertyDescriptor(e, r).enumerable; })), t.push.apply(t, o); } return t; }
function _objectSpread(e) { for (var r = 1; r < arguments.length; r++) { var t = null != arguments[r] ? arguments[r] : {}; r % 2 ? ownKeys(Object(t), !0).forEach(function (r) { _defineProperty(e, r, t[r]); }) : Object.getOwnPropertyDescriptors ? Object.defineProperties(e, Object.getOwnPropertyDescriptors(t)) : ownKeys(Object(t)).forEach(function (r) { Object.defineProperty(e, r, Object.getOwnPropertyDescriptor(t, r)); }); } return e; }
function _defineProperty(e, r, t) { return (r = _toPropertyKey(r)) in e ? Object.defineProperty(e, r, { value: t, enumerable: !0, configurable: !0, writable: !0 }) : e[r] = t, e; }
function _toPropertyKey(t) { var i = _toPrimitive(t, "string"); return "symbol" == _typeof(i) ? i : i + ""; }
function _toPrimitive(t, r) { if ("object" != _typeof(t) || !t) return t; var e = t[Symbol.toPrimitive]; if (void 0 !== e) { var i = e.call(t, r || "default"); if ("object" != _typeof(i)) return i; throw new TypeError("@@toPrimitive must return a primitive value."); } return ("string" === r ? String : Number)(t); }
function _regenerator() { /*! regenerator-runtime -- Copyright (c) 2014-present, Facebook, Inc. -- license (MIT): https://github.com/babel/babel/blob/main/packages/babel-helpers/LICENSE */ var e, t, r = "function" == typeof Symbol ? Symbol : {}, n = r.iterator || "@@iterator", o = r.toStringTag || "@@toStringTag"; function i(r, n, o, i) { var c = n && n.prototype instanceof Generator ? n : Generator, u = Object.create(c.prototype); return _regeneratorDefine2(u, "_invoke", function (r, n, o) { var i, c, u, f = 0, p = o || [], y = !1, G = { p: 0, n: 0, v: e, a: d, f: d.bind(e, 4), d: function d(t, r) { return i = t, c = 0, u = e, G.n = r, a; } }; function d(r, n) { for (c = r, u = n, t = 0; !y && f && !o && t < p.length; t++) { var o, i = p[t], d = G.p, l = i[2]; r > 3 ? (o = l === n) && (u = i[(c = i[4]) ? 5 : (c = 3, 3)], i[4] = i[5] = e) : i[0] <= d && ((o = r < 2 && d < i[1]) ? (c = 0, G.v = n, G.n = i[1]) : d < l && (o = r < 3 || i[0] > n || n > l) && (i[4] = r, i[5] = n, G.n = l, c = 0)); } if (o || r > 1) return a; throw y = !0, n; } return function (o, p, l) { if (f > 1) throw TypeError("Generator is already running"); for (y && 1 === p && d(p, l), c = p, u = l; (t = c < 2 ? e : u) || !y;) { i || (c ? c < 3 ? (c > 1 && (G.n = -1), d(c, u)) : G.n = u : G.v = u); try { if (f = 2, i) { if (c || (o = "next"), t = i[o]) { if (!(t = t.call(i, u))) throw TypeError("iterator result is not an object"); if (!t.done) return t; u = t.value, c < 2 && (c = 0); } else 1 === c && (t = i.return) && t.call(i), c < 2 && (u = TypeError("The iterator does not provide a '" + o + "' method"), c = 1); i = e; } else if ((t = (y = G.n < 0) ? u : r.call(n, G)) !== a) break; } catch (t) { i = e, c = 1, u = t; } finally { f = 1; } } return { value: t, done: y }; }; }(r, o, i), !0), u; } var a = {}; function Generator() {} function GeneratorFunction() {} function GeneratorFunctionPrototype() {} t = Object.getPrototypeOf; var c = [][n] ? t(t([][n]())) : (_regeneratorDefine2(t = {}, n, function () { return this; }), t), u = GeneratorFunctionPrototype.prototype = Generator.prototype = Object.create(c); function f(e) { return Object.setPrototypeOf ? Object.setPrototypeOf(e, GeneratorFunctionPrototype) : (e.__proto__ = GeneratorFunctionPrototype, _regeneratorDefine2(e, o, "GeneratorFunction")), e.prototype = Object.create(u), e; } return GeneratorFunction.prototype = GeneratorFunctionPrototype, _regeneratorDefine2(u, "constructor", GeneratorFunctionPrototype), _regeneratorDefine2(GeneratorFunctionPrototype, "constructor", GeneratorFunction), GeneratorFunction.displayName = "GeneratorFunction", _regeneratorDefine2(GeneratorFunctionPrototype, o, "GeneratorFunction"), _regeneratorDefine2(u), _regeneratorDefine2(u, o, "Generator"), _regeneratorDefine2(u, n, function () { return this; }), _regeneratorDefine2(u, "toString", function () { return "[object Generator]"; }), (_regenerator = function _regenerator() { return { w: i, m: f }; })(); }
function _regeneratorDefine2(e, r, n, t) { var i = Object.defineProperty; try { i({}, "", {}); } catch (e) { i = 0; } _regeneratorDefine2 = function _regeneratorDefine(e, r, n, t) { function o(r, n) { _regeneratorDefine2(e, r, function (e) { return this._invoke(r, n, e); }); } r ? i ? i(e, r, { value: n, enumerable: !t, configurable: !t, writable: !t }) : e[r] = n : (o("next", 0), o("throw", 1), o("return", 2)); }, _regeneratorDefine2(e, r, n, t); }
function asyncGeneratorStep(n, t, e, r, o, a, c) { try { var i = n[a](c), u = i.value; } catch (n) { return void e(n); } i.done ? t(u) : Promise.resolve(u).then(r, o); }
function _asyncToGenerator(n) { return function () { var t = this, e = arguments; return new Promise(function (r, o) { var a = n.apply(t, e); function _next(n) { asyncGeneratorStep(a, r, o, _next, _throw, "next", n); } function _throw(n) { asyncGeneratorStep(a, r, o, _next, _throw, "throw", n); } _next(void 0); }); }; }
if (!NodeList.prototype.forEach) {
  NodeList.prototype.forEach = Array.prototype.forEach;
}
var STORAGE_OK = true;
function storageGet(key, fallback) {
  try {
    var val = localStorage.getItem(key);
    return val === null || val === undefined ? fallback : val;
  } catch (e) {
    STORAGE_OK = false;
    return fallback;
  }
}
function storageSet(key, val) {
  if (!STORAGE_OK) return;
  try {
    localStorage.setItem(key, val);
  } catch (e) {
    STORAGE_OK = false;
  }
}
function storageRemove(key) {
  if (!STORAGE_OK) return;
  try {
    localStorage.removeItem(key);
  } catch (e) {
    STORAGE_OK = false;
  }
}
var ORIGIN = location.origin || location.protocol + '//' + location.host;
var PROXY = location.hostname === 'localhost' || location.hostname === '127.0.0.1' ? location.protocol + '//' + location.hostname + ':8080' : ORIGIN;
var SITE = ORIGIN;
var BASE_PATH = window.DUMBCOURSE_SETTINGS && window.DUMBCOURSE_SETTINGS.basePath ? window.DUMBCOURSE_SETTINGS.basePath : '/dumb';
var SITE_ICON = '';
var SITE_FAVICON = '';
var SITE_TITLE = 'Forum';
var SITE_SETTINGS = {
  allowSignup: true,
  fullNameRequired: false,
  fullNameVisible: false,
  userFields: [],
  userFieldMaxLength: 0
};
var HCAPTCHA_ENABLED = false;
var HCAPTCHA_SITE_KEY = '';
var LT_ENABLED = window.DUMBCOURSE_SETTINGS && window.DUMBCOURSE_SETTINGS.languagetoolEnabled;
var HCAPTCHA_WIDGET_ID = null;
var HCAPTCHA_LOAD_PROMISE = null;
var API_INFLIGHT = {};
var API_CACHE = {};
var RATE_LIMIT_UNTIL = 0;
var LAST_SESSION_CHECK = 0;
var SESSION_CHECKING = false;
var EMOJI_MAP = {};
var EMOJI_CACHE = {};
var EMOJI_READY = false;
var READ_TOPICS = {};
var VIEWED_THIS_SESSION = {}; // Track topics viewed this session for instant unread update
var TOPICS_POLL_INTERVAL = null; // Polling interval for topics page auto-refresh
var API_CACHE_KEY = 'jt_api_cache';
var API_CACHE_TTL = 5 * 60 * 1000;
var PERSISTENT_API_CACHE = {};
try {
  PERSISTENT_API_CACHE = JSON.parse(storageGet(API_CACHE_KEY, '{}') || '{}') || {};
} catch (e) {
  PERSISTENT_API_CACHE = {};
}
var READ_TOPICS_KEY = 'jt_read_topics';
try {
  READ_TOPICS = JSON.parse(storageGet(READ_TOPICS_KEY, '{}') || '{}') || {};
} catch (e) {
  READ_TOPICS = {};
}
var IMAGE_CACHE_KEY = 'jt_image_cache';
var IMAGE_CACHE_MAX = 60;
var IMAGE_CACHE = {};
var IMAGE_LIST = [];
try {
  IMAGE_LIST = JSON.parse(storageGet(IMAGE_CACHE_KEY, '[]') || '[]') || [];
} catch (e) {
  IMAGE_LIST = [];
}
var EMOJI_CACHE_KEY = 'jt_emoji_map';
try {
  var emojiSeed = JSON.parse(storageGet(EMOJI_CACHE_KEY, '{}') || '{}');
  if (emojiSeed && emojiSeed.map) {
    EMOJI_MAP = emojiSeed.map;
    EMOJI_READY = true;
  }
} catch (e) {}

// MessageBus client for real-time updates (official Discourse method)
var MB = {
  clientId: 'dumbcourse_' + Math.random().toString(36).substr(2, 9) + '_' + Date.now(),
  channels: {},
  callbacks: {},
  lastIds: {},
  polling: false,
  stopped: true,
  pollXhr: null,
  baseUrl: PROXY,

  subscribe: function(channel, callback, lastId) {
    if (!this.callbacks[channel]) this.callbacks[channel] = [];
    this.callbacks[channel].push(callback);
    this.lastIds[channel] = typeof lastId === 'number' ? lastId : -1;
    if (!this.stopped) this.poll();
  },

  unsubscribe: function(channel, callback) {
    if (!this.callbacks[channel]) return;
    if (callback) {
      this.callbacks[channel] = this.callbacks[channel].filter(function(cb) { return cb !== callback; });
    } else {
      delete this.callbacks[channel];
      delete this.lastIds[channel];
    }
  },

  start: function() {
    if (!this.stopped) return;
    this.stopped = false;
    this.poll();
  },

  stop: function() {
    this.stopped = true;
    this.polling = false;
    if (this.pollXhr) {
      try { this.pollXhr.abort(); } catch(e) {}
      this.pollXhr = null;
    }
  },

  poll: function() {
    var self = this;
    if (self.stopped || self.polling) return;
    if (document.hidden) {
      setTimeout(function() { self.poll(); }, 10000);
      return;
    }

    var channels = Object.keys(self.lastIds);
    if (channels.length === 0) return;

    self.polling = true;

    // Build POST body: channel => lastId
    var body = {};
    channels.forEach(function(ch) {
      body[ch] = self.lastIds[ch];
    });

    var xhr = new XMLHttpRequest();
    self.pollXhr = xhr;
    xhr.open('POST', self.baseUrl + '/message-bus/' + self.clientId + '/poll', true);
    xhr.setRequestHeader('Content-Type', 'application/x-www-form-urlencoded');
    xhr.setRequestHeader('Accept', 'application/json');
    if (S.token) xhr.setRequestHeader('X-Session-Token', S.token);
    if (S.csrf) xhr.setRequestHeader('X-CSRF-Token', S.csrf);
    if (S.cookies) xhr.setRequestHeader('X-Cookies', S.cookies);
    xhr.timeout = 30000; // Long poll timeout

    xhr.onload = function() {
      self.polling = false;
      self.pollXhr = null;
      if (xhr.status >= 200 && xhr.status < 300) {
        try {
          var messages = JSON.parse(xhr.responseText);
          if (Array.isArray(messages)) {
            messages.forEach(function(msg) {
              var ch = msg.channel;
              if (msg.message_id) self.lastIds[ch] = msg.message_id;
              var cbs = self.callbacks[ch];
              if (cbs) {
                cbs.forEach(function(cb) {
                  try { cb(msg.data, msg.global_id, msg.message_id); } catch(e) {}
                });
              }
            });
          }
        } catch(e) {}
      }
      if (!self.stopped) {
        setTimeout(function() { self.poll(); }, 100);
      }
    };

    xhr.onerror = xhr.ontimeout = function() {
      self.polling = false;
      self.pollXhr = null;
      if (!self.stopped) {
        setTimeout(function() { self.poll(); }, 5000);
      }
    };

    // Encode body as form data
    var params = [];
    channels.forEach(function(ch) {
      params.push(encodeURIComponent(ch) + '=' + encodeURIComponent(self.lastIds[ch]));
    });
    xhr.send(params.join('&'));
  }
};

function fromCodePoint(cp) {
  if (String.fromCodePoint) return String.fromCodePoint(cp);
  if (cp <= 0xFFFF) return String.fromCharCode(cp);
  cp -= 0x10000;
  return String.fromCharCode(0xD800 + (cp >> 10), 0xDC00 + (cp & 0x3FF));
}
function codepointsToString(codeStr) {
  if (!codeStr) return '';
  var parts = String(codeStr).split('-');
  var out = '';
  for (var i = 0; i < parts.length; i++) {
    var cp = parseInt(parts[i], 16);
    if (!cp) continue;
    out += fromCodePoint(cp);
  }
  return out;
}
function emojiForName(name) {
  var code = EMOJI_MAP[name];
  if (!code) return '';
  if (EMOJI_CACHE[name]) return EMOJI_CACHE[name];
  var val = codepointsToString(code);
  EMOJI_CACHE[name] = val;
  return val;
}
function emojifyText(s) {
  if (!s) return '';
  return String(s).replace(/:([a-z0-9_+\-]+):/g, function (m, name) {
    var e = emojiForName(name);
    return e || m;
  });
}
function markTopicRead(id) {
  if (!id) return;
  READ_TOPICS[String(id)] = Date.now();
  var keys = Object.keys(READ_TOPICS);
  if (keys.length > 600) {
    keys.sort(function (a, b) {
      return READ_TOPICS[a] - READ_TOPICS[b];
    });
    for (var i = 0; i < keys.length - 400; i++) {
      delete READ_TOPICS[keys[i]];
    }
  }
  storageSet(READ_TOPICS_KEY, JSON.stringify(READ_TOPICS));
}
function isTopicRead(id) {
  return !!READ_TOPICS[String(id)];
}
function isTopicUnread(t) {
  if (VIEWED_THIS_SESSION[String(t.id)]) return false;
  if ((t.unread_posts || 0) > 0 || (t.new_posts || 0) > 0) return true;
  if (t.last_read_post_number != null && t.highest_post_number > t.last_read_post_number) return true;
  if (t.last_read_post_number == null && !isTopicRead(t.id)) return true;
  return false;
}
function updateSiteUI(prevTitle) {
  var t = emojifyText(SITE_TITLE || 'Forum');
  var top = document.getElementById('topTitle');
  if (top && (top.textContent === 'Forum' || top.textContent === emojifyText(prevTitle || ''))) top.textContent = t;
  var icon = document.getElementById('siteIcon');
  if (icon) {
    if (SITE_ICON) {
      icon.src = SITE_ICON;
      icon.alt = t;
      icon.style.display = 'block';
    } else {
      icon.style.display = 'none';
    }
  }
  var loginTitle = document.getElementById('loginTitle');
  if (loginTitle) loginTitle.textContent = t;
  var loginNote = document.getElementById('loginNote');
  if (loginNote) loginNote.textContent = 'Sign in to ' + t + '.';
  var signupLink = document.getElementById('signupLink');
  var loginDivider = document.getElementById('loginDivider');
  if (signupLink) signupLink.style.display = SITE_SETTINGS.allowSignup === false ? 'none' : 'block';
  if (loginDivider) loginDivider.style.display = SITE_SETTINGS.allowSignup === false ? 'none' : 'flex';
  var signupTitle = document.getElementById('signupTitle');
  if (signupTitle) signupTitle.textContent = t;
  var signupNote = document.getElementById('signupNote');
  if (signupNote) signupNote.textContent = 'Create your account on ' + t + '.';
}
function setSiteTitle(t) {
  var prev = SITE_TITLE;
  SITE_TITLE = t || 'Forum';
  updateSiteUI(prev);
}
function setSiteIcon(url) {
  SITE_ICON = url || '';
  updateSiteUI(SITE_TITLE);
  if (!SITE_FAVICON && SITE_ICON) setFavicon(SITE_ICON);
}
function setFavicon(url) {
  SITE_FAVICON = url || '';
  if (!url) return;
  var href = url;
  if (href.indexOf('http') !== 0 && href.indexOf('//') !== 0) href = SITE + href;
  var link = document.querySelector('link[rel="icon"]') || document.querySelector('link[rel="shortcut icon"]');
  if (!link) {
    link = document.createElement('link');
    link.rel = 'icon';
    document.head.appendChild(link);
  }
  link.href = href;
}
function ensureHCaptchaReady() {
  if (!HCAPTCHA_ENABLED || !HCAPTCHA_SITE_KEY) return Promise.resolve(false);
  if (window.hcaptcha && typeof window.hcaptcha.render === 'function') return Promise.resolve(true);
  if (HCAPTCHA_LOAD_PROMISE) return HCAPTCHA_LOAD_PROMISE;
  HCAPTCHA_LOAD_PROMISE = new Promise(function (resolve) {
    try {
      var script = document.createElement('script');
      script.src = 'https://hcaptcha.com/1/api.js?render=explicit';
      script.async = true;
      script.defer = true;
      script.onload = function () {
        resolve(!!(window.hcaptcha && typeof window.hcaptcha.render === 'function'));
      };
      script.onerror = function () {
        resolve(false);
      };
      document.head.appendChild(script);
    } catch (e) {
      resolve(false);
    }
  });
  return HCAPTCHA_LOAD_PROMISE;
}
function renderHCaptchaBox() {
  var box = document.getElementById('hcaptchaBox');
  if (!box) return;
  if (!HCAPTCHA_ENABLED || !HCAPTCHA_SITE_KEY) {
    box.style.display = 'none';
    return;
  }
  box.style.display = 'block';
  var errEl = document.getElementById('hcaptchaError');
  if (errEl) {
    errEl.style.display = 'none';
    errEl.textContent = '';
  }
  ensureHCaptchaReady().then(function (ok) {
    if (!ok) {
      if (errEl) {
        errEl.textContent = 'Captcha failed to load. Please refresh or use the full site to sign up.';
        errEl.style.display = 'block';
      }
      return;
    }
    try {
      if (window.hcaptcha && HCAPTCHA_WIDGET_ID !== null && typeof window.hcaptcha.reset === 'function') {
        window.hcaptcha.reset(HCAPTCHA_WIDGET_ID);
      }
      HCAPTCHA_WIDGET_ID = window.hcaptcha.render('hcaptchaField', {
        sitekey: HCAPTCHA_SITE_KEY
      });
    } catch (e) {
      if (errEl) {
        errEl.textContent = 'Captcha failed to load. Please refresh or use the full site to sign up.';
        errEl.style.display = 'block';
      }
    }
  });
}
function resetHCaptcha() {
  if (window.hcaptcha && HCAPTCHA_WIDGET_ID !== null) {
    try {
      window.hcaptcha.reset(HCAPTCHA_WIDGET_ID);
    } catch (e) {}
  }
}
function ensureHCaptchaToken() {
  if (!HCAPTCHA_ENABLED || !HCAPTCHA_SITE_KEY) return Promise.resolve(false);
  if (!window.hcaptcha || HCAPTCHA_WIDGET_ID === null) {
    return Promise.reject(new Error('Captcha failed to load. Please refresh.'));
  }
  var token = '';
  try {
    token = window.hcaptcha.getResponse(HCAPTCHA_WIDGET_ID) || '';
  } catch (e) {}
  if (!token) return Promise.reject(new Error('Please complete the captcha'));
  return api(BASE_PATH + '/hcaptcha', {
    method: 'POST',
    body: {
      token: token
    },
    nocache: true,
    nodup: true
  }).then(function () {
    return true;
  });
}

function loadSite() {
  return fetch(PROXY + '/site.json', {
    headers: {
      'Accept': 'application/json'
    },
    credentials: 'same-origin'
  }).then(function (resp) {
    if (!resp || !resp.ok) return null;
    return resp.json();
  }).then(function (d) {
    var name = d && d.site && (d.site.title || d.site.name) || (d && d.title);
    if (name) setSiteTitle(name);
    var fav = d && d.site && d.site.favicon_url;
    if (fav) setFavicon(fav);
    if (typeof d.full_name_required_for_signup === 'boolean') {
      SITE_SETTINGS.fullNameRequired = d.full_name_required_for_signup;
    }
    if (typeof d.full_name_visible_in_signup === 'boolean') {
      SITE_SETTINGS.fullNameVisible = d.full_name_visible_in_signup;
    }
    if (typeof d.allow_new_registrations === 'boolean') {
      SITE_SETTINGS.allowSignup = d.allow_new_registrations;
    }
    if (Array.isArray(d.user_fields)) {
      SITE_SETTINGS.userFields = d.user_fields;
    }
    if (typeof d.user_field_max_length === 'number') {
      SITE_SETTINGS.userFieldMaxLength = d.user_field_max_length;
    }
  }).catch(function () {});
}
function loadManifest() {
  return fetch(PROXY + '/manifest.json', {
    headers: {
      'Accept': 'application/json'
    },
    credentials: 'same-origin'
  }).then(function (resp) {
    if (!resp || !resp.ok) return null;
    return resp.json();
  }).then(function (m) {
    if (m && m.name && (!SITE_TITLE || SITE_TITLE === 'Forum')) setSiteTitle(m.name);
    var icons = m && m.icons || [];
    if (icons.length && icons[0] && icons[0].src) {
      var iconUrl = icons[0].src;
      if (iconUrl.indexOf('http') !== 0 && iconUrl.indexOf('//') !== 0) iconUrl = SITE + iconUrl;
      setSiteIcon(iconUrl);
      if (!SITE_FAVICON) setFavicon(iconUrl);
    }
  }).catch(function () {});
}
function loadEmojiMap() {
  return fetch(SITE + BASE_PATH + '/emoji_map.json', {
    headers: {
      'Accept': 'application/json'
    },
    credentials: 'same-origin'
  }).then(function (resp) {
    if (!resp || !resp.ok) return null;
    return resp.json();
  }).then(function (d) {
    if (d && d.map) {
      EMOJI_MAP = d.map;
      EMOJI_READY = true;
      storageSet(EMOJI_CACHE_KEY, JSON.stringify(d));
    }
  }).catch(function () {});
}
var S = {
  token: storageGet('jt_session_token', '') || '',
  csrf: storageGet('jt_csrf', '') || '',
  cookies: storageGet('jt_cookies', '') || '',
  username: storageGet('jt_username', '') || '',
  userId: storageGet('jt_user_id', '') || '',
  loggedIn: storageGet('jt_logged_in', '') === '1',
  authChecked: false,
  honeypot: '',
  challenge: '',
  honeypotExpiresAt: 0,
  categories: {},
  drafts: JSON.parse(storageGet('jt_drafts', '{}') || '{}'),
  history: [],
  pushRegistered: false,
  admin: storageGet('jt_admin', '') === '1',
  moderator: storageGet('jt_moderator', '') === '1'
};
var _unreadMsgCount = 0;
var _unreadNotifCount = 0;
var TOPIC_USERS = {};
function mergeTopicUsers(list) {
  (list || []).forEach(function (u) {
    if (!u || !u.id) return;
    TOPIC_USERS[u.id] = u;
  });
}
function isLoggedIn() {
  return !!S.loggedIn;
}
function canModerate() {
  return S.admin || S.moderator;
}
// Push notification registration for native app (ES5 compatible for Chrome 44+)
var PUSH_REGISTERED = false;
function isNativeApp() {
  try {
    return !!(window.PushBridge && typeof window.PushBridge.isNativeApp === 'function' && window.PushBridge.isNativeApp());
  } catch (e) {
    return false;
  }
}
function generatePushTopic() {
  var deviceId = '';
  try {
    deviceId = window.PushBridge.getDeviceId() || '';
  } catch (e) {}
  if (!deviceId) deviceId = 'web-' + Math.random().toString(36).substring(2, 15);
  var topic = 'dumbcourse-' + deviceId.substring(0, 8) + '-' + Math.random().toString(36).substring(2, 10);
  return topic;
}
function registerPushNotifications() {
  if (PUSH_REGISTERED || !isNativeApp() || !isLoggedIn()) {
    return Promise.resolve(false);
  }
  var existingTopic = '';
  try {
    existingTopic = window.PushBridge.getTopic() || '';
  } catch (e) {}
  return fetch(PROXY + BASE_PATH + '/push/info', {
    headers: { 'Accept': 'application/json' },
    credentials: 'same-origin'
  }).then(function (resp) {
    if (!resp || !resp.ok) return null;
    return resp.json();
  }).then(function (info) {
    if (!info || !info.enabled) return false;
    var server = info.server;
    var topic = existingTopic || generatePushTopic();
    var deviceId = '';
    try {
      deviceId = window.PushBridge.getDeviceId() || '';
    } catch (e) {}
    return fetch(PROXY + BASE_PATH + '/push/register', {
      method: 'POST',
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'X-CSRF-Token': S.csrf || ''
      },
      credentials: 'same-origin',
      body: JSON.stringify({ topic: topic, device_id: deviceId })
    }).then(function (resp) {
      if (!resp || !resp.ok) return false;
      return resp.json();
    }).then(function (result) {
      if (result && result.success) {
        try {
          window.PushBridge.registerPush(server, topic);
          PUSH_REGISTERED = true;
          S.pushRegistered = true;
          return true;
        } catch (e) {
          return false;
        }
      }
      return false;
    });
  }).catch(function () {
    return false;
  });
}
function unregisterPushNotifications() {
  if (!isNativeApp()) return Promise.resolve(false);
  var deviceId = '';
  try {
    deviceId = window.PushBridge.getDeviceId() || '';
  } catch (e) {}
  return fetch(PROXY + BASE_PATH + '/push/unregister', {
    method: 'DELETE',
    headers: {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'X-CSRF-Token': S.csrf || ''
    },
    credentials: 'same-origin',
    body: JSON.stringify({ device_id: deviceId })
  }).then(function (resp) {
    if (!resp || !resp.ok) return false;
    try {
      window.PushBridge.unregisterPush();
    } catch (e) {}
    PUSH_REGISTERED = false;
    S.pushRegistered = false;
    return true;
  }).catch(function () {
    return false;
  });
}
var _badgePollInterval = null;
function registerWebPushBadges() {
  if (!isLoggedIn()) return;
  if (_badgePollInterval) return;
  // Poll badge counts every 30 seconds instead of holding an SSE connection
  // SSE connections through Rails hold a Puma thread each, exhausting the thread pool
  _badgePollInterval = setInterval(function () {
    if (isLoggedIn()) {
      refreshUnreadNotifCount();
      refreshUnreadMessageCount();
    }
  }, 30000);
}
function closeWebPushBadges() {
  if (_badgePollInterval) {
    clearInterval(_badgePollInterval);
    _badgePollInterval = null;
  }
}
function refreshCurrentUser() {
  var now = Date.now();
  if (SESSION_CHECKING) return Promise.resolve(!!S.loggedIn);
  if (LAST_SESSION_CHECK && now - LAST_SESSION_CHECK < 3000) return Promise.resolve(!!S.loggedIn);
  LAST_SESSION_CHECK = now;
  SESSION_CHECKING = true;
  return fetch(PROXY + '/session/current.json', {
    headers: {
      'Accept': 'application/json'
    },
    credentials: 'same-origin'
  }).then(function (resp) {
    if (!resp) return { state: 'error' };
    if (resp.status === 401 || resp.status === 403) return { state: 'unauth' };
    if (!resp.ok) return { state: 'error' };
    return resp.json().then(function (d) {
      return { state: 'ok', data: d };
    }, function () {
      return { state: 'error' };
    });
  }).then(function (r) {
    if (r.state === 'unauth') {
      S.loggedIn = false;
      storageSet('jt_logged_in', '0');
      return false;
    }
    if (r.state === 'ok' && r.data && r.data.current_user) {
      S.loggedIn = true;
      S.authChecked = true;
      S.username = r.data.current_user.username || S.username;
      S.userId = r.data.current_user.id || S.userId;
      S.admin = !!r.data.current_user.admin;
      S.moderator = !!r.data.current_user.moderator;
      if (S.username) storageSet('jt_username', S.username);
      if (S.userId) storageSet('jt_user_id', S.userId);
      storageSet('jt_logged_in', '1');
      storageSet('jt_admin', S.admin ? '1' : '0');
      storageSet('jt_moderator', S.moderator ? '1' : '0');
      return true;
    }
    if (r.state === 'ok') {
      S.loggedIn = false;
      storageSet('jt_logged_in', '0');
      return false;
    }
    return !!S.loggedIn;
  }).catch(function () {
    return !!S.loggedIn;
  }).then(function (v) {
    SESSION_CHECKING = false;
    return v;
  });
}
function checkSession() {
  if (S.authChecked) return Promise.resolve(isLoggedIn());
  S.authChecked = true;
  return refreshCurrentUser();
}
function ensureCsrf() {
  return fetch(PROXY + '/session/csrf.json', {
    headers: {
      'Accept': 'application/json'
    },
    credentials: 'same-origin'
  }).then(function (resp) {
    if (!resp || !resp.ok) return null;
    var t = resp.headers.get('X-Session-Token');
    if (t) {
      S.token = t;
      storageSet('jt_session_token', t);
    }
    var c = resp.headers.get('X-Cookies');
    if (c) {
      S.cookies = c;
      storageSet('jt_cookies', c);
    }
    return resp.json();
  }).then(function (d) {
    if (d && d.csrf) {
      S.csrf = d.csrf;
      storageSet('jt_csrf', S.csrf);
    }
    return d;
  }).catch(function () {
    return null;
  });
}
function reverseString(str) {
  if (!str) return '';
  return String(str).split('').reverse().join('');
}
function ensureHoneypot() {
  var now = Date.now();
  if (S.honeypot && S.challenge && S.honeypotExpiresAt && now < S.honeypotExpiresAt - 5000) {
    return Promise.resolve({
      value: S.honeypot,
      challenge: S.challenge
    });
  }
  return fetch(PROXY + '/session/hp', {
    headers: {
      'Accept': 'application/json'
    },
    credentials: 'same-origin'
  }).then(function (resp) {
    if (!resp || !resp.ok) return null;
    return resp.json();
  }).then(function (d) {
    if (d && d.value && d.challenge) {
      S.honeypot = d.value;
      S.challenge = d.challenge;
      S.honeypotExpiresAt = Date.now() + (d.expires_in ? d.expires_in * 1000 : 300000);
    }
    return d;
  }).catch(function () {
    return null;
  });
}
function saveDraft(key, val) {
  if (!key) return;
  var entry = {
    text: String(val || ''),
    updatedAt: Date.now()
  };
  if (arguments.length > 2 && arguments[2]) {
    entry.meta = arguments[2];
  } else if (S.drafts[key] && typeof S.drafts[key] === 'object' && S.drafts[key].meta) {
    entry.meta = S.drafts[key].meta;
  }
  S.drafts[key] = entry;
  storageSet('jt_drafts', JSON.stringify(S.drafts));
}
function getDraft(key) {
  var val = S.drafts[key];
  if (!val) return '';
  if (typeof val === 'string') return val;
  if (typeof val === 'object' && val.text) return val.text;
  return '';
}
function getDraftEntry(key) {
  var val = S.drafts[key];
  if (!val) return null;
  if (typeof val === 'string') return {
    text: val,
    updatedAt: 0
  };
  if (typeof val === 'object') return val;
  return null;
}
function clearDraft(key) {
  delete S.drafts[key];
  storageSet('jt_drafts', JSON.stringify(S.drafts));
}
function cacheApiSet(path, val) {
  if (!path || !val) return;
  PERSISTENT_API_CACHE[path] = {
    t: Date.now(),
    v: val
  };
  var keys = Object.keys(PERSISTENT_API_CACHE);
  if (keys.length > 80) {
    keys.sort(function (a, b) {
      return PERSISTENT_API_CACHE[a].t - PERSISTENT_API_CACHE[b].t;
    });
    keys.slice(0, keys.length - 80).forEach(function (k) {
      delete PERSISTENT_API_CACHE[k];
    });
  }
  storageSet(API_CACHE_KEY, JSON.stringify(PERSISTENT_API_CACHE));
}
function cacheApiGet(path) {
  var c = PERSISTENT_API_CACHE[path];
  if (!c) return null;
  if (Date.now() - c.t > API_CACHE_TTL) return null;
  return c.v || null;
}
function clearApiCache() {
  API_CACHE = {};
  PERSISTENT_API_CACHE = {};
  try {
    storageRemove(API_CACHE_KEY);
  } catch (e) {}
}
function rememberImage(url) {
  if (!url || IMAGE_CACHE[url]) return;
  IMAGE_CACHE[url] = true;
  if (IMAGE_LIST.indexOf(url) === -1) {
    IMAGE_LIST.unshift(url);
    IMAGE_LIST = IMAGE_LIST.slice(0, IMAGE_CACHE_MAX);
    storageSet(IMAGE_CACHE_KEY, JSON.stringify(IMAGE_LIST));
  }
  try {
    var img = new Image();
    img.src = url;
  } catch (e) {}
}
function hydrateImageCache() {
  if (!IMAGE_LIST.length) return;
  IMAGE_LIST.forEach(function (url) {
    rememberImage(url);
  });
}
function api(path, opts) {
  var method = opts && opts.method ? String(opts.method).toUpperCase() : 'GET';
  var key = method + ' ' + path;
  if (method === 'GET' && (!opts || !opts.nocache)) {
    var c = API_CACHE[path];
    if (c && Date.now() - c.t < 1000) return Promise.resolve(c.v);
    var persisted = cacheApiGet(path);
    if (persisted) {
      API_CACHE[path] = {
        t: Date.now(),
        v: persisted
      };
      return Promise.resolve(persisted);
    }
  }
  if (!opts || !opts.nodup) {
    if (API_INFLIGHT[key]) return API_INFLIGHT[key];
    var p = _api(path, opts);
    API_INFLIGHT[key] = p;
    var clear = function () {
      if (API_INFLIGHT[key] === p) delete API_INFLIGHT[key];
    };
    if (p && typeof p.then === 'function') {
      return p.then(function (v) {
        clear();
        if (method === 'GET' && path && typeof v === 'string' && /\.json(\?|$)/.test(path)) {
          var trimmed = v.trim();
          if (trimmed && (trimmed[0] === '{' || trimmed[0] === '[')) {
            try {
              v = JSON.parse(trimmed);
            } catch (e) {}
          }
        }
        if (method === 'GET' && (!opts || !opts.nocache) && typeof v !== 'string') {
          API_CACHE[path] = {
            t: Date.now(),
            v: v
          };
          cacheApiSet(path, v);
        }
        return v;
      }, function (e) {
        clear();
        throw e;
      });
    }
    clear();
    return p;
  }
  return _api(path, opts);
}
function _api() {
  _api = _asyncToGenerator(/*#__PURE__*/_regenerator().m(function _callee12(path) {
    var opts,
      url,
      headers,
      mergedHeaders,
      resp,
      newToken,
      newCsrf,
      newCookies,
      text,
      msg,
      j,
      ct,
      _args12 = arguments;
    return _regenerator().w(function (_context12) {
      while (1) switch (_context12.n) {
        case 0:
          opts = _args12.length > 1 && _args12[1] !== undefined ? _args12[1] : {};
          if (RATE_LIMIT_UNTIL && Date.now() < RATE_LIMIT_UNTIL) {
            throw new Error('Too many requests. Please wait and try again.');
          }
          url = PROXY + path;
          headers = {
            'Accept': 'application/json'
          };
          if (S.token) headers['X-Session-Token'] = S.token;
          if (S.csrf) headers['X-CSRF-Token'] = S.csrf;
          if (S.cookies) headers['X-Cookies'] = S.cookies;
          if (opts.body && !(opts.body instanceof FormData)) {
            headers['Content-Type'] = 'application/json';
            opts.body = JSON.stringify(opts.body);
          }
          mergedHeaders = opts.body instanceof FormData ? _objectSpread({}, headers) // no Content-Type override
          : _objectSpread(_objectSpread({}, headers), opts.headers || {});
          delete opts.headers; // consumed
          _context12.n = 1;
          return fetch(url, _objectSpread(_objectSpread({}, opts), {}, {
            headers: mergedHeaders,
            credentials: opts.credentials || 'same-origin'
          }));
        case 1:
          resp = _context12.v;
          newToken = resp.headers.get('X-Session-Token');
          if (newToken) {
            S.token = newToken;
            storageSet('jt_session_token', newToken);
          }
          newCsrf = resp.headers.get('X-CSRF-Token');
          if (newCsrf) {
            S.csrf = newCsrf;
            storageSet('jt_csrf', newCsrf);
          }
          newCookies = resp.headers.get('X-Cookies');
          if (newCookies) {
            S.cookies = newCookies;
            storageSet('jt_cookies', newCookies);
          }
          if (resp.ok) {
            _context12.n = 3;
            break;
          }
          if (resp.status === 401) {
            S.token = '';
            S.csrf = '';
            S.cookies = '';
            S.loggedIn = false;
            S.authChecked = true;
            S.username = '';
            S.userId = '';
            storageRemove('jt_session_token');
            storageRemove('jt_csrf');
            storageRemove('jt_cookies');
            storageRemove('jt_username');
            storageRemove('jt_user_id');
            storageSet('jt_logged_in', '0');
            navigate('/', true);
            throw new Error('Session expired. Please log in again.');
          }
          if (resp.status === 403 && path && path.indexOf('/session/') === 0) {
            S.loggedIn = false;
            storageSet('jt_logged_in', '0');
          }
          if (resp.status === 429) {
            var ra = parseInt(resp.headers.get('Retry-After') || '0', 10);
            RATE_LIMIT_UNTIL = Date.now() + (ra > 0 ? ra * 1000 : 15000);
            throw new Error('Too many requests. Please wait and try again.');
          }
          _context12.n = 2;
          return resp.text();
        case 2:
          text = _context12.v;
          try {
            j = JSON.parse(text);
            msg = j.errors && j.errors.join(', ') || j.error || text;
          } catch (e) {
            msg = text;
          }
          throw new Error(`${resp.status}: ${msg}`);
        case 3:
          ct = resp.headers.get('content-type') || '';
          if (!ct.includes('json')) {
            _context12.n = 4;
            break;
          }
          return _context12.a(2, resp.json());
        case 4:
          return _context12.a(2, resp.text());
      }
    }, _callee12);
  }));
  return _api.apply(this, arguments);
}
var OFFLINE_MSG = 'Forums are down right now. Try again later.';
function friendlyErrorMessage(err) {
  var msg = err && err.message ? err.message : String(err || '');
  var lower = msg.toLowerCase();
  if (lower.indexOf('failed to fetch') !== -1 || lower.indexOf('networkerror') !== -1 || lower.indexOf('load failed') !== -1) {
    return OFFLINE_MSG;
  }
  if (/(\s|^)(502|503|504|521|522|524)\b/.test(msg) || lower.indexOf('discourse offline') !== -1 || lower.indexOf('errorpages/') !== -1 || lower.indexOf('<!doctype') !== -1 || lower.indexOf('<html') !== -1) {
    return OFFLINE_MSG;
  }
  return msg;
}
function formatErrorMessage(err) {
  var msg = friendlyErrorMessage(err);
  if (msg === OFFLINE_MSG) return msg;
  return 'Error: ' + msg;
}
function isImageUpload(file, upload) {
  if (file && file.type && file.type.indexOf('image/') === 0) return true;
  var name = file && file.name || upload && upload.original_filename || '';
  return /\.(png|jpe?g|gif|webp|bmp|svg)$/i.test(name);
}
function buildUploadMarkdown(file, upload) {
  var name = file && file.name || upload && upload.original_filename || 'file';
  var url = upload && (upload.short_url || upload.url) || '';
  if (!url) return '';
  if (isImageUpload(file, upload)) {
    return `![${name}](${url})`;
  }
  return `[${name}|attachment](${url})`;
}
function addAttachmentPreview(listId, file, upload, textareaId) {
  var list = document.getElementById(listId);
  if (!list) return;
  list.style.display = 'flex';
  var item = document.createElement('div');
  item.className = 'attachment-item';
  item.tabIndex = 0;
  var icon = document.createElement('span');
  icon.className = 'attach-icon';
  icon.innerHTML = IC.upload;
  var name = document.createElement('span');
  name.className = 'attach-name';
  name.textContent = file && file.name || upload && upload.original_filename || 'attachment';
  var markdown = buildUploadMarkdown(file, upload);
  var removeBtn = document.createElement('button');
  removeBtn.className = 'attach-remove';
  removeBtn.type = 'button';
  removeBtn.tabIndex = 0;
  removeBtn.innerHTML = IC.x;
  removeBtn.setAttribute('aria-label', 'Remove attachment');
  removeBtn.addEventListener('click', function(e) {
    e.stopPropagation();
    // Remove markdown from textarea
    if (textareaId && markdown) {
      var ta = document.getElementById(textareaId);
      if (ta) {
        ta.value = ta.value.replace('\n' + markdown, '').replace(markdown, '');
        ta.dispatchEvent(new Event('input'));
      }
    }
    item.remove();
    if (list.children.length === 0) list.style.display = 'none';
  });
  item.appendChild(icon);
  item.appendChild(name);
  item.appendChild(removeBtn);
  list.appendChild(item);
}
function clearAttachmentPreview(listId) {
  var list = document.getElementById(listId);
  if (!list) return;
  list.innerHTML = '';
  list.style.display = 'none';
}
function uploadFile(file, btn) {
  return new Promise(function (resolve, reject) {
    var orig = btn.innerHTML;
    btn.disabled = true;
    btn.style.pointerEvents = 'none';
    btn.style.opacity = '0.5';
    btn.textContent = '0%';
    var fd = new FormData();
    fd.append('file', file);
    fd.append('type', 'composer');
    var xhr = new XMLHttpRequest();
    xhr.upload.addEventListener('progress', function (e) {
      if (e.lengthComputable) btn.textContent = Math.round(e.loaded / e.total * 100) + '%';
    });
    xhr.addEventListener('load', function () {
      btn.innerHTML = orig;
      btn.disabled = false;
      btn.style.pointerEvents = '';
      btn.style.opacity = '';
      if (xhr.status >= 200 && xhr.status < 300) {
        try {
          resolve(JSON.parse(xhr.responseText));
        } catch (e) {
          reject(new Error('Bad response'));
        }
      } else {
        reject(new Error('Upload failed (' + xhr.status + ')'));
      }
    });
    xhr.addEventListener('error', function () {
      btn.innerHTML = orig;
      btn.disabled = false;
      btn.style.pointerEvents = '';
      btn.style.opacity = '';
      reject(new Error('Upload failed'));
    });
    xhr.open('POST', PROXY + '/uploads.json');
    xhr.setRequestHeader('Accept', 'application/json');
    if (S.token) xhr.setRequestHeader('X-Session-Token', S.token);
    if (S.csrf) xhr.setRequestHeader('X-CSRF-Token', S.csrf);
    if (S.cookies) xhr.setRequestHeader('X-Cookies', S.cookies);
    xhr.send(fd);
  });
}
function useHashRouting() {
  return false;
}
function makeUrl(path) {
  var p = path || '/';
  if (p.indexOf(BASE_PATH) === 0) return p;
  if (p[0] !== '/') p = '/' + p;
  return BASE_PATH + p;
}
function currentPath() {
  var p = location.pathname || '/';
  if (p.indexOf(BASE_PATH) === 0) p = p.slice(BASE_PATH.length) || '/';
  return p || '/';
}
function currentQuery() {
  return (location.search || '').replace(/^\?/, '');
}
function setUrl(path, replace) {
  var p = path || '/';
  var url = makeUrl(p);
  if (replace && history.replaceState) history.replaceState(null, '', url);else if (history.pushState) history.pushState(null, '', url);else location.href = url;
}
function navigate(path, replace) {
  if (topicScrollCleanup && isTopicListPath(currentPath()) && !isTopicListPath(path)) {
    topicScrollCleanup();
  }
  setUrl(path, replace);
  route();
  // Refresh badges after a short delay to let the server process read state
  if (isLoggedIn()) {
    setTimeout(function () {
      refreshUnreadNotifCount();
      refreshUnreadMessageCount();
    }, 1500);
  }
}
document.addEventListener('click', function (e) {
  if (e.defaultPrevented) return;
  var a = e.target.closest ? e.target.closest('a') : null;
  if (!a) return;
  if (a.target === '_blank' || a.hasAttribute('download')) return;
  var href = a.getAttribute('href') || '';
  if (!href || href.indexOf('javascript:') === 0 || href.indexOf('mailto:') === 0) return;
  var url = href;
  if (href.indexOf('http://') === 0 || href.indexOf('https://') === 0) {
    if (href.indexOf(ORIGIN) !== 0) return;
    url = href.slice(ORIGIN.length);
  }
  if (url.indexOf(BASE_PATH) !== 0) return;
  e.preventDefault();
  navigate(url.slice(BASE_PATH.length) || '/');
});
function parseTopicPath(path) {
  if (!path) return null;
  var p = path.split('?')[0];
  var parts = p.split('/').filter(Boolean);
  if (parts[0] === 't') {
    if (parts.length >= 2 && /^\d+$/.test(parts[1])) {
      return {
        id: parts[1],
        post: /^\d+$/.test(parts[2] || '') ? parts[2] : ''
      };
    }
    if (parts.length >= 3 && /^\d+$/.test(parts[2])) {
      return {
        id: parts[2],
        post: /^\d+$/.test(parts[3] || '') ? parts[3] : ''
      };
    }
  }
  if (parts[0] === 'messages' && parts[1] && /^\d+$/.test(parts[1])) {
    return {
      id: parts[1],
      post: ''
    };
  }
  return null;
}
function parseCategoryPath(path) {
  if (!path) return null;
  var p = path.split('?')[0];
  var parts = p.split('/').filter(Boolean);
  if (parts[0] === 'c') {
    if (parts.length >= 2 && /^\d+$/.test(parts[1])) {
      return {
        id: parts[1],
        slug: ''
      };
    }
    if (parts.length >= 3 && /^\d+$/.test(parts[2])) {
      return {
        id: parts[2],
        slug: parts[1] || ''
      };
    }
  }
  return null;
}
function currentTopicId() {
  var t = parseTopicPath(currentPath());
  return t && t.id || '';
}
function currentTopicPost() {
  var t = parseTopicPath(currentPath());
  return t && t.post || '';
}
var CURRENT_TOPIC = null;
var POST_REFRESHER = null;
var TOPIC_MB_CLEANUP = null;
var PRESENCE_SUPPORTED = null; // null = unknown, true/false after first check
function presenceXhr(method, path, body, cb) {
  if (PRESENCE_SUPPORTED === false) return;
  var xhr = new XMLHttpRequest();
  xhr.open(method, PROXY + path, true);
  xhr.setRequestHeader('Content-Type', 'application/json');
  xhr.setRequestHeader('Accept', 'application/json');
  xhr.setRequestHeader('X-Requested-With', 'XMLHttpRequest');
  if (S.token) xhr.setRequestHeader('X-Session-Token', S.token);
  if (S.csrf) xhr.setRequestHeader('X-CSRF-Token', S.csrf);
  if (S.cookies) xhr.setRequestHeader('X-Cookies', S.cookies);
  xhr.timeout = 10000;
  xhr.onload = function() {
    if (xhr.status === 404) {
      PRESENCE_SUPPORTED = false;
      return;
    }
    if (PRESENCE_SUPPORTED === null) PRESENCE_SUPPORTED = true;
    if (cb && xhr.status >= 200 && xhr.status < 300) {
      try { cb(JSON.parse(xhr.responseText)); } catch(e) {}
    }
  };
  xhr.onerror = xhr.ontimeout = function() {};
  xhr.send(body ? JSON.stringify(body) : null);
}
function refreshPostById(postId) {
  if (POST_REFRESHER) return POST_REFRESHER(postId);
  clearApiCache();
  return renderTopic(currentTopicId());
}
function topicPath(id, slug, postNumber) {
  if (!id) return '/';
  var p = slug ? '/t/' + slug + '/' + id : '/t/' + id;
  var pn = postNumber && String(postNumber).match(/^\d+$/) ? postNumber : '';
  if (pn) p += '/' + pn;
  return p;
}
function topicHref(id, slug, postNumber) {
  return makeUrl(topicPath(id, slug, postNumber));
}
function categoryPath(slug, id) {
  if (!id) return '/categories';
  if (slug) return '/c/' + slug + '/' + id;
  return '/c/' + id;
}
function categoryHref(slug, id) {
  return makeUrl(categoryPath(slug, id));
}
function userPath(username) {
  return '/u/' + encodeURIComponent(username);
}
function userHref(username) {
  return makeUrl(userPath(username));
}
var $app = document.getElementById('app');
var $title = document.getElementById('topTitle');
var $home = document.getElementById('homeLink');
var $searchBtn = document.getElementById('searchBtn');
var $back = document.getElementById('backBtn');
var $menu = document.getElementById('menuDrop');
var $menuBtn = document.getElementById('menuBtn');
var $view = document.getElementById('viewDrop');
var $viewBtn = document.getElementById('viewBtn');
var $create = document.getElementById('createBtn');
var $siteIcon = document.getElementById('siteIcon');
var createTarget = '';
function setTitle(t) {
  var siteTitle = emojifyText(SITE_TITLE);
  var baseTitle = siteTitle + ' Dumbcourse';
  var title = emojifyText(t || SITE_TITLE);
  $title.textContent = title;
  document.title = title === siteTitle ? baseTitle : title + ' - ' + baseTitle;
  if ($siteIcon) {
    $siteIcon.style.display = title !== siteTitle && SITE_ICON ? 'none' : SITE_ICON ? 'block' : 'none';
  }
  syncTopbarHeight();
}
function showBack(show) {
  $back.style.display = show ? 'block' : 'none';
}
function setActiveView(viewKey) {
  if (!$view) return;
  $view.querySelectorAll('a[data-view]').forEach(function (a) {
    a.classList.toggle('active', a.getAttribute('data-view') === viewKey);
  });
}
function showCreate(target) {
  createTarget = target;
  $create.style.display = target ? 'block' : 'none';
}
$create.addEventListener('click', function () {
  if (createTarget) navigate(createTarget);
});
if ($home) {
  $home.addEventListener('click', function (e) {
    e.preventDefault();
    navigate('/', true);
  });
}
function bindTap(el, handler) {
  if (!el) return;
  var lastTouch = 0;
  el.addEventListener('touchend', function (e) {
    lastTouch = Date.now();
    e.preventDefault();
    handler(e);
  }, {
    passive: false
  });
  el.addEventListener('click', function (e) {
    if (Date.now() - lastTouch < 350) return;
    handler(e);
  });
}
if ($searchBtn) {
  bindTap($searchBtn, function () {
    navigate('/search');
  });
}
if ($viewBtn) {
  bindTap($viewBtn, function () {
    toggleView();
  });
}
function softRefresh(path) {
  clearApiCache();
  if (path) setUrl(path, true);
  return route();
}
var refreshBtnEl = document.getElementById('refreshBtn');
bindTap(refreshBtnEl, function () {
  return softRefresh();
});
if (refreshBtnEl) {
  refreshBtnEl.addEventListener('keydown', function (e) {
    if (e.key === 'Enter' || e.key === ' ') {
      e.preventDefault();
      softRefresh();
    }
  });
}
function goBack() {
  if (S.history.length > 1) {
    S.history.pop();
    navigate(S.history[S.history.length - 1], true);
  } else history.back();
}
$back.addEventListener('click', goBack);
document.addEventListener('keydown', function (e) {
  var tag = document.activeElement && document.activeElement.tagName;
  var inInput = tag === 'INPUT' || tag === 'TEXTAREA' || tag === 'SELECT';
  if (e.key === 'ArrowDown') {
    var active = document.activeElement;
    var inTopbar = active && active.closest && active.closest('#topbar');
    var inMenu = active && active.closest && active.closest('#menuDrop');
    if (inTopbar && !inMenu && !$menu.classList.contains('open')) {
      focusContent();
      e.preventDefault();
      return;
    }
  }
  if ((e.key === 'Backspace' || e.key === 'Escape') && !inInput) {
    if ($view && $view.classList.contains('open')) {
      toggleView(false);
      if ($viewBtn) $viewBtn.focus();
      e.preventDefault();
      return;
    }
    if ($menu.classList.contains('open')) {
      toggleMenu(false);
      $menuBtn.focus();
      e.preventDefault();
      return;
    }
    var activePost = document.querySelector('.post.active');
    if (activePost) {
      deactivatePost(activePost);
      activePost.focus();
      e.preventDefault();
      return;
    }
    var overlay = document.querySelector('.confirm-overlay');
    if (overlay) {
      var cb = overlay.querySelector('.cancel') || overlay.querySelector('.ok');
      if (cb) cb.click();
      e.preventDefault();
      return;
    }
    if ($back.style.display !== 'none') {
      e.preventDefault();
      goBack();
    }
  }
  if (e.key === 'Escape' && inInput) {
    document.activeElement.blur();
    e.preventDefault();
  }
});
function route() {
  return routeLogic();
}
function routeLogic() {
  try {
    var hash = currentPath();
    if (currentQuery()) hash += '?' + currentQuery();
    if (S.history[S.history.length - 1] !== hash) S.history.push(hash);
    // Clear CURRENT_TOPIC unless navigating to a topic (will be set by renderTopic)
    var pathForCheck = hash.split('?')[0] || '/';
    if (!parseTopicPath(pathForCheck) && !pathForCheck.match(/^\/messages\/\d+/)) {
      CURRENT_TOPIC = null;
    }
    // Stop MessageBus and clean up stale subscriptions on every navigation
    MB.stop();
    if (TOPIC_MB_CLEANUP) { TOPIC_MB_CLEANUP(); TOPIC_MB_CLEANUP = null; }
    if (TOPICS_POLL_INTERVAL) {
      clearInterval(TOPICS_POLL_INTERVAL);
      TOPICS_POLL_INTERVAL = null;
    }
    if (!isLoggedIn()) {
      if (hash === '/signup' || hash === '/register') {
        showCreate('');
        renderSignup();
        return Promise.resolve();
      }
      showCreate('');
      renderLogin();
      return Promise.resolve();
    }
    var path = hash.split('?')[0] || '/';
    document.body.classList.remove('search-mode');
    document.body.classList.remove('auth-mode');
    showCreate('');
    var topicInfo = parseTopicPath(path);
    var catInfo = parseCategoryPath(path);
    var viewKey = viewFromPath(path);
    if (path === '/') {
      if (defaultView === 'categories') return renderCategories();
      return renderTopics(defaultView);
    }
    if (path === '/categories') return renderCategories();
    if (catInfo) return renderCategoryTopics(catInfo.id, catInfo.slug);
    if (viewKey) return renderTopics(viewKey);
    if (topicInfo) return renderTopic(topicInfo.id, topicInfo.post);
    if (path === '/new-topic') {
      renderNewTopic();
      return Promise.resolve();
    }
    if (path === '/messages') return renderMessages();
    if (path.match(/^\/messages\/(\d+)/)) return renderTopic(path.match(/^\/messages\/(\d+)/)[1], '', true);
    if (path === '/drafts') {
      renderDrafts();
      return Promise.resolve();
    }
    if (path === '/new-message') {
      renderNewMessage();
      return Promise.resolve();
    }
    if (path === '/notifications') return renderNotifications();
    if (path === '/review') return renderReview();
    if (path.match(/^\/u\/(.+)/)) return renderProfile(decodeURIComponent(path.match(/^\/u\/(.+)/)[1]));
    if (path === '/settings') {
      renderSettings();
      return Promise.resolve();
    }
    if (path.match(/^\/search/)) return renderSearch();
    return renderTopics(defaultView === 'categories' ? 'latest' : defaultView);
  } catch (err) {
    $app.innerHTML = `<div class="error">${esc(formatErrorMessage(err))}</div>`;
    return Promise.resolve();
  }
}
var ROUTE_BUSY = false;
var ROUTE_QUEUED = false;
var LAST_ROUTE_AT = 0;
var routeRaw = route;
route = function () {
  var now = Date.now();
  if (ROUTE_BUSY) {
    ROUTE_QUEUED = true;
    return;
  }
  if (now - LAST_ROUTE_AT < 250) {
    ROUTE_QUEUED = true;
    return;
  }
  LAST_ROUTE_AT = now;
  ROUTE_BUSY = true;
  setLoading(true);
  var p = routeRaw();
  var done = function () {
    ROUTE_BUSY = false;
    syncTopbarHeight();
    setLoading(false);
    if (ROUTE_QUEUED) {
      ROUTE_QUEUED = false;
      setTimeout(route, 120);
    }
  };
  if (p && typeof p.then === 'function') {
    p.then(done, done);
  } else {
    done();
  }
  return p;
};
window.addEventListener('popstate', route);
var _topbarTimer = null;
window.addEventListener('resize', function () {
  if (_topbarTimer) clearTimeout(_topbarTimer);
  _topbarTimer = setTimeout(syncTopbarHeight, 120);
});
setTimeout(syncTopbarHeight, 0);
hydrateImageCache();
var _escEl = document.createElement('div');
function esc(s) {
  if (!s) return '';
  _escEl.textContent = String(s);
  return _escEl.innerHTML;
}
function syncTopbarHeight() {
  var tb = document.getElementById('topbar');
  if (!tb) return;
  var h = tb.offsetHeight || 48;
  if (h) document.documentElement.style.setProperty('--top-h', h + 'px');
}
function setLoading(on) {
  var el = document.getElementById('topLoader');
  if (!el) return;
  el.style.display = on ? 'block' : 'none';
}
function decodeHtml(s) {
  if (!s) return '';
  _escEl.innerHTML = String(s);
  return _escEl.textContent || _escEl.innerText || '';
}
function escEmoji(s) {
  return esc(emojifyText(s));
}
function stripHtml(s) {
  if (!s) return '';
  return String(s).replace(/<[^>]*>/g, '');
}
function htmlToText(html) {
  if (!html) return '';
  var s = String(html);
  s = s.replace(/<br\s*\/?>/gi, '\n');
  s = s.replace(/<\/p>/gi, '\n\n');
  s = s.replace(/<\/div>/gi, '\n');
  s = s.replace(/<\/li>/gi, '\n');
  s = stripHtml(s);
  s = decodeHtml(s);
  return s.replace(/\n{3,}/g, '\n\n').trim();
}
function mdBasic(src) {
  var text = String(src || '').replace(/\r\n/g, '\n');
  var blocks = [];
  text = text.replace(/```([\s\S]*?)```/g, function (m, code) {
    blocks.push(code);
    return '\n%%CODE' + (blocks.length - 1) + '%%\n';
  });
  text = text.replace(/^\s*([-*]{3,}|_{3,})\s*$/gm, '%%HR%%');
  text = esc(text);
  text = emojifyText(text);
  text = text.replace(/`([^`]+)`/g, '<code>$1</code>');
  text = text.replace(/\*\*([\s\S]+?)\*\*/g, '<strong>$1</strong>');
  text = text.replace(/__([\s\S]+?)__/g, '<strong>$1</strong>');
  text = text.replace(/\*(?!\s)([^*]+?)\*/g, '<em>$1</em>');
  text = text.replace(/_(?!\s)([^_]+?)_/g, '<em>$1</em>');
  text = text.replace(/\[([^\]]+)\]\((https?:\/\/[^\s)]+)\)/g, '<a href="$2" target="_blank" rel="noopener">$1</a>');
  var lines = text.split('\n');
  var out = '';
  var inUl = false;
  var inOl = false;
  var inBq = false;
  var para = '';
  function flushPara() {
    if (para) {
      out += '<p>' + para + '</p>';
      para = '';
    }
  }
  function closeLists() {
    if (inUl) {
      out += '</ul>';
      inUl = false;
    }
    if (inOl) {
      out += '</ol>';
      inOl = false;
    }
  }
  function closeBq() {
    if (inBq) {
      out += '</blockquote>';
      inBq = false;
    }
  }
  for (var i = 0; i < lines.length; i++) {
    var line = lines[i];
    if (/^%%CODE\\d+%%$/.test(line.trim())) {
      flushPara();
      closeLists();
      closeBq();
      var idx = parseInt(line.trim().replace(/\\D/g, ''), 10);
      out += '<pre><code>' + esc(blocks[idx] || '') + '</code></pre>';
      continue;
    }
    if (line.trim() === '%%HR%%') {
      flushPara();
      closeLists();
      closeBq();
      out += '<hr>';
      continue;
    }
    if (line.trim() === '') {
      flushPara();
      closeLists();
      closeBq();
      continue;
    }
    if (/^#{1,3}\\s+/.test(line)) {
      flushPara();
      closeLists();
      closeBq();
      var level = line.match(/^#{1,3}/)[0].length;
      out += '<h' + level + '>' + line.replace(/^#{1,3}\\s+/, '') + '</h' + level + '>';
      continue;
    }
    if (line.indexOf('&gt; ') === 0) {
      flushPara();
      closeLists();
      if (!inBq) {
        out += '<blockquote>';
        inBq = true;
      }
      out += line.replace(/^&gt;\\s?/, '') + '<br>';
      continue;
    }
    if (/^\\s*[-*]\\s+\\[[ xX]\\]\\s+/.test(line)) {
      flushPara();
      closeBq();
      if (!inUl) {
        out += '<ul class="contains-task-list">';
        inUl = true;
      }
      var checked = /^\\s*[-*]\\s+\\[[xX]\\]\\s+/.test(line);
      var content = line.replace(/^\\s*[-*]\\s+\\[[ xX]\\]\\s+/, '');
      out += '<li class="task-list-item"><input type="checkbox" disabled' + (checked ? ' checked' : '') + '> ' + content + '</li>';
      continue;
    }
    if (/^\\s*[-*]\\s+/.test(line)) {
      flushPara();
      closeBq();
      if (!inUl) {
        out += '<ul>';
        inUl = true;
      }
      out += '<li>' + line.replace(/^\\s*[-*]\\s+/, '') + '</li>';
      continue;
    }
    if (/^\\s*\\d+\\.\\s+/.test(line)) {
      flushPara();
      closeBq();
      if (!inOl) {
        out += '<ol>';
        inOl = true;
      }
      out += '<li>' + line.replace(/^\\s*\\d+\\.\\s+/, '') + '</li>';
      continue;
    }
    closeLists();
    closeBq();
    if (para) para += '<br>';
    para += line;
  }
  flushPara();
  closeLists();
  closeBq();
  return out || '';
}
function getPreviewContext(opts) {
  if (!opts) return {};
  if (typeof opts === 'function') return opts() || {};
  var ctx = {};
  if (opts.titleId) {
    var titleEl = document.getElementById(opts.titleId);
    if (titleEl) ctx.title = titleEl.value.trim();
  }
  if (opts.categoryId) {
    var catEl = document.getElementById(opts.categoryId);
    if (catEl && catEl.value) ctx.category = parseInt(catEl.value, 10);
  }
  if (opts.topicId) ctx.topicId = opts.topicId;
  if (opts.archetype) ctx.archetype = opts.archetype;
  if (opts.replyToPostNumber) {
    ctx.replyToPostNumber = typeof opts.replyToPostNumber === 'function' ? opts.replyToPostNumber() : opts.replyToPostNumber;
  }
  return ctx;
}
function renderDiscoursePreview(raw, opts) {
  var body = {
    raw: raw
  };
  var ctx = getPreviewContext(opts);
  if (ctx.title) body.title = ctx.title;
  if (ctx.category) body.category = ctx.category;
  if (ctx.topicId) body.topic_id = ctx.topicId;
  if (ctx.replyToPostNumber) body.reply_to_post_number = ctx.replyToPostNumber;
  if (ctx.archetype) body.archetype = ctx.archetype;
  return api('/posts/preview.json', {
    method: 'POST',
    body: body,
    nodup: true
  }).then(function (d) {
    return fixPostHtml(d && d.cooked ? d.cooked : '');
  });
}
function bindPreview(textareaId, previewId, toggleId, opts) {
  var ta = document.getElementById(textareaId);
  var pv = document.getElementById(previewId);
  var btn = document.getElementById(toggleId);
  if (!ta || !pv || !btn) return;
  var on = false;
  var timer = null;
  var previewToken = 0;
  function setPreviewButton(state) {
    var label = state ? 'Hide Preview' : 'Preview';
    var icon = state ? IC.hidePreview : IC.preview;
    btn.innerHTML = '<span class="btn-icon">' + icon + '</span>';
    btn.setAttribute('aria-label', label);
    btn.setAttribute('title', label);
  }
  function render() {
    var raw = ta.value || '';
    if (!raw.trim()) {
      pv.innerHTML = '';
      return;
    }
    var token = ++previewToken;
    renderDiscoursePreview(raw, opts).then(function (html) {
      if (token !== previewToken) return;
      pv.innerHTML = html || mdBasic(raw);
      enhanceCooked(pv);
    }).catch(function () {
      if (token !== previewToken) return;
      pv.innerHTML = mdBasic(raw);
      enhanceCooked(pv);
    });
  }
  function schedule() {
    if (!on) return;
    if (timer) clearTimeout(timer);
    timer = setTimeout(function () {
      return render();
    }, 200);
  }
  btn.addEventListener('click', function () {
    on = !on;
    pv.style.display = on ? 'block' : 'none';
    ta.style.display = on ? 'none' : 'block';
    setPreviewButton(on);
    if (on) {
      render();
      if (pv && pv.focus) pv.focus();
    } else {
      ta.focus();
    }
  });
  setPreviewButton(on);
  ta.addEventListener('input', schedule);
}
function applyLtMatches(text, matches) {
  if (!matches || !matches.length) return {
    text: text,
    changed: false
  };
  var list = [];
  for (var i = 0; i < matches.length; i++) {
    var m = matches[i] || {};
    if (typeof m.offset !== 'number' || typeof m.length !== 'number') continue;
    if (!m.replacements || !m.replacements.length) continue;
    list.push(m);
  }
  if (!list.length) return {
    text: text,
    changed: false
  };
  list.sort(function (a, b) {
    return (b.offset || 0) - (a.offset || 0);
  });
  var out = text;
  var changed = false;
  for (var j = 0; j < list.length; j++) {
    var m2 = list[j];
    var rep = m2.replacements && m2.replacements[0] ? m2.replacements[0].value : null;
    if (rep === null || rep === undefined) continue;
    var start = m2.offset || 0;
    var len = m2.length || 0;
    if (start < 0 || len < 0) continue;
    var end = start + len;
    if (start > out.length) continue;
    out = out.slice(0, start) + rep + out.slice(end);
    changed = true;
  }
  return {
    text: out,
    changed: changed
  };
}
function bindRefine(textareaId, buttonId) {
  var ta = document.getElementById(textareaId);
  var btn = document.getElementById(buttonId);
  if (!ta || !btn) return;
  if (btn._bound) return;
  btn._bound = true;
  btn.addEventListener('click', function () {
    if (!LT_ENABLED) return showAlert('LanguageTool not enabled');
    var raw = ta.value || '';
    if (!raw.trim()) return showAlert('Write something first');
    if (btn.disabled) return;
    var prevHtml = btn.innerHTML;
    btn.disabled = true;
    btn.innerHTML = '<span class="btn-icon">' + IC.refine + '</span>';
    api(BASE_PATH + '/languagetool/check', {
      method: 'POST',
      body: {
        text: raw
      }
    }).then(function (resp) {
      var matches = resp && resp.matches ? resp.matches : [];
      var result = applyLtMatches(raw, matches);
      if (result.changed && result.text !== raw) {
        ta.value = result.text;
        ta.dispatchEvent(new Event('input'));
      } else {
        showAlert('No changes found');
      }
    }).catch(function (e) {
      showAlert(e && e.message ? e.message : 'LanguageTool failed');
    }).then(function () {
      btn.disabled = false;
      btn.innerHTML = prevHtml;
    });
  });
}
function attachMentionAutocomplete(textarea, opts) {
  if (!textarea) return;
  var topicId = opts && opts.topicId ? opts.topicId : '';
  var localSuggestions = opts && opts.suggestions ? opts.suggestions : [];
  var mentionTimer = null;
  var mentionDrop = document.createElement('div');
  mentionDrop.className = 'mention-dropdown';
  mentionDrop.style.display = 'none';
  var parent = textarea.parentNode || textarea;
  if (parent && parent.style) parent.style.position = 'relative';
  if (parent && parent.insertBefore) parent.insertBefore(mentionDrop, textarea.nextSibling);
  var mentionIdx = -1;
  var mentionItems = [];
  var mentionStart = -1;
  var lastTerm = '';
  function closeMention() {
    mentionDrop.style.display = 'none';
    mentionDrop.innerHTML = '';
    mentionIdx = -1;
    mentionItems = [];
    mentionStart = -1;
    lastTerm = '';
  }
  function setActive(idx) {
    if (!mentionItems.length) return;
    if (idx < 0) idx = 0;
    if (idx >= mentionItems.length) idx = mentionItems.length - 1;
    mentionIdx = idx;
    for (var i = 0; i < mentionItems.length; i++) {
      if (i === idx) mentionItems[i].classList.add('active');else mentionItems[i].classList.remove('active');
    }
  }
  function insertMention(username) {
    var val = textarea.value;
    var pos = textarea.selectionStart || 0;
    var before = val.substring(0, pos);
    var after = val.substring(pos);
    var start = mentionStart >= 0 ? mentionStart : before.lastIndexOf('@');
    if (start < 0) return;
    var newBefore = before.substring(0, start) + '@' + username + ' ';
    textarea.value = newBefore + after;
    textarea.selectionStart = textarea.selectionEnd = newBefore.length;
    closeMention();
    textarea.focus();
    textarea.dispatchEvent(new Event('input'));
  }
  function renderUsers(users) {
    mentionDrop.innerHTML = users.map(function (u) {
      return '<div class="mention-item" data-username="' + esc(u.username) + '" tabindex="0">' + (u.avatar_template ? '<img src="' + avatarUrl(u.avatar_template, 20) + '" alt="" style="width:16px;height:16px;border-radius:50%;vertical-align:middle"> ' : '') + esc(u.username) + '</div>';
    }).join('');
    mentionDrop.style.display = 'block';
    mentionItems = mentionDrop.querySelectorAll('.mention-item');
    mentionIdx = -1;
    for (var i = 0; i < mentionItems.length; i++) {
      mentionItems[i].addEventListener('click', function () {
        insertMention(this.dataset.username);
      });
    }
  }
  function filterLocal(term) {
    if (!localSuggestions || !localSuggestions.length) return [];
    if (!term) return localSuggestions.slice(0, 5);
    var lower = term.toLowerCase();
    var out = [];
    for (var i = 0; i < localSuggestions.length; i++) {
      var u = localSuggestions[i];
      if (!u || !u.username) continue;
      var uname = u.username.toLowerCase();
      var idx = uname.indexOf(lower);
      if (idx >= 0) out.push({
        u: u,
        idx: idx,
        len: uname.length
      });
    }
    out.sort(function (a, b) {
      if (a.idx !== b.idx) return a.idx - b.idx;
      if (a.len !== b.len) return a.len - b.len;
      return a.u.username.localeCompare(b.u.username);
    });
    return out.slice(0, 5).map(function (x) {
      return x.u;
    });
  }
  function rankUsers(list, term) {
    if (!list || !list.length) return [];
    if (!term) return list.slice(0, 5);
    var lower = term.toLowerCase();
    var scored = [];
    for (var i = 0; i < list.length; i++) {
      var u = list[i];
      if (!u || !u.username) continue;
      var uname = u.username.toLowerCase();
      var idx = uname.indexOf(lower);
      if (idx < 0) continue;
      scored.push({
        u: u,
        idx: idx,
        len: uname.length
      });
    }
    scored.sort(function (a, b) {
      if (a.idx !== b.idx) return a.idx - b.idx;
      if (a.len !== b.len) return a.len - b.len;
      return a.u.username.localeCompare(b.u.username);
    });
    return scored.slice(0, 5).map(function (x) {
      return x.u;
    });
  }
  mentionDrop.addEventListener('mousedown', function (e) {
    e.preventDefault();
  });
  textarea.addEventListener('input', function () {
    if (textarea.readOnly) return;
    clearTimeout(mentionTimer);
    var val = textarea.value;
    var pos = textarea.selectionStart || 0;
    var before = val.substring(0, pos);
    var match = before.match(/(?:^|\\s)@([\\w.-]*)$/);
    if (!match) {
      closeMention();
      return;
    }
    var term = match[1];
    if (!term || term.length < 1) {
      var localEmpty = filterLocal('');
      if (localEmpty.length) {
        mentionStart = before.length - 1;
        renderUsers(localEmpty);
        return;
      }
      closeMention();
      return;
    }
    mentionStart = before.length - term.length - 1;
    if (term === lastTerm && mentionDrop.style.display === 'block') return;
    lastTerm = term;
    mentionTimer = setTimeout(function () {
      var url = '/u/search/users.json?term=' + encodeURIComponent(term) + '&include_groups=false';
      if (topicId) url += '&topic_id=' + encodeURIComponent(topicId);
      api(url).then(function (d) {
        var users = d.users || [];
        var ranked = rankUsers(users, term);
        if (!ranked.length) {
          var localUsers = filterLocal(term);
          if (localUsers.length) {
            renderUsers(localUsers);
            return;
          }
          closeMention();
          return;
        }
        renderUsers(ranked);
      }).catch(function () {
        var localUsers = filterLocal(term);
        if (localUsers.length) {
          renderUsers(localUsers);
          return;
        }
        closeMention();
      });
    }, 200);
  });
  textarea.addEventListener('keydown', function (e) {
    if (mentionDrop.style.display === 'none') return;
    if (e.key === 'ArrowDown') {
      e.preventDefault();
      setActive(mentionIdx < 0 ? 0 : mentionIdx + 1);
    }
    if (e.key === 'ArrowUp') {
      e.preventDefault();
      if (!mentionItems.length) return;
      setActive(mentionIdx <= 0 ? mentionItems.length - 1 : mentionIdx - 1);
    }
    if (e.key === 'Enter' && mentionIdx >= 0 && mentionItems[mentionIdx]) {
      e.preventDefault();
      insertMention(mentionItems[mentionIdx].dataset.username);
    }
    if (e.key === 'Escape') {
      e.preventDefault();
      closeMention();
    }
  });
}
function updateChipActions(container) {
  if (!container) return;
  container.classList.remove('compact', 'compact2');
  var buttons = container.querySelectorAll('button');
  if (!buttons.length) return;
  if (container.scrollWidth > container.clientWidth) {
    container.classList.add('compact');
  }
  if (container.scrollWidth > container.clientWidth) {
    container.classList.add('compact2');
  }
}
function refreshComposeActions() {
  var containers = document.querySelectorAll('.chip-actions');
  for (var i = 0; i < containers.length; i++) {
    updateChipActions(containers[i]);
  }
}
window.addEventListener('resize', function () {
  setTimeout(refreshComposeActions, 60);
});
function timeAgo(dateStr) {
  if (!dateStr) return '';
  var s = Math.floor((Date.now() - new Date(dateStr).getTime()) / 1000);
  if (s < 60) return 'now';
  if (s < 3600) return Math.floor(s / 60) + 'm';
  if (s < 86400) return Math.floor(s / 3600) + 'h';
  if (s < 2592000) return Math.floor(s / 86400) + 'd';
  return Math.floor(s / 2592000) + 'mo';
}
function formatDate(dateStr) {
  if (!dateStr) return '';
  var d = new Date(dateStr);
  if (isNaN(d.getTime())) return '';
  var months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return months[d.getMonth()] + ' ' + d.getDate() + ', ' + d.getFullYear();
}
function normalizeUrl(url) {
  if (!url) return '';
  if (url.indexOf('http://') === 0 || url.indexOf('https://') === 0 || url.indexOf('//') === 0) return url;
  return 'http://' + url;
}
function avatarUrl(tpl, size) {
  if (!tpl) return '';
  var url = ASSET_BASE + tpl.replace('{size}', size || 48);
  rememberImage(url);
  return url;
}
var ASSET_BASE = location.hostname === 'localhost' || location.hostname === '127.0.0.1' ? PROXY : ORIGIN;
function isHttpUrl(url) {
  return url.indexOf('http://') === 0 || url.indexOf('https://') === 0;
}
function stripOrigin(url) {
  if (isHttpUrl(url) && url.indexOf(ORIGIN) === 0) return url.slice(ORIGIN.length);
  return url;
}
function rewriteSrc(url) {
  if (!url) return url;
  var u = stripOrigin(url);
  if (isHttpUrl(u) || u.indexOf('//') === 0) return url;
  if (u[0] === '/') return ASSET_BASE + u;
  return url;
}
function rewriteHref(url) {
  if (!url) return url;
  if (url.indexOf('#') === 0 || url.indexOf('mailto:') === 0 || url.indexOf('javascript:') === 0) return url;
  var u = stripOrigin(url);
  if (isHttpUrl(u) || u.indexOf('//') === 0) return url;
  if (u[0] !== '/') return url;
  if (u.indexOf('/uploads/') === 0 || u.indexOf('/images/') === 0 || u.indexOf('/user_avatar/') === 0 || u.indexOf('/letter_avatar_proxy/') === 0 || u.indexOf('/emoji/') === 0) {
    return ASSET_BASE + u;
  }
  if (u === '/' || u.indexOf('/t/') === 0 || u.indexOf('/u/') === 0 || u.indexOf('/messages') === 0 || u.indexOf('/search') === 0 || u.indexOf('/notifications') === 0) {
    return makeUrl(u);
  }
  return ORIGIN + u;
}
function fixPostHtml(html) {
  if (!html) return '';
  return html.replace(/src="([^"]*?)"/g, function (m, url) {
    var finalUrl = rewriteSrc(url);
    rememberImage(finalUrl);
    return 'src="' + finalUrl + '"';
  }).replace(/href="([^"]*?)"/g, function (m, url) {
    return 'href="' + rewriteHref(url) + '"';
  }).replace(/srcset="[^"]*"/g, '');
}
var DETAILS_SUPPORTED = 'open' in document.createElement('details');
function enhanceCooked(container) {
  if (!container || !container.querySelectorAll) return;
  var spoilers = container.querySelectorAll('.spoiler, .spoiler-blurred');
  spoilers.forEach(function (el) {
    if (el.dataset.dumbSpoiler) return;
    el.dataset.dumbSpoiler = '1';
    if (!el.hasAttribute('tabindex')) el.setAttribute('tabindex', '0');
    el.setAttribute('role', 'button');
    var toggle = function toggle() {
      el.classList.toggle('revealed');
    };
    el.addEventListener('click', function () {
      toggle();
    });
    el.addEventListener('keydown', function (e) {
      if (e.key === 'Enter' || e.key === ' ') {
        e.preventDefault();
        toggle();
      }
    });
  });
  var detailsList = container.querySelectorAll('details');
  detailsList.forEach(function (details) {
    if (details.dataset.dumbDetails) return;
    details.dataset.dumbDetails = '1';
    var summary = details.querySelector('summary');
    if (summary) {
      if (!summary.hasAttribute('tabindex')) summary.setAttribute('tabindex', '0');
      summary.setAttribute('role', 'button');
    }
    var setOpen = function setOpen(open) {
      details.setAttribute('data-open', open ? '1' : '0');
      if (!DETAILS_SUPPORTED) {
        if (open) details.setAttribute('open', '');else details.removeAttribute('open');
      }
    };
    setOpen(details.hasAttribute('open'));
    if (DETAILS_SUPPORTED) {
      details.addEventListener('toggle', function () {
        setOpen(details.open);
      });
      if (summary) {
        summary.addEventListener('keydown', function (e) {
          if (e.key === 'Enter' || e.key === ' ') {
            e.preventDefault();
            details.open = !details.open;
          }
        });
      }
    } else if (summary) {
      summary.addEventListener('click', function (e) {
        e.preventDefault();
        setOpen(details.getAttribute('data-open') !== '1');
      });
      summary.addEventListener('keydown', function (e) {
        if (e.key === 'Enter' || e.key === ' ') {
          e.preventDefault();
          setOpen(details.getAttribute('data-open') !== '1');
        }
      });
    }
  });
  var dateEls = container.querySelectorAll('.discourse-local-date, time[datetime], abbr[title]');
  dateEls.forEach(function (el) {
    if (el.dataset.dumbDate) return;
    var dataDate = el.getAttribute('data-date');
    var dataTime = el.getAttribute('data-time');
    var raw = el.getAttribute('datetime') || dataDate || el.getAttribute('title') || el.textContent;
    if (!raw) return;
    var d;
    if (dataDate) {
      d = new Date(dataDate + (dataTime ? 'T' + dataTime + 'Z' : 'T00:00:00Z'));
    } else {
      d = new Date(raw);
    }
    if (isNaN(d.getTime())) return;
    var label = formatDate(d.toISOString());
    if (dataTime || raw.indexOf('T') !== -1) {
      var hh = d.getHours();
      var mm = d.getMinutes();
      var ap = hh >= 12 ? 'PM' : 'AM';
      var h12 = hh % 12 || 12;
      label += ' ' + h12 + ':' + (mm < 10 ? '0' + mm : mm) + ' ' + ap;
    }
    el.textContent = label;
    el.dataset.dumbDate = '1';
  });
  var links = container.querySelectorAll('a');
  links.forEach(function (a) {
    if (a.dataset.dumbLink) return;
    a.dataset.dumbLink = '1';
    if (!a.hasAttribute('tabindex')) a.setAttribute('tabindex', '0');
    a.addEventListener('keydown', function (e) {
      if (e.key === 'Enter' || e.key === ' ') {
        e.preventDefault();
        a.click();
      }
    });
  });
  var pollOptions = container.querySelectorAll('.poll-option');
  pollOptions.forEach(function (opt) {
    if (opt.dataset.dumbPoll) return;
    opt.dataset.dumbPoll = '1';
    opt.setAttribute('role', 'button');
    if (!opt.hasAttribute('tabindex')) opt.setAttribute('tabindex', '0');
    opt.addEventListener('keydown', function (e) {
      if (e.key === 'Enter' || e.key === ' ') {
        e.preventDefault();
        opt.click();
      }
    });
  });
}
var IC = {
  heart: '<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M20.84 4.61a5.5 5.5 0 0 0-7.78 0L12 5.67l-1.06-1.06a5.5 5.5 0 0 0-7.78 7.78l1.06 1.06L12 21.23l7.78-7.78 1.06-1.06a5.5 5.5 0 0 0 0-7.78z"/></svg>',
  bookmark: '<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M19 21l-7-5-7 5V5a2 2 0 0 1 2-2h10a2 2 0 0 1 2 2z"/></svg>',
  reply: '<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="9 17 4 12 9 7"/><path d="M20 18v-2a4 4 0 0 0-4-4H4"/></svg>',
  quote: '<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M7 17H5a3 3 0 0 1-3-3V8a3 3 0 0 1 3-3h6v6H7v6z"/><path d="M19 17h-2a3 3 0 0 1-3-3V8a3 3 0 0 1 3-3h6v6h-4v6z"/></svg>',
  edit: '<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M11 4H4a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-7"/><path d="M18.5 2.5a2.121 2.121 0 0 1 3 3L12 15l-4 1 1-4 9.5-9.5z"/></svg>',
  trash: '<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="3 6 5 6 21 6"/><path d="M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6m3 0V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2"/></svg>',
  send: '<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><line x1="22" y1="2" x2="11" y2="13"/><polygon points="22 2 15 22 11 13 2 9 22 2"/></svg>',
  x: '<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></svg>',
  plus: '<svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><line x1="12" y1="5" x2="12" y2="19"/><line x1="5" y1="12" x2="19" y2="12"/></svg>',
  upload: '<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/><polyline points="17 8 12 3 7 8"/><line x1="12" y1="3" x2="12" y2="15"/></svg>',
  preview: '<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M1 12s4-7 11-7 11 7 11 7-4 7-11 7S1 12 1 12z"/><circle cx="12" cy="12" r="3"/></svg>',
  hidePreview: '<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M17.94 17.94A10.94 10.94 0 0 1 12 20C5 20 1 12 1 12a21.77 21.77 0 0 1 5.06-6.94"/><path d="M9.9 4.24A10.94 10.94 0 0 1 12 4c7 0 11 8 11 8a21.72 21.72 0 0 1-3.06 4.44"/><path d="M14.12 14.12A3 3 0 0 1 9.88 9.88"/><line x1="1" y1="1" x2="23" y2="23"/></svg>',
  refine: '<svg width="14" height="14" viewBox="0 0 24 24" fill="currentColor"><path d="M12,1L9,9L1,12L9,15L12,23L15,15L23,12L15,9L12,1Z" /></svg>',
  msg: '<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z"/></svg>',
  bell: '<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M18 8A6 6 0 0 0 6 8c0 7-3 9-3 9h18s-3-2-3-9"/><path d="M13.73 21a2 2 0 0 1-3.46 0"/></svg>',
  flag: '<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M4 15s1-1 4-1 5 2 8 2 4-1 4-1V3s-1 1-4 1-5-2-8-2-4 1-4 1z"/><line x1="4" y1="22" x2="4" y2="15"/></svg>',
  lock: '<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="11" width="18" height="11" rx="2" ry="2"/><path d="M7 11V7a5 5 0 0 1 10 0v4"/></svg>',
  pin: '<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 2v8"/><circle cx="12" cy="14" r="4"/><path d="M12 18v4"/></svg>',
  smile: '<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="10"/><path d="M8 14s1.5 2 4 2 4-2 4-2"/><line x1="9" y1="9" x2="9.01" y2="9"/><line x1="15" y1="9" x2="15.01" y2="9"/></svg>',
  shield: '<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"/></svg>',
  eye: '<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="2"/><path d="M21 12c-2.5 4.5-5.5 6.5-9 6.5S5.5 16.5 3 12c2.5-4.5 5.5-6.5 9-6.5s6.5 2 9 6.5z"/></svg>',
  clock: '<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="10"/><polyline points="12 6 12 12 16 14"/></svg>',
  wrench: '<svg viewBox="0 0 512 512" fill="currentColor" aria-hidden="true"><path d="M78.6 5C69.1-2.4 55.6-1.5 47 7L7 47c-8.5 8.5-9.4 22-2.1 31.6l80 104c4.5 5.9 11.6 9.4 19 9.4h54.1l109 109c-14.7 29-10 65.4 14.3 89.6l112 112c12.5 12.5 32.8 12.5 45.3 0l64-64c12.5-12.5 12.5-32.8 0-45.3l-112-112c-24.2-24.2-60.6-29-89.6-14.3l-109-109V104c0-7.5-3.5-14.5-9.4-19L78.6 5zM19.9 396.1C7.2 408.8 0 426.1 0 444.1C0 481.6 30.4 512 67.9 512c18 0 35.3-7.2 48-19.9L233.7 374.3c-7.8-20.9-9-43.6-3.6-65.1l-61.7-61.7L19.9 396.1zM512 144c0-10.5-1.1-20.7-3.2-30.5c-2.4-11.2-16.1-14.1-24.2-6l-63.9 63.9c-3 3-7.1 4.7-11.3 4.7H352c-8.8 0-16-7.2-16-16V102.6c0-4.2 1.7-8.3 4.7-11.3l63.9-63.9c8.1-8.1 5.2-21.8-6-24.2C388.7 1.1 378.5 0 368 0C288.5 0 224 64.5 224 144l0 .8 85.3 85.3c36-9.1 75.8 .5 104 28.7L429 274.5c49-23 83-72.8 83-130.5zM56 432a24 24 0 1 1 48 0 24 24 0 1 1 -48 0z"/></svg>',
  diamond: '<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M6 3h12l4 6-10 12L2 9z"/></svg>',
  star: '<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polygon points="12 2 15 8.5 22 9.3 17 14 18.5 21 12 17.5 5.5 21 7 14 2 9.3 9 8.5 12 2"/></svg>',
  check: '<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="20 6 9 17 4 12"/></svg>',
  thumb: '<svg viewBox="0 0 512 512" fill="currentColor" aria-hidden="true"><path d="M313.4 32.9c26 5.2 42.9 30.5 37.7 56.5l-2.3 11.4c-5.3 26.7-15.1 52.1-28.8 75.2H464c26.5 0 48 21.5 48 48c0 18.5-10.5 34.6-25.9 42.6C497 275.4 504 288.9 504 304c0 23.4-16.8 42.9-38.9 47.1c4.4 7.3 6.9 15.8 6.9 24.9c0 21.3-13.9 39.4-33.1 45.6c.7 3.3 1.1 6.8 1.1 10.4c0 26.5-21.5 48-48 48H294.5c-19 0-37.5-5.6-53.3-16.1l-38.5-25.7C176 420.4 160 390.4 160 358.3V320 272 247.1c0-29.2 13.3-56.7 36-75l7.4-5.9c26.5-21.2 44.6-51 51.2-84.2l2.3-11.4c5.2-26 30.5-42.9 56.5-37.7zM32 192H96c17.7 0 32 14.3 32 32V448c0 17.7-14.3 32-32 32H32c-17.7 0-32-14.3-32-32V224c0-17.7 14.3-32 32-32z"/></svg>',
  undo: '<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M3 7v6h6"/><path d="M21 17a9 9 0 0 0-9-9 9 9 0 0 0-6 2.3L3 13"/></svg>',
  gear: '<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="3"/><path d="M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 0 1 0 2.83 2 2 0 0 1-2.83 0l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 0 1-2 2 2 2 0 0 1-2-2v-.09A1.65 1.65 0 0 0 9 19.4a1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 0 1-2.83 0 2 2 0 0 1 0-2.83l.06-.06a1.65 1.65 0 0 0 .33-1.82 1.65 1.65 0 0 0-1.51-1H3a2 2 0 0 1-2-2 2 2 0 0 1 2-2h.09A1.65 1.65 0 0 0 4.6 9a1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 0 1 0-2.83 2 2 0 0 1 2.83 0l.06.06a1.65 1.65 0 0 0 1.82.33H9a1.65 1.65 0 0 0 1-1.51V3a2 2 0 0 1 2-2 2 2 0 0 1 2 2v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 0 1 2.83 0 2 2 0 0 1 0 2.83l-.06.06a1.65 1.65 0 0 0-.33 1.82V9a1.65 1.65 0 0 0 1.51 1H21a2 2 0 0 1 2 2 2 2 0 0 1-2 2h-.09a1.65 1.65 0 0 0-1.51 1z"/></svg>'
};
var REACTION_EMOJI = {
  '+1': '\uD83D\uDC4D',
  'folded_hands': '\uD83D\uDE4F',
  'laughing': '\uD83D\uDE02',
  'ok_hand': '\uD83D\uDC4C',
  'man_shrugging': '\uD83E\uDD37\u200D\u2642\uFE0F'
};
var REACTION_LIST = ['+1', 'folded_hands', 'laughing', 'ok_hand', 'man_shrugging'];
function catBadge(id) {
  var c = S.categories[id];
  if (!c) return '';
  var bg = c.color ? '#' + c.color : '#666';
  if (!showCategoryNames) {
    var iconUrl = pickIconUrl(c.uploaded_logo) || pickIconUrl(c.uploaded_logo_dark) || pickIconUrl(c.logo_url) || pickIconUrl(c.logo) || pickIconUrl(c.icon_url) || pickIconUrl(c.icon);
    if (!iconUrl && c.custom_fields) {
      iconUrl = pickIconUrl(c.custom_fields.category_icon) || pickIconUrl(c.custom_fields.icon) || pickIconUrl(c.custom_fields.category_logo);
    }
    if (iconUrl) {
      var finalUrl = rewriteSrc(iconUrl);
      return `<span class="cat-icon cat-icon--image" style="color:${bg}" title="${esc(c.name)}" aria-label="${esc(c.name)}"><img src="${finalUrl}" alt="" loading="lazy"></span>`;
    }
    return `<span class="cat-icon" style="color:${bg}" title="${esc(c.name)}" aria-label="${esc(c.name)}"></span>`;
  }
  return `<span class="cat" style="color:${bg};border-color:${bg}">${esc(c.name)}</span>`;
}
function pickIconUrl(value) {
  if (!value) return '';
  if (typeof value === 'string') return value;
  if (typeof value === 'object') return value.url || value.src || value.path || '';
  return '';
}
function mergeCategories(list) {
  (list || []).forEach(function (c) {
    if (!c || !c.id) return;
    S.categories[c.id] = c;
  });
}
function isMobileLayout() {
  return window.matchMedia && window.matchMedia('(max-width: 680px)').matches;
}
function shouldShowTopicPosters() {
  if (!topicPostersVisibility || topicPostersVisibility === 'none') return false;
  if (topicPostersVisibility === 'all') return true;
  return isMobileLayout() ? topicPostersVisibility === 'mobile' : topicPostersVisibility === 'desktop';
}
function isUserOnline(u) {
  if (DUMBCOURSE_SETTINGS && DUMBCOURSE_SETTINGS.onlineGlowEnabled === false) return false;
  if (!u) return false;
  if (typeof u.is_online === 'boolean') return u.is_online;
  if (typeof u.online === 'boolean') return u.online;
  if (u.status && typeof u.status.is_online === 'boolean') return u.status.is_online;
  return false;
}
function topicPostersHtml(t) {
  if (!shouldShowTopicPosters()) return '';
  var posters = (t.posters || []).map(function (p) {
    return p && p.user_id;
  }).filter(Boolean);
  if (!posters.length) return '';
  var seen = {};
  var users = posters.map(function (id) {
    return TOPIC_USERS[id];
  }).filter(function (u) {
    return u && u.id && u.username && u.avatar_template;
  });
  var uniq = [];
  users.forEach(function (u) {
    if (seen[u.id]) return;
    seen[u.id] = true;
    uniq.push(u);
  });
  if (!uniq.length) return '';
  return `<div class="topic-posters">${uniq.slice(0, 5).map(function (u) {
    return `<span class="topic-poster" title="${esc(u.username)}"><img class="topic-poster-avatar${isUserOnline(u) ? ' topic-poster-avatar--online' : ''}" src="${avatarUrl(u.avatar_template, 40)}" alt="" loading="lazy"></span>`;
  }).join('')}</div>`;
}
function loadCategories() {
  return _loadCategories.apply(this, arguments);
}
function _loadCategories() {
  _loadCategories = _asyncToGenerator(/*#__PURE__*/_regenerator().m(function _callee14() {
    var d, _t14;
    return _regenerator().w(function (_context14) {
      while (1) switch (_context14.p = _context14.n) {
        case 0:
          _context14.p = 1;
          _context14.n = 2;
          return api('/categories.json');
        case 2:
          d = _context14.v;
          mergeCategories(d.category_list && d.category_list.categories || []);
          _context14.n = 4;
          break;
        case 3:
          _context14.p = 3;
          _t14 = _context14.v;
        case 4:
          return _context14.a(2);
      }
    }, _callee14, null, [[1, 3]]);
  }));
  return _loadCategories.apply(this, arguments);
}
function confirm(msg) {
  return new Promise(function (resolve) {
    var prev = document.activeElement;
    var el = document.createElement('div');
    el.className = 'confirm-overlay';
    el.innerHTML = `<div class="confirm-box"><p>${esc(msg)}</p><div class="actions">
      <button class="cancel" style="background:var(--bg3);color:var(--fg)" tabindex="0">Cancel</button>
      <button class="ok" tabindex="0">Confirm</button></div></div>`;
    document.body.appendChild(el);
    var okBtn = el.querySelector('.ok');
    var cancelBtn = el.querySelector('.cancel');
    okBtn.focus();
    var doOk = function doOk() {
      el.remove();
      if (prev && prev.focus) prev.focus();
      resolve(true);
    };
    var doCancel = function doCancel() {
      el.remove();
      if (prev && prev.focus) prev.focus();
      resolve(false);
    };
    okBtn.onclick = doOk;
    cancelBtn.onclick = doCancel;
    el.onclick = function (e) {
      if (e.target === el) doCancel();
    };
    el.addEventListener('keydown', function (e) {
      if (e.key === 'Escape') {
        e.stopPropagation();
        doCancel();
      }
      if (e.key === 'Tab') {
        var els = [cancelBtn, okBtn];
        var idx = els.indexOf(document.activeElement);
        if (e.shiftKey) {
          els[(idx - 1 + els.length) % els.length].focus();
        } else {
          els[(idx + 1) % els.length].focus();
        }
        e.preventDefault();
      }
    });
  });
}
function renderLogin() {
  document.body.classList.add('auth-mode');
  setTitle(SITE_TITLE);
  document.title = 'Sign in - ' + SITE_TITLE + ' Dumbcourse';
  showBack(false);
  $app.innerHTML = `
    <div class="login-box">
      <h2 id="loginTitle">${SITE_TITLE}</h2>
      <p id="loginNote">Sign in to ${SITE_TITLE}.</p>
      <div class="field"><label for="loginUser">Username or Email</label>
        <input type="text" id="loginUser" placeholder="Username or email" tabindex="0"></div>
      <div class="field"><label for="loginPass">Password</label>
        <input type="password" id="loginPass" placeholder="Password" tabindex="0"></div>
      <div id="loginError" class="error" style="display:none"></div>
      <button id="loginBtn" style="width:100%" tabindex="0">Sign In</button>
      <div id="loginDivider" class="login-divider"><span>or</span></div>
      <a id="signupLink" class="link-btn" href="${BASE_PATH}/signup" tabindex="0">Create Account</a>
    </div>`;
  var doLogin = /*#__PURE__*/function () {
    var _ref = _asyncToGenerator(/*#__PURE__*/_regenerator().m(function _callee() {
      var login, password, errEl, btn, headers, body, resp, newToken, newCsrf, newCookies, d, user, _t, _t2;
      return _regenerator().w(function (_context) {
        while (1) switch (_context.p = _context.n) {
          case 0:
            login = document.getElementById('loginUser').value.trim();
            password = document.getElementById('loginPass').value;
            errEl = document.getElementById('loginError');
            btn = document.getElementById('loginBtn');
            if (!(!login || !password)) {
              _context.n = 1;
              break;
            }
            errEl.textContent = 'Both fields are required';
            errEl.style.display = 'block';
            return _context.a(2);
          case 1:
            btn.disabled = true;
            btn.textContent = 'Signing in...';
            errEl.style.display = 'none';
            _context.p = 2;
            _context.p = 3;
            _context.n = 4;
            return ensureCsrf();
          case 4:
            _context.n = 7;
            break;
          case 6:
            _context.p = 6;
            _t = _context.v;
          case 7:
            headers = {
              'Content-Type': 'application/x-www-form-urlencoded',
              'Accept': 'application/json',
              'X-Requested-With': 'XMLHttpRequest'
            };
            if (S.csrf) headers['X-CSRF-Token'] = S.csrf;
            if (S.token) headers['X-Session-Token'] = S.token;
            if (S.cookies) headers['X-Cookies'] = S.cookies;
            body = `login=${encodeURIComponent(login)}&password=${encodeURIComponent(password)}`;
            _context.n = 8;
            return fetch(PROXY + '/session.json', {
              method: 'POST',
              headers,
              body,
              credentials: 'same-origin'
            });
          case 8:
            resp = _context.v;
            newToken = resp.headers.get('X-Session-Token');
            if (newToken) {
              S.token = newToken;
              storageSet('jt_session_token', newToken);
            }
            newCsrf = resp.headers.get('X-CSRF-Token');
            if (newCsrf) {
              S.csrf = newCsrf;
              storageSet('jt_csrf', newCsrf);
            }
            newCookies = resp.headers.get('X-Cookies');
            if (newCookies) {
              S.cookies = newCookies;
              storageSet('jt_cookies', newCookies);
            }
            _context.n = 9;
            return resp.json();
          case 9:
            d = _context.v;
            if (!d.error) {
              _context.n = 10;
              break;
            }
            throw new Error(d.error);
          case 10:
            if (resp.ok) {
              _context.n = 11;
              break;
            }
            throw new Error(d.errors && d.errors.join(', ') || 'Login failed');
          case 11:
            user = d.user || {};
            S.username = user.username || login;
            S.userId = user.id || '';
            storageSet('jt_username', S.username);
            storageSet('jt_user_id', S.userId);
            storageSet('jt_logged_in', '1');
            S.authChecked = true;
            clearApiCache();
            return refreshCurrentUser().then(function (ok) {
              if (!ok) throw new Error('Login failed. Please try again.');
              window.location.href = makeUrl('/');
            });
            _context.n = 13;
            break;
          case 12:
            _context.p = 12;
            _t2 = _context.v;
            errEl.textContent = _t2.message;
            errEl.style.display = 'block';
            btn.disabled = false;
            btn.textContent = 'Sign In';
          case 13:
            return _context.a(2);
        }
      }, _callee, null, [[3, 6], [2, 12]]);
    }));
    return function doLogin() {
      return _ref.apply(this, arguments);
    };
  }();
  document.getElementById('loginBtn').addEventListener('click', doLogin);
  document.getElementById('loginPass').addEventListener('keydown', function (e) {
    if (e.key === 'Enter') doLogin();
  });
  document.getElementById('loginUser').addEventListener('keydown', function (e) {
    if (e.key === 'Enter') document.getElementById('loginPass').focus();
  });
  updateSiteUI();
}
function renderSignup() {
  document.body.classList.add('auth-mode');
  setTitle(SITE_TITLE);
  document.title = 'Create account - ' + SITE_TITLE + ' Dumbcourse';
  showBack(true);
  if (SITE_SETTINGS.allowSignup === false) {
    $app.innerHTML = `<div class="login-box">
      <h2 id="signupTitle">${SITE_TITLE}</h2>
      <p id="signupNote">Create your account on ${SITE_TITLE}.</p>
      <div class="error">Account creation is disabled on this site.</div>
      <a class="link-btn" href="${BASE_PATH}/" tabindex="0">Back to Sign In</a>
    </div>`;
    updateSiteUI();
    return;
  }
  var showName = SITE_SETTINGS.fullNameVisible || SITE_SETTINGS.fullNameRequired;
  var nameLabel = SITE_SETTINGS.fullNameRequired ? 'Full Name' : 'Full Name (optional)';
  var nameField = showName ? `<div class="field"><label for="signupName">${nameLabel}</label>
        <input type="text" id="signupName" placeholder="Your name" tabindex="0"></div>` : '';
  var userFields = Array.isArray(SITE_SETTINGS.userFields) ? SITE_SETTINGS.userFields.slice() : [];
  userFields = userFields.filter(function (f) {
    return f && (f.show_on_signup || f.required);
  }).sort(function (a, b) {
    return (a.position || 0) - (b.position || 0);
  });
  var userFieldHtml = userFields.map(function (f) {
    var fid = 'signupField_' + f.id;
    var label = esc(f.name || 'Field');
    var required = f.required ? ' *' : '';
    var reqAttr = f.required ? ' required' : '';
    var maxAttr = SITE_SETTINGS.userFieldMaxLength ? ' maxlength="' + SITE_SETTINGS.userFieldMaxLength + '"' : '';
    var desc = f.description ? `<div class="field-note">${esc(f.description)}</div>` : '';
    if (f.field_type === 'dropdown' || f.field_type === 'multiselect') {
      var options = (f.options || []).map(function (opt) {
        var o = esc(opt);
        return `<option value="${o}">${o}</option>`;
      }).join('');
      var emptyOpt = f.required ? '' : '<option value="">Select</option>';
      var multi = f.field_type === 'multiselect' ? ' multiple' : '';
      return `<div class="field"><label for="${fid}">${label}${required}</label><select id="${fid}"${multi}${reqAttr} tabindex="0">${emptyOpt}${options}</select>${desc}</div>`;
    }
    if (f.field_type === 'checkbox' || f.field_type === 'confirm') {
      return `<div class="field"><label for="${fid}">${label}${required}</label><input type="checkbox" id="${fid}"${reqAttr} tabindex="0">${desc}</div>`;
    }
    return `<div class="field"><label for="${fid}">${label}${required}</label><input type="text" id="${fid}" placeholder="${label}"${reqAttr}${maxAttr} tabindex="0">${desc}</div>`;
  }).join('');
  $app.innerHTML = `
    <div class="login-box">
      <h2 id="signupTitle">${SITE_TITLE}</h2>
      <p id="signupNote">Create your account on ${SITE_TITLE}.</p>
      ${nameField}
      ${userFieldHtml}
      <div class="field"><label for="signupUser">Username</label>
        <input type="text" id="signupUser" placeholder="Username" tabindex="0"></div>
      <div class="field"><label for="signupEmail">Email</label>
        <input type="email" id="signupEmail" placeholder="Email" tabindex="0"></div>
      <div class="field"><label for="signupPass">Password</label>
        <input type="password" id="signupPass" placeholder="Password" tabindex="0"></div>
      <div class="field"><label for="signupPass2">Confirm Password</label>
        <input type="password" id="signupPass2" placeholder="Confirm password" tabindex="0"></div>
      <div id="hcaptchaBox" class="field hcaptcha-box" style="display:none">
        <div id="hcaptchaField"></div>
        <div id="hcaptchaError" class="error" style="display:none"></div>
      </div>
      <div id="signupError" class="error" style="display:none"></div>
      <div id="signupSuccess" class="success" style="display:none"></div>
      <button id="signupBtn" style="width:100%" tabindex="0">Create Account</button>
      <div class="login-divider"><span>or</span></div>
      <a class="link-btn" href="${BASE_PATH}/" tabindex="0">Back to Sign In</a>
    </div>`;
  renderHCaptchaBox();
  function getUserFieldValue(field) {
    if (!field || !field.id) return '';
    var el = document.getElementById('signupField_' + field.id);
    if (!el) return '';
    if (field.field_type === 'checkbox' || field.field_type === 'confirm') {
      return el.checked ? 'true' : '';
    }
    if (field.field_type === 'multiselect' && el.options) {
      var vals = [];
      for (var i = 0; i < el.options.length; i++) {
        if (el.options[i].selected) vals.push(el.options[i].value);
      }
      return vals;
    }
    return (el.value || '').trim();
  }
  var doSignup = function doSignup() {
    var name = showName ? document.getElementById('signupName').value.trim() : '';
    var username = document.getElementById('signupUser').value.trim();
    var email = document.getElementById('signupEmail').value.trim();
    var pass = document.getElementById('signupPass').value;
    var pass2 = document.getElementById('signupPass2').value;
    var errEl = document.getElementById('signupError');
    var okEl = document.getElementById('signupSuccess');
    var btn = document.getElementById('signupBtn');
    var hcaptchaUsed = false;
    errEl.style.display = 'none';
    okEl.style.display = 'none';
    var userFieldValues = {};
    var missingField = '';
    if (userFields && userFields.length) {
      for (var i = 0; i < userFields.length; i++) {
        var f = userFields[i];
        var val = getUserFieldValue(f);
        var isEmpty = Array.isArray(val) ? val.length === 0 : !val;
        if (f.required && isEmpty && !missingField) {
          missingField = (f.name || 'A required field') + ' is required';
        }
        if (!isEmpty) userFieldValues[f.id] = val;
      }
    }
    if (!username || !email || !pass || !pass2 || showName && SITE_SETTINGS.fullNameRequired && !name || missingField) {
      errEl.textContent = missingField || 'All required fields must be filled';
      errEl.style.display = 'block';
      return;
    }
    if (pass !== pass2) {
      errEl.textContent = 'Passwords do not match';
      errEl.style.display = 'block';
      return;
    }
    var emailOk = /.+@.+\..+/.test(email);
    if (!emailOk) {
      errEl.textContent = 'Please enter a valid email address';
      errEl.style.display = 'block';
      return;
    }
    btn.disabled = true;
    btn.textContent = 'Creating...';
    ensureCsrf().then(function () {
      return ensureHoneypot();
    }).then(function (hp) {
      if (!hp || !hp.value || !hp.challenge) {
        throw new Error('Unable to start signup. Please reload and try again.');
      }
      return api('/u/check_username.json?username=' + encodeURIComponent(username), {
        nocache: true,
        nodup: true
      }).then(function (usernameCheck) {
        if (usernameCheck && usernameCheck.errors && usernameCheck.errors.length) {
          throw new Error(usernameCheck.errors.join(', '));
        }
        if (usernameCheck && usernameCheck.available === false) {
          throw new Error('Username is not available');
        }
        return api('/u/check_email.json?email=' + encodeURIComponent(email), {
          nocache: true,
          nodup: true
        }).then(function (emailCheck) {
          if (emailCheck && emailCheck.errors && emailCheck.errors.length) {
            throw new Error(emailCheck.errors.join(', '));
          }
          return ensureHCaptchaToken().then(function (used) {
            if (used) hcaptchaUsed = true;
            var headers = {
              'Content-Type': 'application/x-www-form-urlencoded',
              'Accept': 'application/json',
              'X-Requested-With': 'XMLHttpRequest'
            };
            if (S.csrf) headers['X-CSRF-Token'] = S.csrf;
            if (S.token) headers['X-Session-Token'] = S.token;
            if (S.cookies) headers['X-Cookies'] = S.cookies;
            var params = [];
            params.push('name=' + encodeURIComponent(name));
            params.push('username=' + encodeURIComponent(username));
            params.push('email=' + encodeURIComponent(email));
            params.push('password=' + encodeURIComponent(pass));
            params.push('password_confirmation=' + encodeURIComponent(hp.value));
            params.push('challenge=' + encodeURIComponent(reverseString(hp.challenge)));
            Object.keys(userFieldValues).forEach(function (key) {
              var val = userFieldValues[key];
              if (Array.isArray(val)) {
                val.forEach(function (entry) {
                  params.push('user_fields[' + encodeURIComponent(key) + '][]=' + encodeURIComponent(entry));
                });
              } else {
                params.push('user_fields[' + encodeURIComponent(key) + ']=' + encodeURIComponent(val));
              }
            });
            var body = params.join('&');
            return fetch(PROXY + '/u', {
              method: 'POST',
              headers,
              body,
              credentials: 'same-origin'
            });
          });
        });
      });
    }).then(function (resp) {
      return resp.json().then(function (d) {
        return {
          resp: resp,
          data: d
        };
      });
    }).then(function (result) {
      var d = result.data;
      if (d && d.success) {
        var msg = stripHtml(d.message) || 'Account created. Check your email to activate.';
        okEl.textContent = msg;
        okEl.style.display = 'block';
        btn.disabled = false;
        btn.textContent = 'Create Account';
        return;
      }
      var msgErr = d && (d.error || d.message || d.errors && d.errors.join(', ')) || 'Sign up failed';
      throw new Error(stripHtml(msgErr));
    }).catch(function (e) {
      errEl.textContent = e.message;
      errEl.style.display = 'block';
    }).then(function () {
      if (hcaptchaUsed) resetHCaptcha();
      btn.disabled = false;
      btn.textContent = 'Create Account';
    });
  };
  document.getElementById('signupBtn').addEventListener('click', doSignup);
  document.getElementById('signupPass2').addEventListener('keydown', function (e) {
    if (e.key === 'Enter') doSignup();
  });
  document.getElementById('signupPass').addEventListener('keydown', function (e) {
    if (e.key === 'Enter') document.getElementById('signupPass2').focus();
  });
  document.getElementById('signupEmail').addEventListener('keydown', function (e) {
    if (e.key === 'Enter') document.getElementById('signupPass').focus();
  });
  document.getElementById('signupUser').addEventListener('keydown', function (e) {
    if (e.key === 'Enter') document.getElementById('signupEmail').focus();
  });
  updateSiteUI();
}
function logout() {
  return _logout.apply(this, arguments);
} // ============ TOPICS ============
function _logout() {
  _logout = _asyncToGenerator(/*#__PURE__*/_regenerator().m(function _callee15() {
    return _regenerator().w(function (_context15) {
      while (1) switch (_context15.n) {
        case 0:
          _context15.n = 1;
          return confirm('Log out of ' + SITE_TITLE + '?');
        case 1:
          if (_context15.v) {
            _context15.n = 2;
            break;
          }
          return _context15.a(2);
        case 2:
          try {
            unregisterPushNotifications().catch(function () {});
          } catch (e) {}
          closeWebPushBadges();
          try {
            api('/session/' + encodeURIComponent(S.username) + '.json', {
              method: 'DELETE'
            }).catch(function () {});
          } catch (e) {}
          S.token = '';
          S.csrf = '';
          S.cookies = '';
          S.username = '';
          S.userId = '';
          S.loggedIn = false;
          S.authChecked = true;
          S.admin = false;
          S.moderator = false;
          storageRemove('jt_session_token');
          storageRemove('jt_csrf');
          storageRemove('jt_cookies');
          storageRemove('jt_username');
          storageRemove('jt_user_id');
          storageSet('jt_logged_in', '0');
          storageSet('jt_admin', '0');
          storageSet('jt_moderator', '0');
          navigate('/');
        case 3:
          return _context15.a(2);
      }
    }, _callee15);
  }));
  return _logout.apply(this, arguments);
}
var TOPIC_VIEWS = [
  { key: 'latest', label: 'Latest', path: '/latest.json' },
  { key: 'new', label: 'New', path: '/new.json' },
  { key: 'top', label: 'Top', path: '/top.json?period=weekly' },
  { key: 'unseen', label: 'Unseen', path: '/unread.json' },
  { key: 'hot', label: 'Hot', path: '/hot.json' },
  { key: 'my', label: 'My Posts', path: function () { return S.username ? '/topics/created-by/' + encodeURIComponent(S.username) + '.json' : '/latest.json'; } }
];
var topicView = 'latest';
function viewConfig(key) {
  var v = (key || '').toLowerCase();
  for (var i = 0; i < TOPIC_VIEWS.length; i++) {
    if (TOPIC_VIEWS[i].key === v) return TOPIC_VIEWS[i];
  }
  return TOPIC_VIEWS[0];
}
function isTopicListPath(path) {
  var p = path || '/';
  if (p === '/' || p === '') return true;
  p = p.replace(/^\/+/, '');
  if (p === 'categories' || p.indexOf('c/') === 0) return true;
  for (var i = 0; i < TOPIC_VIEWS.length; i++) {
    if (TOPIC_VIEWS[i].key === p) return true;
  }
  return false;
}
function viewFromPath(path) {
  var p = (path || '').replace(/^\/+/, '');
  for (var i = 0; i < TOPIC_VIEWS.length; i++) {
    if (TOPIC_VIEWS[i].key === p) return TOPIC_VIEWS[i].key;
  }
  return '';
}
function buildViewUrl(viewKey, page) {
  var cfg = viewConfig(viewKey);
  var base = typeof cfg.path === 'function' ? cfg.path() : cfg.path;
  var sep = base.indexOf('?') >= 0 ? '&' : '?';
  var settings = window.DUMBCOURSE_SETTINGS || {};
  if (settings.paginationEnabled && settings.topicsPerPage) {
    base += sep + 'per_page=' + settings.topicsPerPage;
    sep = '&';
  }
  if (page && page > 0) {
    base += sep + 'page=' + page;
  }
  return base;
}
function emptyMessageForView(viewKey) {
  switch ((viewKey || '').toLowerCase()) {
    case 'new':
      return 'No new topics right now.';
    case 'top':
      return 'No top topics yet.';
    case 'unseen':
      return 'You read it all. No unseen topics.';
    case 'hot':
      return 'No hot topics right now.';
    case 'my':
      return 'You have not created any topics yet.';
    case 'latest':
    default:
      return 'No topics to show.';
  }
}
var topicPage = 0,
  topicLoading = false,
  topicMore = true,
  topicScrollCleanup = null;
function setupTopicPagination(currentPage, hasMore) {
  var perPage = window.DUMBCOURSE_SETTINGS && window.DUMBCOURSE_SETTINGS.topicsPerPage || 30;
  var pagination = document.getElementById('topicPagination');
  if (!pagination) return;
  var html = '';
  if (currentPage > 0) {
    html += '<button id="prevPageBtn" tabindex="0" style="background:var(--bg3);color:var(--fg);padding:10px 20px;font-size:1rem">← Prev</button>';
  }
  html += '<span style="color:var(--fg2);padding:10px">Page ' + (currentPage + 1) + '</span>';
  if (hasMore) {
    html += '<button id="nextPageBtn" tabindex="0" style="background:var(--bg3);color:var(--fg);padding:10px 20px;font-size:1rem">Next →</button>';
  }
  pagination.innerHTML = html;
  var prevBtn = document.getElementById('prevPageBtn');
  var nextBtn = document.getElementById('nextPageBtn');
  if (prevBtn) {
    prevBtn.addEventListener('click', function () {
      prevBtn.disabled = true;
      prevBtn.textContent = 'Loading...';
      api(buildViewUrl(topicView, currentPage - 1)).then(function (d) {
        var topics = d.topic_list && d.topic_list.topics || [];
        var list = document.getElementById('topicList');
        if (list) {
          list.innerHTML = topics.map(topicItemHtml).join('');
        }
        window.scrollTo(0, 0);
        setupTopicPagination(currentPage - 1, topics.length >= perPage);
        focusContent();
      }).catch(function (e) {
        showAlert(e.message || 'Failed to load');
        prevBtn.disabled = false;
        prevBtn.textContent = '← Prev';
      });
    });
  }
  if (nextBtn) {
    nextBtn.addEventListener('click', function () {
      nextBtn.disabled = true;
      nextBtn.textContent = 'Loading...';
      api(buildViewUrl(topicView, currentPage + 1)).then(function (d) {
        var topics = d.topic_list && d.topic_list.topics || [];
        var list = document.getElementById('topicList');
        if (list) {
          list.innerHTML = topics.map(topicItemHtml).join('');
        }
        window.scrollTo(0, 0);
        setupTopicPagination(currentPage + 1, topics.length >= perPage);
        focusContent();
      }).catch(function (e) {
        showAlert(e.message || 'Failed to load');
        nextBtn.disabled = false;
        nextBtn.textContent = 'Next →';
      });
    });
  }
}
var categoryPage = 0,
  categoryLoading = false,
  categoryMore = true,
  categoryView = null;

function buildCategoryUrl(cat, page) {
  if (!cat || !cat.id) return '/latest.json';
  var base = cat.slug ? '/c/' + cat.slug + '/' + cat.id + '.json' : '/c/' + cat.id + '.json';
  if (page && page > 0) {
    base += (base.indexOf('?') >= 0 ? '&' : '?') + 'page=' + page;
  }
  return base;
}

function loadMoreCategoryTopics() {
  return _loadMoreCategoryTopics.apply(this, arguments);
}
function _loadMoreCategoryTopics() {
  _loadMoreCategoryTopics = _asyncToGenerator(/*#__PURE__*/_regenerator().m(function _callee16c() {
    var loader, d, topics, list, _t16c;
    return _regenerator().w(function (_context16c) {
      while (1) switch (_context16c.p = _context16c.n) {
        case 0:
          if (!(categoryLoading || !categoryMore || !categoryView)) {
            _context16c.n = 1;
            break;
          }
          return _context16c.a(2);
        case 1:
          categoryLoading = true;
          loader = document.getElementById('topicLoader');
          if (loader) loader.style.display = 'block';
          _context16c.p = 2;
          _context16c.n = 3;
          return api(buildCategoryUrl(categoryView, categoryPage));
        case 3:
          d = _context16c.v;
          mergeTopicUsers(d.users || d.topic_list && d.topic_list.users || []);
          topics = d.topic_list && d.topic_list.topics || [];
          if (!topics.length) {
            categoryMore = false;
            if (loader) loader.textContent = 'No more topics in this category.';
          } else {
            list = document.getElementById('topicList');
            if (list) list.insertAdjacentHTML('beforeend', topics.map(topicItemHtml).join(''));
            categoryPage++;
          }
          _context16c.n = 5;
          break;
        case 4:
          _context16c.p = 4;
          _t16c = _context16c.v;
        case 5:
          categoryLoading = false;
          if (loader && categoryMore) loader.style.display = 'none';
        case 6:
          return _context16c.a(2);
      }
    }, _callee16c, null, [[2, 4]]);
  }));
  return _loadMoreCategoryTopics.apply(this, arguments);
}
function topicItemHtml(t) {
  var unread = isTopicUnread(t);
  var statusIcons = '';
  if (t.pinned) statusIcons += '<span class="topic-status-icon" title="Pinned">' + IC.pin + '</span>';
  if (t.closed || t.archived) statusIcons += '<span class="topic-status-icon" title="Locked">' + IC.lock + '</span>';
  if (statusIcons) statusIcons = '<span class="topic-status-group">' + statusIcons + '</span>';
  var views = t.views != null ? '<span>' + t.views + ' views</span>' : '';
  var posters = topicPostersHtml(t);
  var sideHtml = posters ? `<div class="topic-side">${posters}</div>` : '';
  // If unread, link to first unread post; otherwise go to last
  var firstUnread = null;
  if (unread) {
    if (typeof t.last_read_post_number === 'number' && t.last_read_post_number > 0) {
      firstUnread = t.last_read_post_number + 1;
    } else {
      firstUnread = 1;
    }
  }
  return `<a class="list-item${unread ? ' unread' : ''}" href="${topicHref(t.id, t.slug, firstUnread)}" tabindex="0" data-topic-id="${t.id}">
    <div class="topic-row">
      <div class="topic-main">
        <div class="item-title"><span class="item-title-text">${escEmoji(t.title)}</span>${statusIcons}</div>
        <div class="item-meta">
          ${catBadge(t.category_id)}
          <span class="meta-icon" title="Replies">${IC.msg}<span>${t.posts_count - 1}</span></span>
          ${views ? `<span class="meta-icon" title="Views">${IC.eye}<span>${t.views}</span></span>` : ''}
          <span class="meta-icon" title="Last active">${IC.clock}<span>${timeAgo(t.last_posted_at)}</span></span>
        </div>
        ${t.excerpt ? `<div class="item-excerpt">${t.excerpt}</div>` : ''}
      </div>
      ${sideHtml}
    </div>
  </a>`;
}
function loadMoreTopics() {
  return _loadMoreTopics.apply(this, arguments);
}
function _loadMoreTopics() {
  _loadMoreTopics = _asyncToGenerator(/*#__PURE__*/_regenerator().m(function _callee16() {
    var loader, d, topics, list, _t15;
    return _regenerator().w(function (_context16) {
      while (1) switch (_context16.p = _context16.n) {
        case 0:
          if (!(topicLoading || !topicMore)) {
            _context16.n = 1;
            break;
          }
          return _context16.a(2);
        case 1:
          topicLoading = true;
          loader = document.getElementById('topicLoader');
          if (loader) loader.style.display = 'block';
          _context16.p = 2;
          _context16.n = 3;
          return api(buildViewUrl(topicView, topicPage));
        case 3:
          d = _context16.v;
          mergeTopicUsers(d.users || d.topic_list && d.topic_list.users || []);
          topics = d.topic_list && d.topic_list.topics || [];
          if (!topics.length) {
            topicMore = false;
            if (loader) loader.textContent = emptyMessageForView(topicView);
          } else {
            list = document.getElementById('topicList');
            if (list) list.insertAdjacentHTML('beforeend', topics.map(topicItemHtml).join(''));
            topicPage++;
          }
          _context16.n = 5;
          break;
        case 4:
          _context16.p = 4;
          _t15 = _context16.v;
        case 5:
          topicLoading = false;
          if (loader && topicMore) loader.style.display = 'none';
        case 6:
          return _context16.a(2);
      }
    }, _callee16, null, [[2, 4]]);
  }));
  return _loadMoreTopics.apply(this, arguments);
}
function renderTopics(_x2) {
  return _renderTopics.apply(this, arguments);
} // ============ TOPIC DETAIL ============
function _renderTopics() {
  _renderTopics = _asyncToGenerator(/*#__PURE__*/_regenerator().m(function _callee17(viewKey) {
    var d, topics, html, onScroll, _cleanup, cfg;
    return _regenerator().w(function (_context17) {
      while (1) switch (_context17.n) {
        case 0:
          cfg = viewConfig(viewKey || defaultView);
          topicView = cfg.key;
          setActiveView(topicView);
          setTitle(SITE_TITLE);
          showBack(false);
          $app.innerHTML = '';
          _context17.n = 1;
          return loadCategories();
        case 1:
          topicPage = 0;
          topicMore = true;
          _context17.n = 2;
          return api(buildViewUrl(topicView, 0));
        case 2:
          d = _context17.v;
          mergeCategories(d.topic_list && d.topic_list.categories || []);
          mergeTopicUsers(d.users || d.topic_list && d.topic_list.users || []);
          topics = d.topic_list && d.topic_list.topics || [];
          if (topics.length) {
            _context17.n = 3;
            break;
          }
          $app.innerHTML = '<div class="empty">' + emptyMessageForView(topicView) + '</div>';
          return _context17.a(2);
        case 3:
          topicPage = 1;
          html = '<div id="topicList">';
          html += topics.map(topicItemHtml).join('');
          html += '</div>';
          var paginationEnabled = window.DUMBCOURSE_SETTINGS && window.DUMBCOURSE_SETTINGS.paginationEnabled;
          var perPage = window.DUMBCOURSE_SETTINGS && window.DUMBCOURSE_SETTINGS.topicsPerPage || 30;
          var hasMore = topics.length >= perPage;
          if (paginationEnabled) {
            html += '<div id="topicPagination" style="display:flex;gap:12px;justify-content:center;padding:16px">';
            html += '<button id="nextPageBtn" tabindex="0" style="background:var(--bg3);color:var(--fg);padding:10px 20px;font-size:1rem">Next →</button>';
            html += '</div>';
          } else {
            html += '<div id="topicLoader" class="loading" style="display:none">Loading more...</div>';
          }
          $app.innerHTML = html;
          showCreate('/new-topic');
          if (topicScrollCleanup) topicScrollCleanup();
          // Stop any existing polling
          if (TOPICS_POLL_INTERVAL) {
            clearInterval(TOPICS_POLL_INTERVAL);
            TOPICS_POLL_INTERVAL = null;
          }
          if (paginationEnabled) {
            setupTopicPagination(0, hasMore);
          } else {
            onScroll = function onScroll() {
              if (window.innerHeight + window.scrollY >= document.body.offsetHeight - 300) {
                loadMoreTopics();
              }
            };
            window.addEventListener('scroll', onScroll);
            _cleanup = function cleanup() {
              window.removeEventListener('scroll', onScroll);
              window.removeEventListener('popstate', _cleanup);
              if (TOPICS_POLL_INTERVAL) {
                clearInterval(TOPICS_POLL_INTERVAL);
                TOPICS_POLL_INTERVAL = null;
              }
              topicScrollCleanup = null;
            };
            topicScrollCleanup = _cleanup;
            window.addEventListener('popstate', _cleanup);
          }
          // Track known topic IDs to detect new ones
          var knownTopicIds = {};
          topics.forEach(function (t) { knownTopicIds[t.id] = true; });

          // Real-time updates via MessageBus (official Discourse method)
          function handleTopicMessage(data) {
            if (!data) return;
            var list = document.getElementById('topicList');
            if (!list) return;

            var topicId = data.topic_id;
            var messageType = data.message_type;

            // Handle new topic
            if (messageType === 'new_topic' && topicId && !knownTopicIds[topicId]) {
              knownTopicIds[topicId] = true;
              // Fetch the new topic data and prepend it
              api('/t/' + topicId + '.json').then(function (t) {
                if (!t || !t.id) return;
                var newItem = document.createElement('div');
                newItem.innerHTML = topicItemHtml({
                  id: t.id,
                  slug: t.slug,
                  title: t.title,
                  category_id: t.category_id,
                  posts_count: t.posts_count || 1,
                  views: t.views || 0,
                  last_posted_at: t.last_posted_at || t.created_at,
                  pinned: t.pinned,
                  closed: t.closed,
                  archived: t.archived,
                  unseen: true
                });
                var newLink = newItem.firstElementChild;
                if (newLink && list.firstChild) {
                  newLink.style.animation = 'fadeIn 0.3s ease';
                  newLink.style.background = 'var(--bg3)';
                  list.insertBefore(newLink, list.firstChild);
                  setTimeout(function () { newLink.style.background = ''; }, 5000);
                }
              }).catch(function () {});
            }

            // Handle unread/latest updates - toggle read/unread styling on existing topic
            if ((messageType === 'unread' || messageType === 'latest') && topicId) {
              var link = list.querySelector('a[data-topic-id="' + topicId + '"]');
              if (link) {
                // Fetch fresh topic data to get accurate counts
                api('/t/' + topicId + '.json', { nocache: true }).then(function (t) {
                  if (!t) return;
                  var hasUnread = isTopicUnread(t);
                  if (hasUnread) {
                    link.classList.add('unread');
                    // Update href to first unread
                    if (t.last_read_post_number > 0) {
                      var firstUnread = t.last_read_post_number + 1;
                      link.setAttribute('href', topicHref(topicId, t.slug, firstUnread));
                    }
                  } else {
                    link.classList.remove('unread');
                  }
                  // Move bumped topic to top of list
                  if (link && list.firstChild && link !== list.firstChild) {
                    link.parentNode.removeChild(link);
                    list.insertBefore(link, list.firstChild);
                    link.style.animation = 'fadeIn 0.3s ease';
                  }
                }).catch(function () {});
              }
            }
          }

          // Subscribe to MessageBus channels for real-time updates
          // Clear any stale subscriptions first
          var _existingMbChannels = Object.keys(MB.callbacks);
          _existingMbChannels.forEach(function(ch) { MB.unsubscribe(ch); });
          MB.subscribe('/new', handleTopicMessage);
          MB.subscribe('/latest', handleTopicMessage);
          MB.subscribe('/unread', handleTopicMessage);
          if (S.user && S.user.id) {
            MB.subscribe('/unread/' + S.user.id, handleTopicMessage);
            MB.subscribe('/private-messages/' + S.user.id, function (data) {
              refreshUnreadMessageCount();
              if (location.pathname === BASE_PATH + '/messages' || location.pathname === BASE_PATH + '/messages/') {
                renderMessages();
              }
            });
            MB.subscribe('/notification/' + S.user.id, function (data) {
              refreshUnreadNotifCount();
              if (location.pathname === BASE_PATH + '/notifications' || location.pathname === BASE_PATH + '/notifications/') {
                renderNotifications();
              }
            });
          }
          MB.start();

          // Fallback polling every 15 seconds
          if (TOPICS_POLL_INTERVAL) clearInterval(TOPICS_POLL_INTERVAL);
          var _pollUrl = buildViewUrl(topicView, 0);
          TOPICS_POLL_INTERVAL = setInterval(function() {
            if (document.hidden) return;
            var list = document.getElementById('topicList');
            if (!list) return;
            api(_pollUrl, { nocache: true, nodup: true }).then(function(resp) {
              var freshTopics = resp && resp.topic_list && resp.topic_list.topics || [];
              // Update read/unread styling and add new topics
              freshTopics.forEach(function(t) {
                if (!t || !t.id) return;
                var link = list.querySelector('a[data-topic-id="' + t.id + '"]');
                if (link) {
                  var hasUnread = isTopicUnread(t);
                  if (hasUnread) {
                    link.classList.add('unread');
                  } else {
                    link.classList.remove('unread');
                  }
                } else if (!knownTopicIds[t.id]) {
                  knownTopicIds[t.id] = true;
                  var tmp = document.createElement('div');
                  tmp.innerHTML = topicItemHtml(t);
                  var el = tmp.firstElementChild;
                  if (el && list.firstChild) {
                    el.style.animation = 'fadeIn 0.3s ease';
                    el.style.background = 'var(--bg3)';
                    list.insertBefore(el, list.firstChild);
                    setTimeout(function() { el.style.background = ''; }, 5000);
                  }
                }
              });
              // Reorder topics to match API sort order (latest bumped first)
              var insertRef = list.firstChild;
              freshTopics.forEach(function(t) {
                if (!t || !t.id) return;
                var link = list.querySelector('a[data-topic-id="' + t.id + '"]');
                if (link && link !== insertRef) {
                  list.insertBefore(link, insertRef);
                }
                if (link) insertRef = link.nextSibling;
              });
            }).catch(function() {});
          }, 15000);

          // Store cleanup function to unsubscribe when leaving
          var mbCleanup = function() {
            MB.stop();
            MB.unsubscribe('/new');
            MB.unsubscribe('/latest');
            MB.unsubscribe('/unread');
            if (S.user && S.user.id) {
              MB.unsubscribe('/unread/' + S.user.id);
            }
          };

          // Add to existing cleanup
          var existingCleanup = topicScrollCleanup;
          topicScrollCleanup = function() {
            mbCleanup();
            if (existingCleanup) existingCleanup();
          };
          focusContent();
        case 4:
          return _context17.a(2);
      }
    }, _callee17);
  }));
  return _renderTopics.apply(this, arguments);
}
function categoryItemHtml(c) {
  var color = c.color ? '#' + c.color : '#666';
  var desc = c.description_text || c.description || '';
  var topics = c.topic_count != null ? c.topic_count : c.topics_all_time != null ? c.topics_all_time : '';
  var slug = c.slug || '';
  var subs = (c.subcategory_ids || []).map(function (id) {
    return S.categories[id] ? S.categories[id].name : '';
  }).filter(Boolean);
  var subsHtml = subs.length ? `<div class="item-meta"><span>${subs.length} subcategories</span><span>${subs.join(', ')}</span></div>` : '';
  return `<a class="list-item" href="${categoryHref(slug, c.id)}" style="border-left:4px solid ${color};padding-left:10px">
    <div class="item-title">${esc(c.name)}</div>
    <div class="item-meta">${topics !== '' ? `<span>${topics} topics</span>` : ''}</div>
    ${desc ? `<div class="item-excerpt">${esc(desc)}</div>` : ''}
    ${subsHtml}
  </a>`;
}
function renderCategories() {
  return _renderCategories.apply(this, arguments);
} // ============ CATEGORY LIST ============
function _renderCategories() {
  _renderCategories = _asyncToGenerator(/*#__PURE__*/_regenerator().m(function _callee17b() {
    var d, cats, html, _t17b;
    return _regenerator().w(function (_context17b) {
      while (1) switch (_context17b.n) {
        case 0:
          setActiveView('categories');
          setTitle('Categories');
          showBack(true);
          showCreate('');
          $app.innerHTML = '';
          _context17b.n = 1;
          return loadCategories();
        case 1:
          _context17b.p = 1;
          _context17b.n = 2;
          return api('/categories.json');
        case 2:
          d = _context17b.v;
          mergeCategories(d.category_list && d.category_list.categories || []);
          cats = d.category_list && d.category_list.categories || [];
          if (!cats.length) {
            $app.innerHTML = '<div class="empty">No categories available.</div>';
            return _context17b.a(2);
          }
          html = `<div id="categoryList">` + cats.map(categoryItemHtml).join('') + `</div>`;
          $app.innerHTML = html;
          focusContent();
          _context17b.n = 4;
          break;
        case 3:
          _context17b.p = 3;
          _t17b = _context17b.v;
          $app.innerHTML = `<div class="error">${esc(formatErrorMessage(_t17b))}</div>`;
        case 4:
          return _context17b.a(2);
      }
    }, _callee17b, null, [[1, 3]]);
  }));
  return _renderCategories.apply(this, arguments);
}
function renderCategoryTopics(catId, slug) {
  return _renderCategoryTopics.apply(this, arguments);
}
function _renderCategoryTopics() {
  _renderCategoryTopics = _asyncToGenerator(/*#__PURE__*/_regenerator().m(function _callee17c(catId, slug) {
    var d, topics, html, onScroll, _cleanup, cat, catName, _t17c;
    return _regenerator().w(function (_context17c) {
      while (1) switch (_context17c.n) {
        case 0:
          setActiveView('categories');
          showBack(true);
          showCreate('/new-topic');
          $app.innerHTML = '';
          categoryPage = 0;
          categoryMore = true;
          categoryLoading = false;
          cat = {
            id: parseInt(catId, 10),
            slug: slug || ''
          };
          categoryView = cat;
          _context17c.n = 1;
          return loadCategories();
        case 1:
          if (S.categories[cat.id] && S.categories[cat.id].slug) cat.slug = S.categories[cat.id].slug;
          catName = S.categories[cat.id] && S.categories[cat.id].name ? S.categories[cat.id].name : 'Category';
          setTitle(catName);
          _context17c.p = 2;
          _context17c.n = 3;
          return api(buildCategoryUrl(cat, 0));
        case 3:
          d = _context17c.v;
          mergeCategories(d.category_list && d.category_list.categories || []);
          mergeTopicUsers(d.users || d.topic_list && d.topic_list.users || []);
          if (d.category && d.category.name) setTitle(d.category.name);
          topics = d.topic_list && d.topic_list.topics || [];
          if (topics.length) {
            _context17c.n = 4;
            break;
          }
          $app.innerHTML = '<div class="empty">No topics in this category yet.</div>';
          return _context17c.a(2);
        case 4:
          categoryPage = 1;
          html = `<div id="topicList">`;
          html += topics.map(topicItemHtml).join('');
          html += '</div>';
          html += '<div id="topicLoader" class="loading" style="display:none">Loading more...</div>';
          $app.innerHTML = html;
          if (topicScrollCleanup) topicScrollCleanup();
          onScroll = function onScroll() {
            if (window.innerHeight + window.scrollY >= document.body.offsetHeight - 300) {
              loadMoreCategoryTopics();
            }
          };
          window.addEventListener('scroll', onScroll);
          _cleanup = function cleanup() {
            window.removeEventListener('scroll', onScroll);
            window.removeEventListener('popstate', _cleanup);
            topicScrollCleanup = null;
          };
          topicScrollCleanup = _cleanup;
          window.addEventListener('popstate', _cleanup);
          focusContent();
          _context17c.n = 6;
          break;
        case 5:
          _context17c.p = 5;
          _t17c = _context17c.v;
          $app.innerHTML = `<div class="error">${esc(formatErrorMessage(_t17c))}</div>`;
        case 6:
          return _context17c.a(2);
      }
    }, _callee17c, null, [[2, 5]]);
  }));
  return _renderCategoryTopics.apply(this, arguments);
}
function renderTopic(_x2, _x3) {
  return _renderTopic.apply(this, arguments);
}
function _renderTopic() {
  _renderTopic = _asyncToGenerator(/*#__PURE__*/_regenerator().m(function _callee22(id, postNumber, isMessage) {
    var d, apiPath, lastPost, highestNum, timings, allPostIds, loadedPosts, postNumberMap, indexMap, loadedIndexes, minIdx, maxIdx, earlierIds, laterIds, html, remainingEarlierIds, remainingLaterIds, replyToPostNumber, replyBox, uploadBtn, loadEarlierBtn, loadLaterBtn, posts, last;
    return _regenerator().w(function (_context22) {
      while (1) switch (_context22.n) {
        case 0:
          showBack(true);
          $app.innerHTML = '';
          postNumber = postNumber && String(postNumber).match(/^\d+$/) ? postNumber : '';
          apiPath = postNumber ? `/t/${id}/${postNumber}.json` : `/t/${id}/last.json`;
          // Add show_deleted for staff to see deleted posts
          if (canModerate()) {
            apiPath += (apiPath.indexOf('?') === -1 ? '?' : '&') + 'show_deleted=true';
          }
          _context22.n = 1;
          return api(apiPath);
        case 1:
          d = _context22.v;
          CURRENT_TOPIC = {
            id: d && d.id ? d.id : parseInt(id, 10),
            slug: d && d.slug ? d.slug : '',
            title: d && d.title ? d.title : '',
            closed: d && d.closed,
            pinned: d && d.pinned,
            pinned_at: d && d.pinned_at,
            archived: d && d.archived,
            visible: d && d.visible
          };
          markTopicRead(d && d.id ? d.id : id);
          VIEWED_THIS_SESSION[String(d && d.id ? d.id : id)] = true;
          if (isMessage && _unreadMsgCount > 0) { _unreadMsgCount--; updateMenuBadges(); }
          setTitle(d.title || 'Topic');
          lastPost = d.post_stream && d.post_stream.posts || [];
          highestNum = 0;
          lastPost.forEach(function (p) {
            if (p.post_number > highestNum) highestNum = p.post_number;
          });
          if (highestNum > 0) {
            timings = {};
            timings[highestNum] = 1;
            api('/topics/timings.json', {
              method: 'POST',
              body: {
                topic_id: parseInt(id),
                topic_time: 1,
                timings: timings
              }
            }).then(function () {
              refreshUnreadNotifCount();
              refreshUnreadMessageCount();
            }).catch(function () {});
          }
          allPostIds = d.post_stream && d.post_stream.stream || [];
          loadedPosts = d.post_stream && d.post_stream.posts || [];
          postNumberMap = {};
          loadedPosts.forEach(function (p) {
            postNumberMap[p.id] = p.post_number;
          });
          indexMap = {};
          allPostIds.forEach(function (pid, idx) {
            indexMap[pid] = idx;
          });
          loadedIndexes = loadedPosts.map(function (p) {
            return indexMap[p.id];
          }).filter(function (i) {
            return typeof i === 'number';
          });
          minIdx = loadedIndexes.length ? Math.min.apply(null, loadedIndexes) : 0;
          maxIdx = loadedIndexes.length ? Math.max.apply(null, loadedIndexes) : -1;
          earlierIds = allPostIds.slice(0, minIdx);
          laterIds = allPostIds.slice(maxIdx + 1);
          html = `<h2 style="padding:12px;font-size:1.1rem">${escEmoji(d.title)}</h2>`; // Show "load earlier" at the top if there are older posts
          if (earlierIds.length > 0) {
            html += `<button id="loadEarlierPosts" tabindex="0" style="width:100%;margin:8px 0;background:var(--bg3);color:var(--fg)">Load ${earlierIds.length} earlier posts</button>`;
          }
          html += '<div id="postsContainer">';
          html += loadedPosts.map(function (p) {
            return renderPost(p, d);
          }).join('');
          html += '</div>';
          if (laterIds.length > 0) {
            html += `<button id="loadLaterPosts" tabindex="0" style="width:100%;margin:8px 0;background:var(--bg3);color:var(--fg)">Load ${laterIds.length} newer posts</button>`;
          }
          remainingEarlierIds = earlierIds;
          remainingLaterIds = laterIds;
          html += `<div id="replyIndicator" class="reply-indicator" style="display:none">
    <span id="replyingToText">Replying to topic</span>
    <button class="cancel-reply" id="cancelReply" tabindex="0">${IC.x}</button>
  </div>`;
          html += `<div id="typingIndicator" style="display:none;padding:4px 12px;font-size:0.8rem;color:var(--fg2);font-style:italic"></div>`;
          html += `<div class="compose" id="replyArea">
    <div class="compose-body">
      <div id="replyAttachments" class="attachment-list" style="display:none"></div>
      <textarea id="replyBox" placeholder="Press Enter or tap to type a reply..." tabindex="0" readonly>${esc(getDraft('reply_' + id))}</textarea>
      <div id="replyPreview" class="md-preview" style="display:none" tabindex="0"></div>
    </div>
    <div class="actions chip-actions">
      <label for="uploadFile" id="uploadBtn" role="button" tabindex="0" style="background:var(--bg3);color:var(--fg);cursor:pointer" aria-label="Upload" title="Upload">${IC.upload}</label>
      <button id="emojiBtn" tabindex="0" style="background:var(--bg3);color:var(--fg)" aria-label="Emoji">${IC.smile}</button>
      <button id="replyPreviewBtn" tabindex="0" style="background:var(--bg3);color:var(--fg)" aria-label="Preview" title="Preview"></button>
      ${LT_ENABLED ? `<button id="refineReply" tabindex="0" style="background:var(--bg3);color:var(--fg)" aria-label="Refine" title="Refine"><span class="btn-icon">${IC.refine}</span></button>` : ''}
      <span class="actions-spacer" aria-hidden="true"></span>
      <button id="discardReply" class="discard" tabindex="0" aria-label="Discard reply draft" title="Discard">${IC.trash}</button>
      <button id="sendReply" tabindex="0" aria-label="Post reply" title="Post reply">${IC.send}</button>
    </div>
    <input type="file" id="uploadFile" tabindex="-1" style="position:absolute;opacity:0;width:1px;height:1px;pointer-events:none">
  </div>`;
          $app.innerHTML = html;
          refreshComposeActions();
          enhanceCooked($app);
          updatePostTabindexes();
          replyToPostNumber = null; // Auto-save draft
          replyBox = document.getElementById('replyBox');
          var discardReplyBtn = document.getElementById('discardReply');
          function updateReplyDiscard() {
            if (!discardReplyBtn) return;
            discardReplyBtn.style.display = replyBox.value.trim() ? 'inline-flex' : 'none';
          }
          replyBox.addEventListener('input', function () {
            saveDraft('reply_' + id, replyBox.value, {
              type: 'reply',
              topicId: id,
              topicTitle: d.title || ''
            });
            updateReplyDiscard();
          });
          updateReplyDiscard();
          function enableReplyBoxEditing() {
            if (!replyBox.readOnly) return;
            replyBox.readOnly = false;
            replyBox.placeholder = 'Write a reply...';
          }
          replyBox.addEventListener('pointerdown', function (e) {
            if (e.pointerType === 'touch') {
              enableReplyBoxEditing();
            }
          });
          replyBox.addEventListener('keydown', function (e) {
            if (e.key === 'Enter' && replyBox.readOnly) {
              e.preventDefault();
              enableReplyBoxEditing();
              replyBox.focus();
            }
          });
          replyBox.addEventListener('blur', function () {
            if (!replyBox.readOnly) {
              replyBox.readOnly = true;
              replyBox.placeholder = 'Press Enter or tap to type a reply...';
            }
          });
          bindPreview('replyBox', 'replyPreview', 'replyPreviewBtn', function () {
            return {
              topicId: parseInt(id, 10),
              title: d.title || '',
              replyToPostNumber: replyToPostNumber
            };
          });
          bindRefine('replyBox', 'refineReply');
          refreshComposeActions();
          document.getElementById('discardReply').addEventListener('click', /*#__PURE__*/_asyncToGenerator(/*#__PURE__*/_regenerator().m(function _calleeReplyDiscard() {
            return _regenerator().w(function (_contextReplyDiscard) {
              while (1) switch (_contextReplyDiscard.p = _contextReplyDiscard.n) {
                case 0:
                  _contextReplyDiscard.n = 1;
                  return confirm('Discard this reply draft?');
                case 1:
                  if (_contextReplyDiscard.v) {
                    _contextReplyDiscard.n = 2;
                    break;
                  }
                  return _contextReplyDiscard.a(2);
                case 2:
                  clearDraft('reply_' + id);
                  replyBox.value = '';
                  replyToPostNumber = null;
                  document.getElementById('replyIndicator').style.display = 'none';
                  clearAttachmentPreview('replyAttachments');
                  replyBox.dispatchEvent(new Event('input'));
                  replyBox.focus();
                  return _contextReplyDiscard.a(2);
              }
            }, _calleeReplyDiscard);
          })));
          var mentionSeeds = [];
          if (loadedPosts && loadedPosts.length) {
            var seenMentions = {};
            for (var mi = 0; mi < loadedPosts.length; mi++) {
              var mp = loadedPosts[mi];
              if (!mp || !mp.username || seenMentions[mp.username]) continue;
              seenMentions[mp.username] = true;
              mentionSeeds.push({
                username: mp.username,
                avatar_template: mp.avatar_template
              });
            }
          }
          attachMentionAutocomplete(replyBox, {
            topicId: id,
            suggestions: mentionSeeds
          });
          function appendPostsFromStream(posts, topicData, expectedId) {
            var container = document.getElementById('postsContainer');
            if (!container || !posts || !posts.length) return null;
            var lastEl = null;
            posts.forEach(function (p) {
              if (!p || postNumberMap[p.id]) return;
              postNumberMap[p.id] = p.post_number;
              container.insertAdjacentHTML('beforeend', renderPost(p, topicData || d));
              lastEl = container.lastElementChild;
            });
            if (lastEl) {
              enhanceCooked(container);
              updatePostTabindexes();
              attachPostHandlers(container, id, replyBox, postNumberMap, function (n) {
                replyToPostNumber = n;
              });
            }
            if (expectedId) {
              var expectedEl = container.querySelector('#post-' + expectedId);
              if (expectedEl) {
                try { expectedEl.scrollIntoView({ behavior: 'smooth' }); } catch (e) { expectedEl.scrollIntoView(); }
                expectedEl.focus();
                return expectedEl;
              }
            }
            if (lastEl) {
              try { lastEl.scrollIntoView({ behavior: 'smooth' }); } catch (e) { lastEl.scrollIntoView(); }
              lastEl.focus();
            }
            return lastEl;
          }
          function syncLatestPosts(expectedId) {
            return api('/t/' + id + '/last.json', { nocache: true }).then(function (latest) {
              var posts = latest && latest.post_stream && latest.post_stream.posts || [];
              return appendPostsFromStream(posts, latest, expectedId);
            }).catch(function () {});
          }
          document.getElementById('cancelReply').addEventListener('click', function () {
            replyToPostNumber = null;
            document.getElementById('replyIndicator').style.display = 'none';
          });
          uploadBtn = document.getElementById('uploadBtn');
          var uploadInput = document.getElementById('uploadFile');
          // Label for= handles touch natively; keydown handles d-pad Enter/Space
          uploadBtn.addEventListener('keydown', function (e) {
            if (e.key === 'Enter' || e.key === ' ') {
              e.preventDefault();
              uploadInput.click();
            }
          });
          uploadInput.addEventListener('change', /*#__PURE__*/function () {
            var _ref13 = _asyncToGenerator(/*#__PURE__*/_regenerator().m(function _callee19(e) {
              var file, r, markdown, _t17;
              return _regenerator().w(function (_context19) {
                while (1) switch (_context19.p = _context19.n) {
                  case 0:
                    file = e.target.files[0];
                    if (file) {
                      _context19.n = 1;
                      break;
                    }
                    return _context19.a(2);
                  case 1:
                    _context19.p = 1;
                    _context19.n = 2;
                    return uploadFile(file, uploadBtn);
                  case 2:
                    r = _context19.v;
                    markdown = buildUploadMarkdown(file, r);
                    addAttachmentPreview('replyAttachments', file, r, 'replyBox');
                    if (markdown) replyBox.value += `\n${markdown}`;
                    replyBox.dispatchEvent(new Event('input'));
                    e.target.value = '';
                    _context19.n = 4;
                    break;
                  case 3:
                    _context19.p = 3;
                    _t17 = _context19.v;
                    showAlert(_t17.message);
                    e.target.value = '';
                  case 4:
                    return _context19.a(2);
                }
              }, _callee19, null, [[1, 3]]);
            }));
            return function (_x6) {
              return _ref13.apply(this, arguments);
            };
          }());
          document.getElementById('emojiBtn').addEventListener('click', function () {
            var EMOJIS = ['\uD83D\uDC4D', '\uD83D\uDC4E', '\uD83D\uDE00', '\uD83D\uDE02', '\uD83D\uDE0A', '\uD83D\uDE0D', '\uD83E\uDD14', '\uD83D\uDE22', '\uD83D\uDE21', '\uD83D\uDE31', '\uD83D\uDE4F', '\uD83D\uDD25', '\u2764\uFE0F', '\uD83D\uDCAF', '\u2705', '\u274C', '\uD83C\uDF89', '\uD83D\uDC4B', '\uD83D\uDCAA', '\uD83D\uDE80', '\u2B50', '\uD83D\uDCA1', '\uD83C\uDFC6', '\uD83D\uDDE3\uFE0F', '\uD83D\uDCAC', '\uD83D\uDC40', '\uD83E\uDD1D', '\uD83C\uDF1F', '\uD83D\uDC9A', '\uD83D\uDC99', '\uD83D\uDC9C', '\uD83E\uDDE1', '\uD83D\uDC9B', '\uD83D\uDE07', '\uD83E\uDD23', '\uD83D\uDE09', '\uD83D\uDE0E', '\uD83E\uDD29', '\uD83D\uDE4C', '\uD83D\uDE18', '\uD83E\uDD17', '\uD83E\uDD2F', '\uD83E\uDD73', '\uD83D\uDE1C', '\uD83E\uDD7A', '\uD83D\uDE33', '\uD83D\uDE44', '\uD83D\uDE29', '\uD83E\uDD26', '\uD83D\uDE4B'];
            var overlay = document.createElement('div');
            overlay.className = 'confirm-overlay';
            overlay.innerHTML = '<div class="emoji-picker"><div class="emoji-grid">' + EMOJIS.map(function (e) {
              return '<button class="emoji-item" tabindex="0">' + e + '</button>';
            }).join('') + '</div></div>';
            document.body.appendChild(overlay);
            if (history && history.pushState) {
              history.pushState({
                emoji: true
              }, '');
            }
            var closeEmoji = function closeEmoji() {
              overlay.remove();
            };
            overlay.onclick = function (e) {
              if (e.target === overlay) closeEmoji();
            };
            overlay.querySelectorAll('.emoji-item').forEach(function (btn) {
              btn.addEventListener('click', function () {
                var val = replyBox.value;
                var pos = replyBox.selectionStart || val.length;
                replyBox.value = val.substring(0, pos) + btn.textContent + val.substring(pos);
                replyBox.selectionStart = replyBox.selectionEnd = pos + btn.textContent.length;
                closeEmoji();
                replyBox.readOnly = false;
                replyBox.focus();
                replyBox.dispatchEvent(new Event('input'));
              });
            });
            overlay.addEventListener('keydown', function (e) {
              if (e.key === 'Escape') {
                e.stopPropagation();
                closeEmoji();
              }
            });
            var _popHandler = function popHandler() {
              closeEmoji();
              window.removeEventListener('popstate', _popHandler);
            };
            window.addEventListener('popstate', _popHandler);
            var firstEmoji = overlay.querySelector('.emoji-item');
            if (firstEmoji) firstEmoji.focus();
          });
          document.getElementById('sendReply').addEventListener('click', /*#__PURE__*/_asyncToGenerator(/*#__PURE__*/_regenerator().m(function _callee20() {
            var raw, postBody, created, postData, fetched, container, posts, last, _t18;
            return _regenerator().w(function (_context20) {
              while (1) switch (_context20.p = _context20.n) {
                case 0:
                  raw = replyBox.value.trim();
                  if (raw) {
                    _context20.n = 1;
                    break;
                  }
                  return _context20.a(2);
                case 1:
                  this.disabled = true;
                  this.innerHTML = IC.send;
                  this.setAttribute('aria-label', 'Posting...');
                  this.setAttribute('title', 'Posting...');
                  _context20.p = 2;
                  postBody = {
                    topic_id: parseInt(id),
                    raw
                  };
                  if (replyToPostNumber) postBody.reply_to_post_number = replyToPostNumber;
                  _context20.n = 3;
                  return api('/posts.json', {
                    method: 'POST',
                    body: postBody
                  });
                case 3:
                  created = _context20.v;
                  clearDraft('reply_' + id);
                  replyBox.value = '';
                  replyToPostNumber = null;
                  document.getElementById('replyIndicator').style.display = 'none';
                  clearAttachmentPreview('replyAttachments');
                  replyBox.dispatchEvent(new Event('input'));
                  postData = created && created.post ? created.post : created;
                  if (!(postData && postData.id && !postData.cooked)) {
                    _context20.n = 5;
                    break;
                  }
                  _context20.n = 4;
                  return api('/posts/' + postData.id + '.json', {
                    nocache: true
                  });
                case 4:
                  fetched = _context20.v;
                  postData = fetched && fetched.post ? fetched.post : fetched;
                case 5:
                  if (postData && postData.id && postData.cooked) {
                    var _container = document.getElementById('postsContainer');
                    if (_container && !document.getElementById('post-' + postData.id)) {
                      postNumberMap[postData.id] = postData.post_number;
                      var _postHtml = renderPost(postData, CURRENT_TOPIC || d);
                      if (_postHtml) {
                        _container.insertAdjacentHTML('beforeend', _postHtml);
                        var _newEl = document.getElementById('post-' + postData.id);
                        if (_newEl) {
                          enhanceCooked(_newEl);
                          attachPostHandlers(_newEl, id, replyBox, postNumberMap, function(n) { replyToPostNumber = n; });
                          updatePostTabindexes();
                          _newEl.scrollIntoView({ behavior: 'smooth' });
                          _newEl.focus();
                        }
                        this.disabled = false;
                        this.innerHTML = IC.send;
                        this.setAttribute('aria-label', 'Post reply');
                        this.setAttribute('title', 'Post reply');
                        return _context20.a(2);
                      }
                    }
                  }
                  _context20.n = 6;
                  return renderTopic(id, postData && postData.post_number ? postData.post_number : null);
                case 6:
                  this.disabled = false;
                  this.innerHTML = IC.send;
                  this.setAttribute('aria-label', 'Post reply');
                  this.setAttribute('title', 'Post reply');
                  // Scroll to bottom where new post is
                  setTimeout(function() {
                    var posts = document.querySelectorAll('.post');
                    if (posts.length) {
                      var last = posts[posts.length - 1];
                      last.scrollIntoView({ behavior: 'smooth' });
                      last.focus();
                    }
                  }, 100);
                  _context20.n = 8;
                  break;
                case 7:
                  _context20.p = 7;
                  _t18 = _context20.v;
                  showAlert(formatErrorMessage(_t18));
                  this.disabled = false;
                  this.innerHTML = IC.send;
                  this.setAttribute('aria-label', 'Post reply');
                  this.setAttribute('title', 'Post reply');
                case 8:
                  return _context20.a(2);
              }
            }, _callee20, this, [[2, 7]]);
          })));
          loadEarlierBtn = document.getElementById('loadEarlierPosts');
          if (loadEarlierBtn) {
            loadEarlierBtn.addEventListener('click', /*#__PURE__*/_asyncToGenerator(/*#__PURE__*/_regenerator().m(function _callee21() {
              var batch, resp, newPosts, container, beforeScrollH, _t19;
              return _regenerator().w(function (_context21) {
                while (1) switch (_context21.p = _context21.n) {
                  case 0:
                    this.disabled = true;
                    this.textContent = 'Loading...';
                    _context21.p = 1;
                    batch = remainingEarlierIds.splice(-20);
                    _context21.n = 2;
                    return api(`/t/${id}/posts.json?post_ids[]=${batch.join('&post_ids[]=')}${canModerate() ? '&show_deleted=true' : ''}`);
                  case 2:
                    resp = _context21.v;
                    newPosts = (resp.post_stream && resp.post_stream.posts || []).sort(function (a, b) {
                      return a.post_number - b.post_number;
                    });
                    container = document.getElementById('postsContainer'); // Insert at the top of the container
                    beforeScrollH = document.body.scrollHeight;
                    newPosts.forEach(function (p) {
                      postNumberMap[p.id] = p.post_number;
                      container.insertAdjacentHTML('afterbegin', renderPost(p, d));
                    });
                    enhanceCooked(container);
                    updatePostTabindexes();
                    window.scrollBy(0, document.body.scrollHeight - beforeScrollH);
                    attachPostHandlers(container, id, replyBox, postNumberMap, function (n) {
                      replyToPostNumber = n;
                    });
                    if (remainingEarlierIds.length > 0) {
                      this.disabled = false;
                      this.textContent = `Load ${remainingEarlierIds.length} earlier posts`;
                    } else {
                      this.remove();
                    }
                    _context21.n = 4;
                    break;
                  case 3:
                    _context21.p = 3;
                    _t19 = _context21.v;
                    showAlert(_t19.message);
                    this.disabled = false;
                    this.textContent = 'Load earlier posts';
                  case 4:
                    return _context21.a(2);
                }
              }, _callee21, this, [[1, 3]]);
            })));
          }
          loadLaterBtn = document.getElementById('loadLaterPosts');
          if (loadLaterBtn) {
            loadLaterBtn.addEventListener('click', /*#__PURE__*/_asyncToGenerator(/*#__PURE__*/_regenerator().m(function _callee21b() {
              var batch, resp, newPosts, container, _t19b;
              return _regenerator().w(function (_context21b) {
                while (1) switch (_context21b.p = _context21b.n) {
                  case 0:
                    this.disabled = true;
                    this.textContent = 'Loading...';
                    _context21b.p = 1;
                    batch = remainingLaterIds.splice(0, 20);
                    _context21b.n = 2;
                    return api(`/t/${id}/posts.json?post_ids[]=${batch.join('&post_ids[]=')}${canModerate() ? '&show_deleted=true' : ''}`);
                  case 2:
                    resp = _context21b.v;
                    newPosts = (resp.post_stream && resp.post_stream.posts || []).sort(function (a, b) {
                      return a.post_number - b.post_number;
                    });
                    container = document.getElementById('postsContainer'); // Append at the bottom of the container
                    newPosts.forEach(function (p) {
                      postNumberMap[p.id] = p.post_number;
                      container.insertAdjacentHTML('beforeend', renderPost(p, d));
                    });
                    enhanceCooked(container);
                    updatePostTabindexes();
                    attachPostHandlers(container, id, replyBox, postNumberMap, function (n) {
                      replyToPostNumber = n;
                    });
                    if (remainingLaterIds.length > 0) {
                      this.disabled = false;
                      this.textContent = `Load ${remainingLaterIds.length} newer posts`;
                    } else {
                      this.remove();
                    }
                    _context21b.n = 4;
                    break;
                  case 3:
                    _context21b.p = 3;
                    _t19b = _context21b.v;
                    showAlert(_t19b.message);
                    this.disabled = false;
                    this.textContent = 'Load newer posts';
                  case 4:
                    return _context21b.a(2);
                }
              }, _callee21b, this, [[1, 3]]);
            })));
          }
          attachPostHandlers($app, id, replyBox, postNumberMap, function (n) {
            replyToPostNumber = n;
          });
          // Real-time updates via MessageBus for this topic
          if (TOPIC_MB_CLEANUP) {
            TOPIC_MB_CLEANUP();
            TOPIC_MB_CLEANUP = null;
          }
          MB.stop();
          var _existingChannels = Object.keys(MB.callbacks);
          _existingChannels.forEach(function(ch) { MB.unsubscribe(ch); });

          var topicChannel = '/topic/' + id;
          var _topicPollInterval = null;

          MB.subscribe(topicChannel, function(data) {
            if (!data) return;
            var type = data.type;
            if ((type === 'revised' || type === 'rebaked') && data.id) {
              if (document.getElementById('post-' + data.id)) {
                refreshPostById(data.id);
              }
              return;
            }
            if (type === 'created' && data.id) {
              var _newPostId = data.id;
              if (document.getElementById('post-' + _newPostId)) return;
              var _ctr = document.getElementById('postsContainer');
              if (!_ctr) return;
              api('/posts/' + _newPostId + '.json', { nocache: true }).then(function(resp) {
                var p = resp && resp.post ? resp.post : resp;
                if (!p || !p.id) return;
                if (document.getElementById('post-' + p.id)) return;
                var c = document.getElementById('postsContainer');
                if (!c) return;
                postNumberMap[p.id] = p.post_number;
                var _html = renderPost(p, CURRENT_TOPIC || { id: id, slug: '' });
                if (!_html) return;
                c.insertAdjacentHTML('beforeend', _html);
                var el = document.getElementById('post-' + p.id);
                if (el) {
                  enhanceCooked(el);
                  attachPostHandlers(el, id, replyBox, postNumberMap, function(n) { replyToPostNumber = n; });
                }
                updatePostTabindexes();
                var distFromBottom = document.body.scrollHeight - window.scrollY - window.innerHeight;
                if (distFromBottom < 200 && el) {
                  el.scrollIntoView({ behavior: 'smooth' });
                }
              }).catch(function() {});
              return;
            }
          });
          MB.start();

          _topicPollInterval = setInterval(function() {
            if (document.hidden) return;
            if (!document.getElementById('postsContainer')) {
              clearInterval(_topicPollInterval);
              return;
            }
            api('/t/' + id + '.json', { nocache: true, nodup: true }).then(function(resp) {
              if (!resp || !resp.post_stream) return;
              var stream = resp.post_stream.stream || [];
              var _ctr2 = document.getElementById('postsContainer');
              if (!_ctr2) return;
              var lastLoadedIndex = -1;
              for (var i = stream.length - 1; i >= 0; i--) {
                if (document.getElementById('post-' + stream[i])) {
                  lastLoadedIndex = i;
                  break;
                }
              }
              var missing = stream.slice(lastLoadedIndex + 1).filter(function(pid) {
                return !document.getElementById('post-' + pid);
              });
              var toFetch = missing.slice(0, 5);
              toFetch.forEach(function(pid) {
                api('/posts/' + pid + '.json', { nocache: true }).then(function(resp2) {
                  var p = resp2 && resp2.post ? resp2.post : resp2;
                  if (!p || !p.id) return;
                  if (document.getElementById('post-' + p.id)) return;
                  var c2 = document.getElementById('postsContainer');
                  if (!c2) return;
                  postNumberMap[p.id] = p.post_number;
                  var h = renderPost(p, CURRENT_TOPIC || { id: id, slug: '' });
                  if (!h) return;
                  c2.insertAdjacentHTML('beforeend', h);
                  var el2 = document.getElementById('post-' + p.id);
                  if (el2) {
                    enhanceCooked(el2);
                    attachPostHandlers(el2, id, replyBox, postNumberMap, function(n) { replyToPostNumber = n; });
                  }
                  updatePostTabindexes();
                }).catch(function() {});
              });
            }).catch(function() {});
          }, 30000);

          // Presence typing indicator
          var presenceChannel = '/discourse-presence/reply/' + id;
          var _lastPresencePublish = 0;
          var _presenceLeaveTimer = null;
          var _presencePollInterval = null;

          function publishPresence() {
            var now = Date.now();
            if (now - _lastPresencePublish < 2000) return;
            _lastPresencePublish = now;
            presenceXhr('POST', '/presence/update', {
              client_id: MB.clientId,
              present_channels: [presenceChannel]
            });
            if (_presenceLeaveTimer) clearTimeout(_presenceLeaveTimer);
            _presenceLeaveTimer = setTimeout(leavePresence, 10000);
          }

          function leavePresence() {
            if (_presenceLeaveTimer) { clearTimeout(_presenceLeaveTimer); _presenceLeaveTimer = null; }
            _lastPresencePublish = 0;
            presenceXhr('POST', '/presence/update', {
              client_id: MB.clientId,
              leave_channels: [presenceChannel]
            });
          }

          replyBox.addEventListener('input', function() {
            if (replyBox.value.trim()) publishPresence();
          });

          _presencePollInterval = setInterval(function() {
            if (document.hidden) return;
            if (!document.getElementById('postsContainer')) {
              clearInterval(_presencePollInterval);
              return;
            }
            presenceXhr('GET', '/presence/get?channels[]=' + encodeURIComponent(presenceChannel), null, function(data) {
              var indicator = document.getElementById('typingIndicator');
              if (!indicator) return;
              var channelData = data && data[presenceChannel];
              var users = channelData && channelData.users || [];
              var others = users.filter(function(u) { return u.username !== S.username; });
              if (others.length === 0) {
                indicator.style.display = 'none';
                indicator.textContent = '';
                return;
              }
              var names = others.map(function(u) { return u.username; });
              var text = names.length === 1
                ? names[0] + ' is typing...'
                : names.join(', ') + ' are typing...';
              indicator.textContent = text;
              indicator.style.display = 'block';
            });
          }, 4000);

          TOPIC_MB_CLEANUP = function() {
            MB.stop();
            MB.unsubscribe(topicChannel);
            if (_topicPollInterval) { clearInterval(_topicPollInterval); _topicPollInterval = null; }
            leavePresence();
            if (_presencePollInterval) { clearInterval(_presencePollInterval); _presencePollInterval = null; }
          };
          // Scroll to specific post or last post
          if (postNumber) {
            var pn = parseInt(postNumber, 10);
            if (pn) {
              var target = $app.querySelector('.post[data-post-number="' + pn + '"]');
              if (target) {
                target.scrollIntoView({ block: 'start' });
                target.focus();
              } else {
                // Target not found, scroll to first post
                var firstPost = document.querySelector('.post');
                if (firstPost) {
                  firstPost.scrollIntoView({ block: 'start' });
                  firstPost.focus();
                }
              }
            }
          } else {
            // No post number, scroll to last
            posts = document.querySelectorAll('.post');
            if (posts.length) {
              last = posts[posts.length - 1];
              last.scrollIntoView({ behavior: 'instant' });
              last.focus();
            }
          }
        case 2:
          return _context22.a(2);
      }
    }, _callee22);
  }));
  return _renderTopic.apply(this, arguments);
}
function attachPostHandlers(container, topicId, replyBox, postNumberMap, setReplyTo) {
  function refreshPost(postId) {
    if (!postId) return Promise.resolve();
    return api('/posts/' + postId + '.json', {
      nocache: true
    }).then(function (resp) {
      var p = resp && resp.post ? resp.post : resp;
      if (!p || !p.id) return;
      postNumberMap[p.id] = p.post_number;
      var oldEl = document.getElementById('post-' + p.id);
      if (!oldEl || !oldEl.parentNode) return;
      var wasActive = oldEl.classList.contains('active');
      var tmp = document.createElement('div');
      tmp.innerHTML = renderPost(p, CURRENT_TOPIC || { id: topicId, slug: '' });
      var newEl = tmp.firstElementChild;
      if (!newEl) return;
      oldEl.parentNode.replaceChild(newEl, oldEl);
      enhanceCooked(newEl);
      if (wasActive) activatePost(newEl);
      updatePostTabindexes();
      attachPostHandlers(newEl, topicId, replyBox, postNumberMap, setReplyTo);
    }).catch(function () {});
  }
  POST_REFRESHER = refreshPost;
  container.querySelectorAll('[data-react-open]').forEach(function (btn) {
    if (btn._bound) return;
    btn._bound = true;
    btn.addEventListener('click', function () {
      showReactionPicker(btn.dataset.reactOpen);
    });
  });
  container.querySelectorAll('[data-react]').forEach(function (btn) {
    if (btn._bound) return;
    btn._bound = true;
    btn.addEventListener('click', /*#__PURE__*/_asyncToGenerator(/*#__PURE__*/_regenerator().m(function _callee2() {
      var postId, reactionId, d, groups, target, gi, emoji, names, _t3;
      return _regenerator().w(function (_context2) {
        while (1) switch (_context2.p = _context2.n) {
          case 0:
            postId = btn.dataset.postId;
            reactionId = btn.dataset.react; // Show who reacted dialog, with option to toggle
            btn.disabled = true;
            _context2.p = 1;
            _context2.n = 2;
            return api('/discourse-reactions/posts/' + postId + '/reactions-users.json');
          case 2:
            d = _context2.v;
            groups = d.reaction_users || [];
            target = null;
            gi = 0;
          case 3:
            if (!(gi < groups.length)) {
              _context2.n = 5;
              break;
            }
            if (!(groups[gi].id === reactionId)) {
              _context2.n = 4;
              break;
            }
            target = groups[gi];
            return _context2.a(3, 5);
          case 4:
            gi++;
            _context2.n = 3;
            break;
          case 5:
            emoji = REACTION_EMOJI[reactionId] || reactionId;
            if (target && target.users && target.users.length) {
              names = target.users.map(function (u) {
                return '@' + u.username;
              }).join(', ');
              showAlert(emoji + ' (' + target.count + '): ' + names);
            } else {
              showAlert(emoji + ': no reactions yet');
            }
            _context2.n = 7;
            break;
          case 6:
            _context2.p = 6;
            _t3 = _context2.v;
            showAlert(_t3.message);
          case 7:
            btn.disabled = false;
          case 8:
            return _context2.a(2);
        }
      }, _callee2, null, [[1, 6]]);
    })));
  });
  container.querySelectorAll('[data-reply-to]').forEach(function (btn) {
    if (btn._bound) return;
    btn._bound = true;
    btn.addEventListener('click', function () {
      var postId = parseInt(btn.dataset.replyTo);
      var user = btn.dataset.replyUser;
      var postNum = postNumberMap[postId] || postId;
      setReplyTo(postNum);
      var indicator = document.getElementById('replyIndicator');
      document.getElementById('replyingToText').textContent = `Replying to @${user} (#${postNum})`;
      indicator.style.display = 'flex';
      replyBox.readOnly = false;
      replyBox.placeholder = 'Write a reply...';
      replyBox.focus();
      replyBox.scrollIntoView({
        behavior: 'smooth'
      });
    });
  });
  container.querySelectorAll('[data-jump-post]').forEach(function (btn) {
    if (btn._bound) return;
    btn._bound = true;
    btn.addEventListener('click', function () {
      var targetNum = parseInt(btn.dataset.jumpPost, 10);
      if (!targetNum) return;
      var target = container.querySelector('.post[data-post-number="' + targetNum + '"]');
      if (target && target.scrollIntoView) {
        target.scrollIntoView({ block: 'start', behavior: 'smooth' });
        target.focus();
        return;
      }
      var slug = btn.dataset.topicSlug || '';
      var tid = btn.dataset.topicId || topicId;
      if (tid) navigate(topicPath(tid, slug, targetNum), true);
    });
  });
  container.querySelectorAll('[data-quote-post]').forEach(function (btn) {
    if (btn._bound) return;
    btn._bound = true;
    btn.addEventListener('click', /*#__PURE__*/_asyncToGenerator(/*#__PURE__*/_regenerator().m(function _callee2b() {
      var postId, user, postNum, raw, postEl, bodyEl, quote, val;
      return _regenerator().w(function (_context2b) {
        while (1) switch (_context2b.p = _context2b.n) {
          case 0:
            postId = parseInt(btn.dataset.quotePost);
            user = btn.dataset.quoteUser || '';
            postNum = postNumberMap[postId] || postId;
            btn.disabled = true;
            _context2b.p = 1;
            _context2b.n = 2;
            return api(`/posts/${postId}.json`);
          case 2:
            raw = _context2b.v.raw || '';
            _context2b.n = 5;
            break;
          case 4:
            _context2b.p = 4;
          case 5:
            if (!raw) {
              postEl = document.getElementById('post-' + postId);
              bodyEl = postEl && postEl.querySelector('.post-body');
              raw = bodyEl ? htmlToText(bodyEl.innerHTML) : '';
            }
            quote = `[quote=\"${user}, post:${postNum}, topic:${topicId}\"]\n${raw}\n[/quote]\n`;
            setReplyTo(postNum);
            var indicator = document.getElementById('replyIndicator');
            document.getElementById('replyingToText').textContent = `Replying to @${user} (#${postNum})`;
            indicator.style.display = 'flex';
            replyBox.readOnly = false;
            replyBox.placeholder = 'Write a reply...';
            val = replyBox.value || '';
            if (val && !val.match(/\n$/)) val += '\n';
            replyBox.value = val + quote;
            replyBox.focus();
            replyBox.scrollIntoView({
              behavior: 'smooth'
            });
            replyBox.dispatchEvent(new Event('input'));
            btn.disabled = false;
          case 6:
            return _context2b.a(2);
        }
      }, _callee2b, null, [[1, 4]]);
    })));
  });
  container.querySelectorAll('[data-delete-post]').forEach(function (btn) {
    if (btn._bound) return;
    btn._bound = true;
    btn.addEventListener('click', /*#__PURE__*/_asyncToGenerator(/*#__PURE__*/_regenerator().m(function _callee3() {
      var postId, _t4;
      return _regenerator().w(function (_context3) {
        while (1) switch (_context3.p = _context3.n) {
          case 0:
            postId = btn.dataset.deletePost;
            _context3.n = 1;
            return confirm('Delete this post?');
          case 1:
            if (_context3.v) {
              _context3.n = 2;
              break;
            }
            return _context3.a(2);
          case 2:
            btn.disabled = true;
            _context3.p = 3;
            _context3.n = 4;
            return api(`/posts/${postId}.json`, {
              method: 'DELETE'
            });
          case 4:
            _context3.n = 5;
            return softRefresh();
          case 5:
            _context3.n = 7;
            break;
          case 6:
            _context3.p = 6;
            _t4 = _context3.v;
            showAlert(_t4.message);
            btn.disabled = false;
          case 7:
            return _context3.a(2);
        }
      }, _callee3, null, [[3, 6]]);
    })));
  });
  container.querySelectorAll('[data-restore-post]').forEach(function (btn) {
    if (btn._bound) return;
    btn._bound = true;
    btn.addEventListener('click', function () {
      var postId = btn.dataset.restorePost;
      confirm('Restore this post?').then(function (ok) {
        if (!ok) return;
        btn.disabled = true;
        api('/posts/' + postId + '/recover.json', {
          method: 'PUT'
        }).then(function () {
          return softRefresh();
        }).catch(function (e) {
          showAlert(e.message || 'Failed to restore post');
          btn.disabled = false;
        });
      });
    });
  });
  container.querySelectorAll('[data-edit-post]').forEach(function (btn) {
    if (btn._bound) return;
    btn._bound = true;
    btn.addEventListener('click', /*#__PURE__*/_asyncToGenerator(/*#__PURE__*/_regenerator().m(function _callee5() {
      var postId, postEl, bodyEl, resp, raw, actionsEl, _t6;
      return _regenerator().w(function (_context5) {
        while (1) switch (_context5.p = _context5.n) {
          case 0:
            postId = btn.dataset.editPost;
            postEl = document.getElementById('post-' + postId);
            bodyEl = postEl && postEl.querySelector('.post-body');
            if (bodyEl) {
              _context5.n = 1;
              break;
            }
            return _context5.a(2);
          case 1:
            btn.disabled = true;
            _context5.p = 2;
            _context5.n = 3;
            return api(`/posts/${postId}.json`);
          case 3:
            resp = _context5.v;
            raw = resp.raw || '';
            actionsEl = postEl.querySelector('.post-actions');
            actionsEl.style.display = 'none';
            bodyEl.innerHTML = `<textarea id="editBox-${postId}" style="width:100%;min-height:120px" tabindex="0">${esc(raw)}</textarea>
          <div style="display:flex;gap:8px;margin-top:8px">
            <button class="save-edit" data-post-id="${postId}" tabindex="0">Save</button>
            ${LT_ENABLED ? `<button class="refine-edit" id="refineEdit-${postId}" data-post-id="${postId}" tabindex="0" style="background:var(--bg3);color:var(--fg)"><span class="btn-icon">${IC.refine}</span></button>` : ''}
            <button class="cancel-edit" data-post-id="${postId}" tabindex="0" style="background:var(--bg3);color:var(--fg)">Cancel</button>
          </div>`;
            attachMentionAutocomplete(document.getElementById('editBox-' + postId), {
              topicId: topicId
            });
            bindRefine('editBox-' + postId, 'refineEdit-' + postId);
            bodyEl.querySelector('.save-edit').addEventListener('click', /*#__PURE__*/_asyncToGenerator(/*#__PURE__*/_regenerator().m(function _callee4() {
              var newRaw, te, _t5;
              return _regenerator().w(function (_context4) {
                while (1) switch (_context4.p = _context4.n) {
                  case 0:
                    newRaw = document.getElementById('editBox-' + postId).value.trim();
                    if (newRaw) {
                      _context4.n = 1;
                      break;
                    }
                    return _context4.a(2);
                  case 1:
                    this.disabled = true;
                    this.textContent = 'Saving...';
                    _context4.p = 2;
                    _context4.n = 3;
                    return api(`/posts/${postId}.json`, {
                      method: 'PUT',
                      body: {
                        post: {
                          raw: newRaw
                        }
                      }
                    });
                  case 3:
                    _context4.n = 4;
                    return refreshPostById(postId);
                  case 4:
                    _context4.n = 6;
                    break;
                  case 5:
                    _context4.p = 5;
                    _t5 = _context4.v;
                    showAlert(_t5.message);
                    this.disabled = false;
                    this.textContent = 'Save';
                  case 6:
                    return _context4.a(2);
                }
              }, _callee4, this, [[2, 5]]);
            })));
            bodyEl.querySelector('.cancel-edit').addEventListener('click', function () {
              return softRefresh();
            });
            _context5.n = 5;
            break;
          case 4:
            _context5.p = 4;
            _t6 = _context5.v;
            showAlert(_t6.message);
            btn.disabled = false;
          case 5:
            return _context5.a(2);
        }
      }, _callee5, null, [[2, 4]]);
    })));
  });
  container.querySelectorAll('[data-poll-vote]').forEach(function (opt) {
    if (opt._bound) return;
    opt._bound = true;
    opt.addEventListener('click', /*#__PURE__*/_asyncToGenerator(/*#__PURE__*/_regenerator().m(function _callee6() {
      var pollName, optVal, postId, _t7;
      return _regenerator().w(function (_context6) {
        while (1) switch (_context6.p = _context6.n) {
          case 0:
            pollName = opt.dataset.pollName;
            optVal = opt.dataset.pollVote;
            postId = opt.dataset.postId;
            _context6.p = 1;
            _context6.n = 2;
            return api('/polls/vote.json', {
              method: 'PUT',
              body: {
                post_id: parseInt(postId),
                poll_name: pollName,
                options: [optVal]
              }
            });
          case 2:
            _context6.n = 3;
            return refreshPostById(postId);
          case 3:
            _context6.n = 5;
            break;
          case 4:
            _context6.p = 4;
            _t7 = _context6.v;
            showAlert(_t7.message);
          case 5:
            return _context6.a(2);
        }
      }, _callee6, null, [[1, 4]]);
    })));
  });
  container.querySelectorAll('[data-flag]').forEach(function (btn) {
    if (btn._bound) return;
    btn._bound = true;
    btn.addEventListener('click', function () {
      var postId = btn.dataset.flag;
      showFlagDialog(postId);
    });
  });
}
function showAlert(msg) {
  return new Promise(function (resolve) {
    var prev = document.activeElement;
    var el = document.createElement('div');
    el.className = 'confirm-overlay';
    el.innerHTML = `<div class="confirm-box"><p>${esc(msg)}</p><div class="actions">
      <button class="ok" tabindex="0">OK</button></div></div>`;
    document.body.appendChild(el);
    var okBtn = el.querySelector('.ok');
    okBtn.focus();
    var close = function close() {
      el.remove();
      if (prev && prev.focus) prev.focus();
      resolve();
    };
    okBtn.onclick = close;
    el.onclick = function (e) {
      if (e.target === el) close();
    };
    okBtn.addEventListener('keydown', function (e) {
      if (e.key === 'Escape') close();
    });
  });
}
function showReactionPicker(postId) {
  var prev = document.activeElement;
  var el = document.createElement('div');
  el.className = 'confirm-overlay';
  el.innerHTML = '<div class="confirm-box"><p>React:</p><div class="reaction-picker-grid">' + REACTION_LIST.map(function (r) {
    return '<button class="reaction-pick" data-rid="' + r + '" tabindex="0">' + (REACTION_EMOJI[r] || r) + '</button>';
  }).join('') + '</div><button class="cancel" tabindex="0" style="background:var(--bg3);color:var(--fg);margin-top:8px;width:100%">Cancel</button></div>';
  document.body.appendChild(el);
  var picks = [].slice.call(el.querySelectorAll('.reaction-pick'));
  var cancelBtn = el.querySelector('.cancel');
  var first = picks[0];
  if (first) first.focus();
  var lastPickIndex = 0;
  picks.forEach(function (btn, idx) {
    btn.addEventListener('focus', function () {
      lastPickIndex = idx;
    });
  });
  var close = function close() {
    el.remove();
    if (prev && prev.focus) prev.focus();
  };
  if (cancelBtn) cancelBtn.onclick = close;
  el.onclick = function (e) {
    if (e.target === el) close();
  };
  picks.forEach(function (btn) {
    btn.addEventListener('click', /*#__PURE__*/_asyncToGenerator(/*#__PURE__*/_regenerator().m(function _callee7() {
      var _t8;
      return _regenerator().w(function (_context7) {
        while (1) switch (_context7.p = _context7.n) {
          case 0:
            btn.disabled = true;
            _context7.p = 1;
            _context7.n = 2;
            return ensureCsrf();
          case 2:
            _context7.n = 3;
            return api('/discourse-reactions/posts/' + postId + '/custom-reactions/' + encodeURIComponent(btn.dataset.rid) + '/toggle.json', {
              method: 'PUT'
            });
          case 3:
            close();
            _context7.n = 4;
            return refreshPostById(postId);
          case 4:
            _context7.n = 6;
            break;
          case 5:
            _context7.p = 5;
            _t8 = _context7.v;
            close();
            showAlert(_t8.message);
          case 6:
            return _context7.a(2);
        }
      }, _callee7, null, [[1, 4]]);
    })));
  });
  function getCols() {
    if (!picks.length) return 1;
    var top = picks[0].offsetTop;
    var c = 0;
    for (var i = 0; i < picks.length; i++) {
      if (picks[i].offsetTop === top) c++;else break;
    }
    return c || picks.length;
  }
  function focusPick(idx) {
    if (idx < 0) idx = 0;
    if (idx >= picks.length) idx = picks.length - 1;
    if (picks[idx]) picks[idx].focus();
  }
  el.addEventListener('keydown', function (e) {
    if (e.key === 'Escape') {
      e.stopPropagation();
      close();
    }
    if (e.key === 'Tab') {
      var focusables = picks.slice();
      if (cancelBtn) focusables.push(cancelBtn);
      var cur = focusables.indexOf(document.activeElement);
      if (cur === -1) {
        focusables[0] && focusables[0].focus();
      } else {
        var nextIdx = e.shiftKey ? (cur - 1 + focusables.length) % focusables.length : (cur + 1) % focusables.length;
        focusables[nextIdx].focus();
      }
      e.preventDefault();
      return;
    }
    if (document.activeElement === cancelBtn) {
      if (e.key === 'ArrowUp') {
        focusPick(lastPickIndex);
        e.preventDefault();
      }
      return;
    }
    var idx = picks.indexOf(document.activeElement);
    if (idx === -1) return;
    var cols = getCols();
    if (e.key === 'ArrowRight') {
      if (idx + 1 < picks.length) {
        picks[idx + 1].focus();
        e.preventDefault();
      }
    }
    if (e.key === 'ArrowLeft') {
      if (idx - 1 >= 0) {
        picks[idx - 1].focus();
        e.preventDefault();
      }
    }
    if (e.key === 'ArrowDown') {
      var down = idx + cols;
      if (down < picks.length) {
        picks[down].focus();
      } else if (cancelBtn) {
        cancelBtn.focus();
      }
      e.preventDefault();
    }
    if (e.key === 'ArrowUp') {
      var up = idx - cols;
      if (up >= 0) {
        picks[up].focus();
        e.preventDefault();
      }
    }
  });
}
function showFlagDialog(postId) {
  var prev = document.activeElement;
  var el = document.createElement('div');
  el.className = 'confirm-overlay';
  el.innerHTML = '<div class="confirm-box"><p>Flag this post as:</p><div style="display:flex;flex-direction:column;gap:6px">' + '<button class="flag-opt" data-type="8" tabindex="0">It\'s Spam</button>' + '<button class="flag-opt" data-type="4" tabindex="0">It\'s Inappropriate</button>' + '<button class="flag-opt" data-type="3" tabindex="0">It\'s Off-Topic</button>' + '<button class="flag-opt" data-type="7" tabindex="0">Something Else</button>' + '<button class="cancel" tabindex="0" style="background:var(--bg3);color:var(--fg);margin-top:4px">Cancel</button>' + '</div></div>';
  document.body.appendChild(el);
  var first = el.querySelector('.flag-opt');
  if (first) first.focus();
  var close = function close() {
    el.remove();
    if (prev && prev.focus) prev.focus();
  };
  el.querySelector('.cancel').onclick = close;
  el.onclick = function (e) {
    if (e.target === el) close();
  };
  el.querySelectorAll('.flag-opt').forEach(function (btn) {
    btn.addEventListener('click', /*#__PURE__*/_asyncToGenerator(/*#__PURE__*/_regenerator().m(function _callee8() {
      var typeId, _t9;
      return _regenerator().w(function (_context8) {
        while (1) switch (_context8.p = _context8.n) {
          case 0:
            typeId = parseInt(btn.dataset.type);
            btn.disabled = true;
            btn.textContent = 'Flagging...';
            _context8.p = 1;
            _context8.n = 2;
            return api('/post_actions.json', {
              method: 'POST',
              body: {
                id: parseInt(postId),
                post_action_type_id: typeId,
                flag_topic: false
              }
            });
          case 2:
            close();
            showAlert('Post flagged');
            _context8.n = 4;
            break;
          case 3:
            _context8.p = 3;
            _t9 = _context8.v;
            close();
            showAlert(_t9.message);
          case 4:
            return _context8.a(2);
        }
      }, _callee8, null, [[1, 3]]);
    })));
  });
  el.addEventListener('keydown', function (e) {
    if (e.key === 'Escape') {
      e.stopPropagation();
      close();
    }
  });
}

function describeTopicChangePost(p) {
  if (!p) return '';
  var code = p.action_code || '';
  var actor = p.username ? esc(p.username) : 'Someone';
  var map = {
    'closed.enabled': actor + ' locked this thread',
    'closed.disabled': actor + ' unlocked this thread',
    'autoclosed.enabled': 'This thread was automatically locked',
    'autoclosed.disabled': 'This thread was automatically unlocked',
    'archived.enabled': actor + ' archived this thread',
    'archived.disabled': actor + ' unarchived this thread',
    'visible.enabled': actor + ' listed this thread',
    'visible.disabled': actor + ' unlisted this thread',
    'pinned.enabled': actor + ' pinned this thread',
    'pinned.disabled': actor + ' unpinned this thread'
  };
  if (map[code]) return map[code];

  if (code.indexOf('.enabled') > -1) {
    return actor + ' enabled ' + code.replace('.enabled', '').replace(/[_\.]/g, ' ');
  }
  if (code.indexOf('.disabled') > -1) {
    return actor + ' disabled ' + code.replace('.disabled', '').replace(/[_\.]/g, ' ');
  }
  return '';
}

function renderPost(p, topicData) {
  var isDeleted = !!p.deleted_at;
  var isHidden = !!p.hidden;
  var isSystemAction = p.post_type === 3 || !!p.action_code;
  var body = fixPostHtml(p.cooked || '');
  if (isSystemAction && !stripHtml(body).trim()) {
    var changeDescription = describeTopicChangePost(p);
    body = '<div class="system-action-label">' + esc(changeDescription || 'Thread settings changed') + '</div>';
  }
  var isOwn = p.username === S.username;
  // For deleted posts, show placeholder if not mod, or show deleted styling if mod
  if (isDeleted || isHidden) {
    if (!canModerate()) {
      // Regular users don't see deleted posts at all
      return '';
    }
    // Mods see deleted posts with special styling
    body = '<div class="deleted-notice" style="color:var(--fg2);font-style:italic;padding:8px;background:var(--bg2);border-radius:4px;margin-bottom:8px">' + (isDeleted ? 'This post was deleted' + (p.deleted_by ? ' by ' + esc(p.deleted_by.username || 'a moderator') : '') : 'This post is hidden') + '</div>' + body;
  }
  var pollsHtml = '';
  if (p.polls && p.polls.length) {
    p.polls.forEach(function (poll) {
      var totalVotes = poll.voters || 0;
      pollsHtml += `<div class="poll"><h4>${esc(poll.title || poll.name)}</h4>`;
      (poll.options || []).forEach(function (opt) {
        var pct = totalVotes > 0 ? Math.round((opt.votes || 0) / totalVotes * 100) : 0;
        var voted = opt.voted ? 'voted' : '';
        pollsHtml += `<div class="poll-option ${voted}" tabindex="0" data-poll-vote="${esc(opt.id)}" data-poll-name="${esc(poll.name)}" data-post-id="${p.id}">
          <span>${esc(opt.html || opt.text || '')}</span>
          <span class="poll-pct">${pct}% (${opt.votes || 0})</span>
        </div>`;
      });
      pollsHtml += `<div style="font-size:.75rem;color:var(--fg2);margin-top:4px">${totalVotes} votes</div></div>`;
    });
  }
  var replyInfo = '';
  if (p.reply_to_post_number) {
    var replyAvatar = p.reply_to_user && p.reply_to_user.avatar_template ? `<img src="${avatarUrl(p.reply_to_user.avatar_template, 20)}" alt="" style="width:16px;height:16px;border-radius:50%;vertical-align:middle">` : '';
    var replySlug = topicData && topicData.slug ? topicData.slug : '';
    var replyTopicId = topicData && topicData.id ? topicData.id : '';
    replyInfo = `<button class="post-reply-link" data-jump-post="${p.reply_to_post_number}" data-topic-id="${replyTopicId}" data-topic-slug="${esc(replySlug)}" tabindex="-1" aria-label="Jump to reply #${p.reply_to_post_number}" title="Jump to reply #${p.reply_to_post_number}">${IC.reply} ${replyAvatar}</button>`;
  }
  var roleLabel = '';
  var roleIcon = '';
  if (p.admin) {
    roleLabel = 'Admin';
    roleIcon = IC.lock;
  } else if (p.moderator) {
    roleLabel = 'Mod';
    roleIcon = IC.wrench;
  }
  var trust = typeof p.trust_level === 'number' ? p.trust_level : typeof p.user_trust_level === 'number' ? p.user_trust_level : null;
  var trustIcon = '';
  if (!roleLabel && trust !== null) {
    if (trust >= 4) trustIcon = IC.diamond;
    else if (trust === 3) trustIcon = IC.star;
    else if (trust === 2) trustIcon = IC.thumb;
    else if (trust === 1) trustIcon = IC.check;
  }
  var trustClass = '';
  if (roleLabel) {
    trustClass = roleLabel === 'Admin' ? 'role-admin' : 'role-mod';
  } else if (trustIcon) {
    trustClass = 'level level-' + trust;
  }
  var trustHtml = roleLabel ? `<span class="post-trust ${trustClass}">${roleIcon}<span class="label">${roleLabel}</span></span>` : trustIcon ? `<span class="post-trust ${trustClass}">${trustIcon}<span class="label">Level ${trust}</span></span>` : '';
  var curReact = p.current_user_reaction;
  var curReactId = curReact && curReact.id ? curReact.id : typeof curReact === 'string' ? curReact : null;
  var usedMain = !!p.current_user_used_main_reaction;
  var deletedClass = (isDeleted || isHidden) ? ' post-deleted' : '';
  return `<div class="post${deletedClass}" id="post-${p.id}" data-post-number="${p.post_number}" tabindex="0"${(isDeleted || isHidden) ? ' style="opacity:0.6"' : ''}>
    <div class="post-header">
      <a class="post-avatar-link" href="${userHref(p.username)}" tabindex="-1" aria-label="${esc(p.username)} profile">
        <img class="post-avatar" src="${avatarUrl(p.avatar_template, 48)}" alt="" loading="lazy">
      </a>
      <div class="post-meta">
        <a class="post-author" href="${userHref(p.username)}" tabindex="-1">${esc(p.username)}</a>
        <div class="post-sub">
          ${trustHtml}
        </div>
      </div>
      <div class="post-meta-right">
        <span class="post-num">#${p.post_number}</span>
        <span class="post-date">${timeAgo(p.created_at)}</span>
        ${replyInfo}
      </div>
    </div>
    <div class="post-body">${body}${pollsHtml}</div>
    ${(isDeleted || isHidden) ? '' : function () {
    var rxs = p.reactions || [];
    return rxs.length ? '<div class="post-reactions">' + rxs.map(function (r) {
      var em = REACTION_EMOJI[r.id] || r.id;
      var isActive = curReactId ? curReactId === r.id : usedMain && r.id === '+1';
      var active = isActive ? ' reacted' : '';
      var likeActive = isActive && r.id === '+1' ? ' reacted-like' : '';
      return '<button class="reaction-pill' + active + likeActive + '" data-react="' + esc(r.id) + '" data-post-id="' + p.id + '" tabindex="-1">' + em + ' ' + r.count + '</button>';
    }).join('') + '</div>' : '';
  }()}
    <div class="post-actions">
      ${(isDeleted || isHidden) ? `${canModerate() ? `<button data-restore-post="${p.id}" tabindex="-1" aria-label="Restore" title="Restore" style="color:var(--accent)">${IC.undo}<span class="action-label">Restore</span></button>` : ''}` : `<button data-react-open="${p.id}" tabindex="-1" aria-label="React" title="React">${IC.heart}<span class="action-label">React</span></button>
      <button data-reply-to="${p.id}" data-reply-user="${esc(p.username)}" tabindex="-1" aria-label="Reply" title="Reply">${IC.reply}<span class="action-label">Reply</span></button>
      <button data-quote-post="${p.id}" data-quote-user="${esc(p.username)}" tabindex="-1" aria-label="Quote" title="Quote">${IC.quote}<span class="action-label">Quote</span></button>
      ${(isOwn || canModerate()) ? `<button data-edit-post="${p.id}" tabindex="-1" aria-label="Edit" title="Edit">${IC.edit}<span class="action-label">Edit</span></button>
      <button data-delete-post="${p.id}" tabindex="-1" aria-label="Delete" title="Delete" style="color:var(--danger)">${IC.trash}<span class="action-label">Delete</span></button>` : ''}
      ${!isOwn ? `<button data-flag="${p.id}" tabindex="-1" aria-label="Flag" title="Flag">${IC.flag}<span class="action-label">Flag</span></button>` : ''}`}
    </div>
  </div>`;
}
function renderNewTopic() {
  setTitle('New Topic');
  showBack(true);
  $app.innerHTML = `<div class="compose">
    <div class="field"><label for="ntTitle">Title</label>
      <input type="text" id="ntTitle" value="${esc(getDraft('new_topic_title'))}" placeholder="Topic title" tabindex="0"></div>
    <div class="field"><label for="ntCat">Category</label>
      <select id="ntCat" tabindex="0"><option value="">Select...</option>
        ${Object.keys(S.categories).map(function (k) {
    return S.categories[k];
  }).map(function (c) {
    return `<option value="${c.id}">${esc(c.name)}</option>`;
  }).join('')}
      </select></div>
    <div class="field"><label for="ntBody">Body</label>
      <div class="compose-body">
        <div id="ntAttachments" class="attachment-list" style="display:none"></div>
        <textarea id="ntBody" placeholder="Write your topic..." tabindex="0">${esc(getDraft('new_topic_body'))}</textarea>
        <div id="ntPreview" class="md-preview" style="display:none" tabindex="0"></div>
      </div>
    </div>
    <div class="actions chip-actions">
      <label for="uploadNtFile" id="uploadNt" role="button" tabindex="0" style="background:var(--bg3);color:var(--fg);cursor:pointer" aria-label="Upload" title="Upload">${IC.upload}</label>
      <button id="previewNt" tabindex="0" style="background:var(--bg3);color:var(--fg)" aria-label="Preview" title="Preview"></button>
      ${LT_ENABLED ? `<button id="refineNt" tabindex="0" style="background:var(--bg3);color:var(--fg)" aria-label="Refine" title="Refine"><span class="btn-icon">${IC.refine}</span></button>` : ''}
      <span class="actions-spacer" aria-hidden="true"></span>
      <button id="discardNt" class="discard" tabindex="0" aria-label="Discard topic draft" title="Discard">${IC.trash}</button>
      <button id="postTopic" tabindex="0" aria-label="Create topic" title="Create topic">${IC.send}</button>
    </div>
    <input type="file" id="uploadNtFile" tabindex="-1" style="position:absolute;opacity:0;width:1px;height:1px;pointer-events:none">
  </div>`;
  refreshComposeActions();
  var ntTitleEl = document.getElementById('ntTitle');
  var ntBodyEl = document.getElementById('ntBody');
  var discardNtBtn = document.getElementById('discardNt');
  function updateNtDiscard() {
    if (!discardNtBtn) return;
    discardNtBtn.style.display = ntTitleEl.value.trim() || ntBodyEl.value.trim() ? 'inline-flex' : 'none';
  }
  ntTitleEl.focus();
  ntTitleEl.addEventListener('input', function (e) {
    saveDraft('new_topic_title', e.target.value, {
      type: 'topic'
    });
    updateNtDiscard();
  });
  ntBodyEl.addEventListener('input', function (e) {
    saveDraft('new_topic_body', e.target.value, {
      type: 'topic'
    });
    updateNtDiscard();
  });
  updateNtDiscard();
  attachMentionAutocomplete(ntBodyEl, {});
  bindPreview('ntBody', 'ntPreview', 'previewNt', {
    titleId: 'ntTitle',
    categoryId: 'ntCat'
  });
  bindRefine('ntBody', 'refineNt');
  document.getElementById('discardNt').addEventListener('click', /*#__PURE__*/_asyncToGenerator(/*#__PURE__*/_regenerator().m(function _calleeNtDiscard() {
    return _regenerator().w(function (_contextNtDiscard) {
      while (1) switch (_contextNtDiscard.p = _contextNtDiscard.n) {
        case 0:
          _contextNtDiscard.n = 1;
          return confirm('Discard this topic draft?');
        case 1:
          if (_contextNtDiscard.v) {
            _contextNtDiscard.n = 2;
            break;
          }
          return _contextNtDiscard.a(2);
        case 2:
          clearDraft('new_topic_title');
          clearDraft('new_topic_body');
          clearAttachmentPreview('ntAttachments');
          navigate('/new-topic', true);
          return _contextNtDiscard.a(2);
      }
    }, _calleeNtDiscard);
  })));
  refreshComposeActions();
  var uploadNtBtn = document.getElementById('uploadNt');
  var uploadNtInput = document.getElementById('uploadNtFile');
  // Label for= handles touch natively; keydown handles d-pad Enter/Space
  uploadNtBtn.addEventListener('keydown', function (e) {
    if (e.key === 'Enter' || e.key === ' ') {
      e.preventDefault();
      uploadNtInput.click();
    }
  });
  uploadNtInput.addEventListener('change', /*#__PURE__*/function () {
    var _ref9 = _asyncToGenerator(/*#__PURE__*/_regenerator().m(function _callee9(e) {
      var file, r, b, markdown, _t0;
      return _regenerator().w(function (_context9) {
        while (1) switch (_context9.p = _context9.n) {
          case 0:
            file = e.target.files[0];
            if (file) {
              _context9.n = 1;
              break;
            }
            return _context9.a(2);
          case 1:
            _context9.p = 1;
            _context9.n = 2;
            return uploadFile(file, uploadNtBtn);
          case 2:
            r = _context9.v;
            b = document.getElementById('ntBody');
            markdown = buildUploadMarkdown(file, r);
            addAttachmentPreview('ntAttachments', file, r, 'ntBody');
            if (markdown) b.value += `\n${markdown}`;
            b.dispatchEvent(new Event('input'));
            e.target.value = '';
            _context9.n = 4;
            break;
          case 3:
            _context9.p = 3;
            _t0 = _context9.v;
            showAlert(_t0.message);
            e.target.value = '';
          case 4:
            return _context9.a(2);
        }
      }, _callee9, null, [[1, 3]]);
    }));
    return function (_x3) {
      return _ref9.apply(this, arguments);
    };
  }());
  document.getElementById('postTopic').addEventListener('click', /*#__PURE__*/_asyncToGenerator(/*#__PURE__*/_regenerator().m(function _callee0() {
    var title, raw, cat, d, _t1;
    return _regenerator().w(function (_context0) {
      while (1) switch (_context0.p = _context0.n) {
        case 0:
          title = document.getElementById('ntTitle').value.trim();
          raw = document.getElementById('ntBody').value.trim();
          cat = document.getElementById('ntCat').value;
          if (!(!title || !raw)) {
            _context0.n = 1;
            break;
          }
          return _context0.a(2, showAlert('Title and body are required'));
        case 1:
          this.disabled = true;
          this.innerHTML = IC.send;
          this.setAttribute('aria-label', 'Creating...');
          this.setAttribute('title', 'Creating...');
          _context0.p = 2;
          _context0.n = 3;
          return api('/posts.json', {
            method: 'POST',
            body: {
              title,
              raw,
              category: cat ? parseInt(cat) : undefined
            }
          });
        case 3:
          d = _context0.v;
          // Handle both direct response and nested {post: ...} response
          var postData = d.post || d;
          clearDraft('new_topic_title');
          clearDraft('new_topic_body');
          if (postData.topic_id) {
            navigate(topicPath(postData.topic_id, postData.topic_slug || ''));
          } else {
            navigate('/');
          }
          _context0.n = 5;
          break;
        case 4:
          _context0.p = 4;
          _t1 = _context0.v;
          showAlert(formatErrorMessage(_t1));
          this.disabled = false;
          this.innerHTML = IC.send;
          this.setAttribute('aria-label', 'Create topic');
          this.setAttribute('title', 'Create topic');
        case 5:
          return _context0.a(2);
      }
    }, _callee0, this, [[2, 4]]);
  })));
}
function renderNewMessage() {
  setTitle('New Message');
  showBack(true);
  $app.innerHTML = `<div class="compose">
    <div class="field"><label for="pmTo">To (username)</label>
      <input type="text" id="pmTo" placeholder="username" tabindex="0" value="${esc(getDraft('new_message_to'))}"></div>
    <div class="field"><label for="pmTitle">Subject</label>
      <input type="text" id="pmTitle" placeholder="Subject" tabindex="0" value="${esc(getDraft('new_message_title'))}"></div>
    <div class="field"><label for="pmBody">Message</label>
      <div class="compose-body">
        <textarea id="pmBody" placeholder="Write your message..." tabindex="0">${esc(getDraft('new_message_body'))}</textarea>
        <div id="pmPreview" class="md-preview" style="display:none" tabindex="0"></div>
      </div>
    </div>
    <div class="actions chip-actions">
      <button id="previewPm" tabindex="0" style="background:var(--bg3);color:var(--fg)" aria-label="Preview" title="Preview"></button>
      ${LT_ENABLED ? `<button id="refinePm" tabindex="0" style="background:var(--bg3);color:var(--fg)" aria-label="Refine" title="Refine"><span class="btn-icon">${IC.refine}</span></button>` : ''}
      <span class="actions-spacer" aria-hidden="true"></span>
      <button id="discardPm" class="discard" tabindex="0" aria-label="Discard message draft" title="Discard">${IC.trash}</button>
      <button id="sendPm" tabindex="0" aria-label="Send message" title="Send message">${IC.send}</button>
    </div>
  </div>`;
  refreshComposeActions();
  var pmToEl = document.getElementById('pmTo');
  var pmTitleEl = document.getElementById('pmTitle');
  var pmBodyEl = document.getElementById('pmBody');
  var discardPmBtn = document.getElementById('discardPm');
  function updatePmDiscard() {
    if (!discardPmBtn) return;
    discardPmBtn.style.display = pmToEl.value.trim() || pmTitleEl.value.trim() || pmBodyEl.value.trim() ? 'inline-flex' : 'none';
  }
  pmToEl.focus();
  pmToEl.addEventListener('input', function (e) {
    saveDraft('new_message_to', e.target.value, {
      type: 'message'
    });
    updatePmDiscard();
  });
  pmTitleEl.addEventListener('input', function (e) {
    saveDraft('new_message_title', e.target.value, {
      type: 'message'
    });
    updatePmDiscard();
  });
  pmBodyEl.addEventListener('input', function (e) {
    saveDraft('new_message_body', e.target.value, {
      type: 'message'
    });
    updatePmDiscard();
  });
  updatePmDiscard();
  attachMentionAutocomplete(pmBodyEl, {});
  document.getElementById('discardPm').addEventListener('click', /*#__PURE__*/_asyncToGenerator(/*#__PURE__*/_regenerator().m(function _calleePmDiscard() {
    return _regenerator().w(function (_contextPmDiscard) {
      while (1) switch (_contextPmDiscard.p = _contextPmDiscard.n) {
        case 0:
          _contextPmDiscard.n = 1;
          return confirm('Discard this message draft?');
        case 1:
          if (_contextPmDiscard.v) {
            _contextPmDiscard.n = 2;
            break;
          }
          return _contextPmDiscard.a(2);
        case 2:
          clearDraft('new_message_to');
          clearDraft('new_message_title');
          clearDraft('new_message_body');
          navigate('/new-message', true);
          return _contextPmDiscard.a(2);
      }
    }, _calleePmDiscard);
  })));
  bindPreview('pmBody', 'pmPreview', 'previewPm', {
    titleId: 'pmTitle',
    archetype: 'private_message'
  });
  bindRefine('pmBody', 'refinePm');
  refreshComposeActions();
  document.getElementById('sendPm').addEventListener('click', /*#__PURE__*/_asyncToGenerator(/*#__PURE__*/_regenerator().m(function _callee1() {
    var to, title, raw, d, _t10;
    return _regenerator().w(function (_context1) {
      while (1) switch (_context1.p = _context1.n) {
        case 0:
          to = document.getElementById('pmTo').value.trim();
          title = document.getElementById('pmTitle').value.trim();
          raw = document.getElementById('pmBody').value.trim();
          if (!(!to || !title || !raw)) {
            _context1.n = 1;
            break;
          }
          return _context1.a(2, showAlert('All fields required'));
        case 1:
          this.disabled = true;
          this.innerHTML = IC.send;
          this.setAttribute('aria-label', 'Sending...');
          this.setAttribute('title', 'Sending...');
          _context1.p = 2;
          _context1.n = 3;
          return api('/posts.json', {
            method: 'POST',
            body: {
              title,
              raw,
              target_recipients: to,
              archetype: 'private_message'
            }
          });
        case 3:
          d = _context1.v;
          clearDraft('new_message_to');
          clearDraft('new_message_title');
          clearDraft('new_message_body');
          navigate(topicPath(d.topic_id, d.topic_slug));
          _context1.n = 5;
          break;
        case 4:
          _context1.p = 4;
          _t10 = _context1.v;
          showAlert(formatErrorMessage(_t10));
          this.disabled = false;
          this.innerHTML = IC.send;
          this.setAttribute('aria-label', 'Send message');
          this.setAttribute('title', 'Send message');
        case 5:
          return _context1.a(2);
      }
    }, _callee1, this, [[2, 4]]);
  })));
}
function draftSnippet(text) {
  if (!text) return '';
  var clean = String(text).replace(/\s+/g, ' ').trim();
  if (clean.length <= 140) return clean;
  return clean.slice(0, 140) + '…';
}
function collectDraftEntries() {
  var entries = [];
  Object.keys(S.drafts || {}).forEach(function (key) {
    if (key.indexOf('reply_') !== 0) return;
    var entry = getDraftEntry(key);
    var text = entry && entry.text ? entry.text.trim() : '';
    if (!text) return;
    var topicId = key.replace('reply_', '');
    var meta = entry.meta || {};
    entries.push({
      id: key,
      title: meta.topicTitle ? `Reply: ${meta.topicTitle}` : `Reply draft #${topicId}`,
      meta: `Topic ${topicId}`,
      snippet: draftSnippet(text),
      path: topicPath(topicId),
      clearKeys: [key]
    });
  });
  var topicTitle = getDraft('new_topic_title');
  var topicBody = getDraft('new_topic_body');
  if (topicTitle.trim() || topicBody.trim()) {
    entries.push({
      id: 'new_topic',
      title: topicTitle.trim() ? `Topic: ${topicTitle.trim()}` : 'New topic draft',
      meta: 'Topic draft',
      snippet: draftSnippet(topicBody),
      path: '/new-topic',
      clearKeys: ['new_topic_title', 'new_topic_body']
    });
  }
  var pmTo = getDraft('new_message_to');
  var pmTitle = getDraft('new_message_title');
  var pmBody = getDraft('new_message_body');
  if (pmTo.trim() || pmTitle.trim() || pmBody.trim()) {
    entries.push({
      id: 'new_message',
      title: pmTitle.trim() ? `Message: ${pmTitle.trim()}` : 'New message draft',
      meta: pmTo.trim() ? `To ${pmTo.trim()}` : 'Message draft',
      snippet: draftSnippet(pmBody),
      path: '/new-message',
      clearKeys: ['new_message_to', 'new_message_title', 'new_message_body']
    });
  }
  entries.sort(function (a, b) {
    return a.title.localeCompare(b.title);
  });
  return entries;
}
function renderDrafts() {
  setTitle('Drafts');
  showBack(true);
  showCreate('');
  var drafts = collectDraftEntries();
  if (!drafts.length) {
    $app.innerHTML = '<div class="empty">No drafts yet.</div>';
    focusContent();
    return;
  }
  $app.innerHTML = drafts.map(function (draft) {
    return `<div class="list-item draft-item" tabindex="0">
      <div class="item-title">${escEmoji(draft.title)}</div>
      <div class="item-meta"><span>${esc(draft.meta)}</span></div>
      ${draft.snippet ? `<div class="item-excerpt">${escEmoji(draft.snippet)}</div>` : ''}
      <div class="draft-actions">
        <button class="primary" data-draft-open="${esc(draft.path)}" tabindex="0">Open</button>
        <button class="discard" data-draft-clear="${esc(draft.clearKeys.join('|'))}" tabindex="0">Discard</button>
      </div>
    </div>`;
  }).join('');
  $app.querySelectorAll('[data-draft-open]').forEach(function (btn) {
    btn.addEventListener('click', function () {
      navigate(btn.dataset.draftOpen);
    });
  });
  $app.querySelectorAll('[data-draft-clear]').forEach(function (btn) {
    btn.addEventListener('click', /*#__PURE__*/_asyncToGenerator(/*#__PURE__*/_regenerator().m(function _calleeDraftClear() {
      var keys;
      return _regenerator().w(function (_contextDraftClear) {
        while (1) switch (_contextDraftClear.p = _contextDraftClear.n) {
          case 0:
            _contextDraftClear.n = 1;
            return confirm('Discard this draft?');
          case 1:
            if (_contextDraftClear.v) {
              _contextDraftClear.n = 2;
              break;
            }
            return _contextDraftClear.a(2);
          case 2:
            keys = btn.dataset.draftClear.split('|');
            keys.forEach(function (k) {
              return clearDraft(k);
            });
            renderDrafts();
            return _contextDraftClear.a(2);
        }
      }, _calleeDraftClear);
    })));
  });
  focusContent();
}
function renderMessages() {
  return _renderMessages.apply(this, arguments);
} // ============ NOTIFICATIONS ============
function _renderMessages() {
  _renderMessages = _asyncToGenerator(/*#__PURE__*/_regenerator().m(function _callee23() {
    var _d, topics, _t20;
    return _regenerator().w(function (_context23) {
      while (1) switch (_context23.p = _context23.n) {
        case 0:
          setTitle('Messages');
          showBack(false);
          $app.innerHTML = '';
          _context23.p = 1;
          _context23.n = 2;
          return api(`/topics/private-messages/${encodeURIComponent(S.username)}.json`);
        case 2:
          _d = _context23.v;
          topics = _d.topic_list && _d.topic_list.topics || [];
          if (!topics.length) {
            $app.innerHTML = '<div class="empty">No messages</div>';
          } else {
            $app.innerHTML = topics.map(function (t) {
              var unread = isTopicUnread(t);
              return `
        <a class="list-item${unread ? ' unread' : ''}" href="${topicHref(t.id, t.slug)}" tabindex="0">
          <div class="item-title">${escEmoji(t.title)}</div>
          <div class="item-meta"><span>${t.posts_count} posts</span><span>${timeAgo(t.last_posted_at)}</span></div>
        </a>`;
            }).join('');
            _unreadMsgCount = 0;
            topics.forEach(function (t) { if (isTopicUnread(t)) _unreadMsgCount++; });
            updateMenuBadges();
          }
          showCreate('/new-message');
          focusContent();
          _context23.n = 4;
          break;
        case 3:
          _context23.p = 3;
          _t20 = _context23.v;
          $app.innerHTML = `<div class="error">${esc(_t20.message)}</div>`;
        case 4:
          return _context23.a(2);
      }
    }, _callee23, null, [[1, 3]]);
  }));
  return _renderMessages.apply(this, arguments);
}
function showPushSettings() {
  var prev = document.activeElement;
  fetch(PROXY + BASE_PATH + '/push/preferences', {
    headers: { 'Accept': 'application/json' },
    credentials: 'same-origin'
  }).then(function (resp) {
    if (!resp || !resp.ok) throw new Error('Failed to load preferences');
    return resp.json();
  }).then(function (prefs) {
    var el = document.createElement('div');
    el.className = 'confirm-overlay';
    el.innerHTML = '<div class="confirm-box push-prefs-box">' +
      '<h3>Push Notifications</h3>' +
      '<div class="push-pref-list">' +
        '<label class="push-pref-item"><input type="checkbox" id="prefDirectReplies" tabindex="0"' + (prefs.direct_replies !== false ? ' checked' : '') + '> Replies to you</label>' +
        '<label class="push-pref-item"><input type="checkbox" id="prefWatching" tabindex="0"' + (prefs.watching !== false ? ' checked' : '') + '> Watched topics</label>' +
        '<label class="push-pref-item"><input type="checkbox" id="prefMentions" tabindex="0"' + (prefs.mentions !== false ? ' checked' : '') + '> @mentions</label>' +
        '<label class="push-pref-item"><input type="checkbox" id="prefMessages" tabindex="0"' + (prefs.messages !== false ? ' checked' : '') + '> Messages</label>' +
        '<label class="push-pref-item"><input type="checkbox" id="prefQuotes" tabindex="0"' + (prefs.quotes !== false ? ' checked' : '') + '> Quotes</label>' +
        '<label class="push-pref-item"><input type="checkbox" id="prefLikes" tabindex="0"' + (prefs.likes === true ? ' checked' : '') + '> Likes</label>' +
      '</div>' +
      '<div class="actions">' +
        '<button class="cancel" style="background:var(--bg3);color:var(--fg)" tabindex="0">Cancel</button>' +
        '<button class="save" tabindex="0">Save</button>' +
      '</div>' +
    '</div>';
    document.body.appendChild(el);

    var saveBtn = el.querySelector('.save');
    var cancelBtn = el.querySelector('.cancel');
    var firstCheckbox = el.querySelector('input[type="checkbox"]');
    if (firstCheckbox) firstCheckbox.focus();

    function close() {
      el.remove();
      if (prev && prev.focus) prev.focus();
    }

    cancelBtn.onclick = close;
    el.onclick = function (e) {
      if (e.target === el) close();
    };

    saveBtn.onclick = function () {
      saveBtn.disabled = true;
      saveBtn.textContent = 'Saving...';

      var newPrefs = {
        direct_replies: document.getElementById('prefDirectReplies').checked,
        watching: document.getElementById('prefWatching').checked,
        mentions: document.getElementById('prefMentions').checked,
        messages: document.getElementById('prefMessages').checked,
        quotes: document.getElementById('prefQuotes').checked,
        likes: document.getElementById('prefLikes').checked
      };

      fetch(PROXY + BASE_PATH + '/push/preferences', {
        method: 'PUT',
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'X-CSRF-Token': S.csrf || ''
        },
        credentials: 'same-origin',
        body: JSON.stringify(newPrefs)
      }).then(function (resp) {
        if (!resp || !resp.ok) throw new Error('Failed to save');
        close();
      }).catch(function (e) {
        saveBtn.disabled = false;
        saveBtn.textContent = 'Save';
        showAlert(e.message || 'Failed to save preferences');
      });
    };

    el.addEventListener('keydown', function (e) {
      if (e.key === 'Escape') {
        e.stopPropagation();
        close();
      }
      // Enter key toggles checkboxes for dpad navigation
      if (e.key === 'Enter' && e.target.type === 'checkbox') {
        e.preventDefault();
        e.target.checked = !e.target.checked;
      }
    });

  }).catch(function (e) {
    showAlert('Could not load notification settings');
  });
}
function renderNotifications() {
  return _renderNotifications.apply(this, arguments);
} // ============ PROFILE ============
function _renderNotifications() {
  _renderNotifications = _asyncToGenerator(/*#__PURE__*/_regenerator().m(function _callee25() {
    var _d2, notifs, html, _t22;
    return _regenerator().w(function (_context25) {
      while (1) switch (_context25.p = _context25.n) {
        case 0:
          setTitle('Notifications');
          showBack(false);
          $app.innerHTML = '';
          _context25.p = 1;
          _context25.n = 2;
          return api('/notifications.json');
        case 2:
          _d2 = _context25.v;
          notifs = _d2.notifications || [];
          _unreadNotifCount = 0;
          notifs.forEach(function (n) { if (!n.read) _unreadNotifCount++; });
          updateMenuBadges();
          if (notifs.length) {
            _context25.n = 3;
            break;
          }
          $app.innerHTML = '<div class="empty">No notifications</div>';
          return _context25.a(2);
        case 3:
          html = `<div style="display:flex;gap:8px;margin:8px;align-items:center">` + `<button id="markAllRead" tabindex="0" style="background:var(--bg3);color:var(--fg)">Mark all read</button>` + `<div style="flex:1"></div>` + `<button id="pushSettingsBtn" tabindex="0" style="background:var(--bg3);color:var(--fg);padding:8px 10px" title="Push notification settings">` + IC.gear + `</button>` + `</div>`;
          html += notifs.map(function (n) {
            var types = {
              1: IC.msg,
              2: IC.msg,
              5: IC.heart,
              6: IC.msg,
              9: IC.msg,
              12: IC.bookmark,
              15: IC.msg
            };
            var icon = types[n.notification_type] || IC.bell;
            var text = n.data && n.data.display_username ? esc(n.data.display_username) + ': ' : '';
            var topic = n.data && n.data.topic_title || n.data && n.data.badge_name || n.fancy_title || '';
            var href = n.topic_id ? topicHref(n.topic_id) : makeUrl('/notifications');
            return `<a class="notif-item ${n.read ? '' : 'unread'}" href="${href}" tabindex="0">
        <span class="notif-icon">${icon}</span>
        <span class="notif-text">${text}${escEmoji(topic)}</span>
        <span class="notif-time">${timeAgo(n.created_at)}</span>
      </a>`;
          }).join('');
          $app.innerHTML = html;
          document.getElementById('markAllRead').addEventListener('click', /*#__PURE__*/_asyncToGenerator(/*#__PURE__*/_regenerator().m(function _callee24() {
            var _t21;
            return _regenerator().w(function (_context24) {
              while (1) switch (_context24.p = _context24.n) {
                case 0:
                  this.disabled = true;
                  this.textContent = 'Marking...';
                  _context24.p = 1;
                  _context24.n = 2;
                  return api('/notifications/mark-read.json', {
                    method: 'PUT'
                  });
                case 2:
                  _unreadNotifCount = 0;
                  updateMenuBadges();
                  _context24.n = 3;
                  return renderNotifications();
                case 3:
                  _context24.n = 5;
                  break;
                case 4:
                  _context24.p = 4;
                  _t21 = _context24.v;
                  showAlert(_t21.message);
                  this.disabled = false;
                  this.textContent = 'Mark all read';
                case 5:
                  return _context24.a(2);
              }
            }, _callee24, this, [[1, 4]]);
          })));
          var pushSettingsBtn = document.getElementById('pushSettingsBtn');
          if (pushSettingsBtn) {
            pushSettingsBtn.addEventListener('click', function () {
              showPushSettings();
            });
          }
          focusContent();
          _context25.n = 5;
          break;
        case 4:
          _context25.p = 4;
          _t22 = _context25.v;
          $app.innerHTML = `<div class="error">${esc(_t22.message)}</div>`;
        case 5:
          return _context25.a(2);
      }
    }, _callee25, null, [[1, 4]]);
  }));
  return _renderNotifications.apply(this, arguments);
}
// ============ REVIEW QUEUE ============
function renderReview() {
  if (!canModerate()) {
    $app.innerHTML = '<div class="empty">Access denied</div>';
    return Promise.resolve();
  }
  setTitle('Review Queue');
  showBack(false);
  $app.innerHTML = '';
  return api('/review.json').then(function (d) {
    var items = d.reviewables || [];
    if (!items.length) {
      $app.innerHTML = '<div class="empty">No items to review</div>';
      return;
    }
    var users = {};
    (d.users || []).forEach(function (u) { users[u.id] = u; });
    var html = items.map(function (r) {
      var user = users[r.created_by_id] || {};
      var targetUser = users[r.target_created_by_id] || {};
      var typeLabel = r.type === 'ReviewableFlaggedPost' ? 'Flagged Post' :
                      r.type === 'ReviewableQueuedPost' ? 'Queued Post' :
                      r.type === 'ReviewableUser' ? 'User' : r.type;
      var statusLabel = r.status === 0 ? 'Pending' : r.status === 1 ? 'Approved' : r.status === 2 ? 'Rejected' : r.status === 3 ? 'Ignored' : r.status === 4 ? 'Deleted' : '';
      var excerpt = r.post_body ? esc(r.post_body.slice(0, 150)) + (r.post_body.length > 150 ? '...' : '') : '';
      var topicTitle = r.topic_fancy_title || r.payload && r.payload.raw && r.payload.raw.slice(0, 50) || '';
      return '<div class="review-item" style="padding:12px;border-bottom:1px solid var(--border)">' +
        '<div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:8px">' +
          '<span style="font-weight:600;color:var(--accent)">' + esc(typeLabel) + '</span>' +
          '<span style="font-size:.8rem;color:var(--fg2)">' + timeAgo(r.created_at) + '</span>' +
        '</div>' +
        (topicTitle ? '<div style="font-weight:500;margin-bottom:4px">' + escEmoji(topicTitle) + '</div>' : '') +
        (targetUser.username ? '<div style="font-size:.85rem;color:var(--fg2);margin-bottom:4px">By: @' + esc(targetUser.username) + '</div>' : '') +
        (excerpt ? '<div style="font-size:.9rem;color:var(--fg);margin-bottom:8px">' + excerpt + '</div>' : '') +
        '<div style="display:flex;gap:8px;flex-wrap:wrap">' +
          '<button class="review-approve" data-id="' + r.id + '" tabindex="0" style="background:var(--success,#2a2);color:#fff;font-size:.85rem">Approve</button>' +
          '<button class="review-reject" data-id="' + r.id + '" tabindex="0" style="background:var(--danger);color:#fff;font-size:.85rem">Reject</button>' +
          '<button class="review-ignore" data-id="' + r.id + '" tabindex="0" style="background:var(--bg3);color:var(--fg);font-size:.85rem">Ignore</button>' +
          (r.topic_id ? '<a href="' + topicHref(r.topic_id) + '" tabindex="0" style="background:var(--bg3);color:var(--fg);font-size:.85rem;padding:6px 12px;border-radius:var(--radius);text-decoration:none">View Topic</a>' : '') +
        '</div>' +
      '</div>';
    }).join('');
    $app.innerHTML = html;
    function handleReview(id, action) {
      var actionId = action === 'approve' ? 0 : action === 'reject' ? 1 : 2;
      return api('/review/' + id + '/perform/' + action + '.json', {
        method: 'PUT'
      }).then(function () {
        return renderReview();
      }).catch(function (e) {
        showAlert(e.message || 'Action failed');
      });
    }
    $app.querySelectorAll('.review-approve').forEach(function (btn) {
      btn.addEventListener('click', function () {
        btn.disabled = true;
        handleReview(btn.dataset.id, 'approve');
      });
    });
    $app.querySelectorAll('.review-reject').forEach(function (btn) {
      btn.addEventListener('click', function () {
        btn.disabled = true;
        handleReview(btn.dataset.id, 'reject');
      });
    });
    $app.querySelectorAll('.review-ignore').forEach(function (btn) {
      btn.addEventListener('click', function () {
        btn.disabled = true;
        handleReview(btn.dataset.id, 'ignore');
      });
    });
    focusContent();
  }).catch(function (e) {
    $app.innerHTML = '<div class="error">' + esc(e.message) + '</div>';
  });
}
function renderProfile(_x4) {
  return _renderProfile.apply(this, arguments);
} // ============ SETTINGS ============
function loadProfileActivity(uname) {
  return api(`/u/${encodeURIComponent(uname)}/activity.json`).then(function (act) {
    var posts = act && act.user_actions || [];
    if (posts.length) return posts;
    return api(`/user_actions.json?username=${encodeURIComponent(uname)}&offset=0`).then(function (act2) {
      return act2 && act2.user_actions || [];
    }, function () {
      return [];
    });
  }, function () {
    return api(`/user_actions.json?username=${encodeURIComponent(uname)}&offset=0`).then(function (act2) {
      return act2 && act2.user_actions || [];
    }, function () {
      return [];
    });
  });
}
function _renderProfile() {
  _renderProfile = _asyncToGenerator(/*#__PURE__*/_regenerator().m(function _callee26(username) {
    var uname, _d3, u, html, act, posts, actHtml, _t23, _t24;
    return _regenerator().w(function (_context26) {
      while (1) switch (_context26.p = _context26.n) {
        case 0:
          showBack(username !== S.username && username !== 'me');
          uname = username === 'me' ? S.username : username;
          setTitle(uname);
          $app.innerHTML = '';
          _context26.p = 1;
          _context26.n = 2;
          return api(`/u/${encodeURIComponent(uname)}.json`);
        case 2:
          _d3 = _context26.v;
          u = _d3.user;
          var banner = u.profile_background_url || u.card_background_url || u.profile_background_upload_url || u.card_background_upload_url;
          var bannerUrl = banner ? rewriteSrc(banner) : '';
          var joined = formatDate(u.created_at);
          var joinedLabel = joined ? 'Joined' : 'Days';
          var joinedVal = joined || (u.days_visited || 0);
          var metaBits = [];
          if (u.location) metaBits.push(`<div class="meta-item"><strong>Location:</strong> ${esc(u.location)}</div>`);
          if (u.website) {
            var web = normalizeUrl(u.website);
            metaBits.push(`<div class="meta-item"><strong>Website:</strong> <a href="${rewriteHref(web)}" target="_blank" rel="noopener">${esc(u.website)}</a></div>`);
          }
          if (u.last_posted_at) metaBits.push(`<div class="meta-item"><strong>Last post:</strong> ${esc(timeAgo(u.last_posted_at))}</div>`);
          if (u.last_seen_at) metaBits.push(`<div class="meta-item"><strong>Last seen:</strong> ${esc(timeAgo(u.last_seen_at))}</div>`);
          var levelVal = u.admin ? 'Admin' : u.moderator ? 'Mod' : u.trust_level != null ? u.trust_level : 0;
          html = `<div class="profile">
      ${bannerUrl ? `<div class="profile-banner" style="background-image:url('${bannerUrl}')" tabindex="0"></div>` : ''}
      <div class="profile-section profile-card ${bannerUrl ? '' : 'no-banner'}" tabindex="0">
        <img class="avatar" src="${avatarUrl(u.avatar_template, 120)}" alt="${esc(u.username)}">
        <div class="profile-main">
          <div class="profile-name">${esc(u.name || u.username)}</div>
          <div class="profile-username">@${esc(u.username)}</div>
          ${u.title ? `<div class="profile-title">${esc(u.title)}</div>` : ''}
        </div>
      </div>
      <div class="profile-stats">
        <div class="profile-stat" tabindex="0"><span class="num">${u.post_count || 0}</span><span class="label">Posts</span></div>
        <div class="profile-stat" tabindex="0"><span class="num">${esc(levelVal)}</span><span class="label">Level</span></div>
        <div class="profile-stat" tabindex="0"><span class="num">${esc(joinedVal)}</span><span class="label">${joinedLabel}</span></div>
      </div>
      ${metaBits.length ? `<div class="profile-section" tabindex="0"><div class="profile-meta">${metaBits.join('')}</div></div>` : ''}
      ${u.bio_cooked ? `<div class="profile-section profile-bio" tabindex="0">${fixPostHtml(u.bio_cooked)}</div>` : ''}
      ${u.badges && u.badges.length ? '<div class="profile-section" tabindex="0" style="display:flex;flex-wrap:wrap;gap:4px">' + u.badges.map(function (b) {
            return '<span class="user-badge">' + esc(b.name) + '</span>';
          }).join('') + '</div>' : ''}</div>`;
          if (uname === S.username) {
            html += `<div class="profile-actions">
        <button tabindex="0" id="editProfileBtn">Edit Profile</button>
        <button tabindex="0" style="background:var(--danger)" id="logoutBtn">Log Out</button>
      </div>`;
          }
          html += `<h3 style="padding:12px 12px 4px;font-size:.95rem">Recent Activity</h3>`;
          $app.innerHTML = html;
          enhanceCooked($app);
          if (uname === S.username) {
            document.getElementById('editProfileBtn').addEventListener('click', function () {
              return navigate('/settings');
            });
            document.getElementById('logoutBtn').addEventListener('click', function () {
              return logout();
            });
          }
          _context26.p = 3;
          _context26.n = 4;
          return loadProfileActivity(uname);
        case 4:
          act = _context26.v;
          posts = (act || []).filter(function (a) {
            return a && a.topic_id;
          });
          if (posts.length) {
            actHtml = posts.slice(0, 20).map(function (a) {
              var ex = a.excerpt || a.cooked || '';
              var exHtml = '';
              if (ex) {
                exHtml = `<div class="item-excerpt">${fixPostHtml(ex)}</div>`;
              } else if (a.raw) {
                exHtml = `<div class="item-excerpt">${esc(a.raw)}</div>`;
              }
              return `
          <a class="list-item" href="${topicHref(a.topic_id, a.topic_slug)}" tabindex="0">
            <div class="item-title">${escEmoji(a.title)}</div>
            ${exHtml}
            <div class="item-meta"><span>${timeAgo(a.created_at)}</span></div>
          </a>`;
            }).join('');
            $app.insertAdjacentHTML('beforeend', actHtml);
          } else {
            $app.insertAdjacentHTML('beforeend', '<div class="empty">No recent activity</div>');
          }
          _context26.n = 6;
          break;
        case 5:
          _context26.p = 5;
          _t23 = _context26.v;
        case 6:
          focusContent();
          _context26.n = 8;
          break;
        case 7:
          _context26.p = 7;
          _t24 = _context26.v;
          $app.innerHTML = `<div class="error">${esc(_t24.message)}</div>`;
        case 8:
          return _context26.a(2);
      }
    }, _callee26, null, [[3, 5], [1, 7]]);
  }));
  return _renderProfile.apply(this, arguments);
}
function renderSettings() {
  setTitle('Settings');
  showBack(true);
  $app.innerHTML = `<div class="compose profile-edit">
    <h3 style="margin-bottom:12px">Edit Profile</h3>
    <div class="field"><label for="setName">Display Name</label>
      <input type="text" id="setName" tabindex="0"></div>
    <div class="field"><label for="setTitle">Title</label>
      <input type="text" id="setTitle" tabindex="0"></div>
    <div class="field"><label for="setLocation">Location</label>
      <input type="text" id="setLocation" tabindex="0"></div>
    <div class="field"><label for="setWebsite">Website</label>
      <input type="text" id="setWebsite" tabindex="0"></div>
    <div class="field"><label for="setBio">Bio</label>
      <textarea id="setBio" tabindex="0"></textarea></div>
    <div class="field"><label for="setStatus">Status</label>
      <input type="text" id="setStatus" placeholder=":emoji: Status text" tabindex="0">
      <div class="hint">Emoji + text (optional)</div></div>
    <div class="actions">
      <button id="saveProfBtn" tabindex="0" style="flex:1">Save</button>
      <button id="cancelProfBtn" tabindex="0" style="background:var(--bg3);color:var(--fg)">Cancel</button>
    </div>
    <button tabindex="0" style="width:100%;background:var(--danger)" id="settingsLogout">Log Out</button>
  </div>`;
  api(`/u/${encodeURIComponent(S.username)}.json`).then(function (d) {
    var u = d && d.user || {};
    var el = document.getElementById('setName');
    if (el) el.value = u.name || '';
    var title = document.getElementById('setTitle');
    if (title) title.value = u.title || '';
    var loc = document.getElementById('setLocation');
    if (loc) loc.value = u.location || '';
    var web = document.getElementById('setWebsite');
    if (web) web.value = u.website || '';
    var bio = document.getElementById('setBio');
    if (bio) bio.value = u.bio_raw || '';
    var st = document.getElementById('setStatus');
    if (st && u.user_status) {
      var emoji = u.user_status.emoji ? ':' + u.user_status.emoji + ':' : '';
      var desc = u.user_status.description || '';
      st.value = (emoji ? emoji + ' ' : '') + desc;
    }
  }).catch(function () {});
  requestAnimationFrame(function () {
    var el = document.getElementById('setName');
    if (el) el.focus();
  });
  document.getElementById('cancelProfBtn').addEventListener('click', function () {
    navigate('/u/me');
  });
  document.getElementById('saveProfBtn').addEventListener('click', /*#__PURE__*/_asyncToGenerator(/*#__PURE__*/_regenerator().m(function _callee10() {
    var profileBody, st, emoji, desc, parts, _t11;
    return _regenerator().w(function (_context10) {
      while (1) switch (_context10.p = _context10.n) {
        case 0:
          this.disabled = true;
          this.textContent = 'Saving...';
          _context10.p = 1;
          _context10.n = 2;
          return ensureCsrf();
        case 2:
          profileBody = {
            name: document.getElementById('setName').value.trim(),
            title: document.getElementById('setTitle').value.trim(),
            location: document.getElementById('setLocation').value.trim(),
            website: document.getElementById('setWebsite').value.trim(),
            bio_raw: document.getElementById('setBio').value
          };
          _context10.n = 3;
          return api(`/u/${encodeURIComponent(S.username)}.json`, {
            method: 'PUT',
            body: profileBody
          }).catch(function (e) {
            var msg = e && e.message || '';
            if (msg.indexOf('404') >= 0 || msg.indexOf('405') >= 0) {
              return api(`/u/${encodeURIComponent(S.username)}/preferences.json`, {
                method: 'PUT',
                body: profileBody
              });
            }
            throw e;
          });
        case 3:
          st = document.getElementById('setStatus').value.trim();
          if (!st) {
            _context10.n = 6;
            break;
          }
          emoji = '';
          desc = st;
          if (st.indexOf(':') === 0 && st.indexOf(':', 1) > 1) {
            parts = st.split(':');
            emoji = parts[1] || '';
            desc = st.slice(emoji.length + 2).trim();
          }
          _context10.n = 5;
          return api('/user-status.json', {
            method: 'PUT',
            body: {
              emoji: emoji || undefined,
              description: desc
            }
          }).catch(function () {});
        case 5:
        case 6:
          navigate('/u/me');
          _context10.n = 8;
          break;
        case 7:
          _context10.p = 7;
          _t11 = _context10.v;
          showAlert(formatErrorMessage(_t11));
          this.disabled = false;
          this.textContent = 'Save';
        case 8:
          return _context10.a(2);
      }
    }, _callee10, this, [[1, 7]]);
  })));
  document.getElementById('settingsLogout').addEventListener('click', function () {
    return logout();
  });
}
var menuOpen = false;
var menuJustToggled = false;
var viewOpen = false;
var viewJustToggled = false;
function updateMenuItems() {
  var logged = isLoggedIn();
  var inTopic = !!(CURRENT_TOPIC && CURRENT_TOPIC.id);
  var showMod = inTopic && canModerate();
  // Show/hide nav items (hide when in topic for all users)
  $menu.querySelectorAll('[data-nav]').forEach(function (el) {
    var isAuth = el.hasAttribute('data-auth');
    if (inTopic) {
      el.style.display = 'none';
    } else {
      el.style.display = isAuth ? (logged ? '' : 'none') : '';
    }
  });
  // Show/hide mod items (only for mods in topic)
  $menu.querySelectorAll('[data-mod]').forEach(function (el) {
    el.style.display = showMod ? '' : 'none';
  });
  // Show/hide mod-front items (only for mods on front page, not in topic)
  var showModFront = !inTopic && canModerate();
  $menu.querySelectorAll('[data-mod-front]').forEach(function (el) {
    el.style.display = showModFront ? '' : 'none';
  });
  // Update mod button labels based on topic state
  if (showMod && CURRENT_TOPIC) {
    var topic = CURRENT_TOPIC;
    var closeBtn = document.getElementById('menuModClose');
    var pinBtn = document.getElementById('menuModPin');
    var archiveBtn = document.getElementById('menuModArchive');
    var unlistBtn = document.getElementById('menuModUnlist');
    if (closeBtn) closeBtn.querySelector('span').textContent = topic.closed ? 'Reopen' : 'Close';
    if (pinBtn) pinBtn.querySelector('span').textContent = (topic.pinned || topic.pinned_at) ? 'Unpin' : 'Pin';
    if (archiveBtn) archiveBtn.querySelector('span').textContent = topic.archived ? 'Unarchive' : 'Archive';
    if (unlistBtn) unlistBtn.querySelector('span').textContent = topic.visible === false ? 'List' : 'Unlist';
  }
  var authBtn = document.getElementById('menuAuthBtn');
  if (logged) {
    authBtn.textContent = '';
    authBtn.innerHTML = '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4"/><polyline points="16 17 21 12 16 7"/><line x1="21" y1="12" x2="9" y2="12"/></svg> Log Out';
    authBtn.style.color = 'var(--danger)';
  } else {
    authBtn.innerHTML = '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M15 3h4a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2h-4"/><polyline points="10 17 15 12 10 7"/><line x1="15" y1="12" x2="3" y2="12"/></svg> Log In';
    authBtn.style.color = 'var(--accent)';
  }
  updateMenuBadges();
}
function refreshUnreadMessageCount() {
  if (!isLoggedIn()) return;
  api('/topics/private-messages/' + encodeURIComponent(S.username) + '.json').then(function (d) {
    var topics = d && d.topic_list && d.topic_list.topics || [];
    var count = 0;
    topics.forEach(function (t) { if (isTopicUnread(t)) count++; });
    _unreadMsgCount = count;
    updateMenuBadges();
  }).catch(function () {});
}
function refreshUnreadNotifCount() {
  if (!isLoggedIn()) return;
  api('/notifications.json').then(function (d) {
    var notifs = d && d.notifications || [];
    var count = 0;
    notifs.forEach(function (n) { if (!n.read) count++; });
    _unreadNotifCount = count;
    updateMenuBadges();
  }).catch(function () {});
}
function updateMenuBadges() {
  var msgLink = document.getElementById('menuMessages');
  if (msgLink) {
    var existing = msgLink.querySelector('.msg-badge');
    if (existing) existing.remove();
    if (_unreadMsgCount > 0) {
      var badge = document.createElement('span');
      badge.className = 'msg-badge';
      badge.textContent = _unreadMsgCount;
      msgLink.appendChild(badge);
    }
  }
  var notifLink = document.getElementById('menuNotifications');
  if (notifLink) {
    var existingN = notifLink.querySelector('.msg-badge');
    if (existingN) existingN.remove();
    if (_unreadNotifCount > 0) {
      var badgeN = document.createElement('span');
      badgeN.className = 'msg-badge';
      badgeN.textContent = _unreadNotifCount;
      notifLink.appendChild(badgeN);
    }
  }
  var menuBtnEl = document.getElementById('menuBtn');
  var wrap = menuBtnEl && menuBtnEl.parentElement;
  if (wrap) {
    var dot = wrap.querySelector('.menu-dot');
    if (dot) dot.remove();
    if (_unreadMsgCount > 0 || _unreadNotifCount > 0) {
      var d = document.createElement('span');
      d.className = 'menu-dot';
      wrap.appendChild(d);
    }
  }
}
function toggleMenu(open) {
  var show = open !== undefined ? open : !menuOpen;
  menuOpen = show;
  menuJustToggled = true;
  setTimeout(function() { menuJustToggled = false; }, 100);
  $menu.classList.toggle('open', show);
  if (show) {
    updateMenuItems();
    if (history && history.pushState) {
      history.pushState({
        menu: true
      }, '');
    }
    var first = $menu.querySelector('a:not([style*="display: none"])');
    if (first) first.focus();
  }
}
function toggleView(open) {
  if (!$view || !$viewBtn) return;
  if (menuOpen) toggleMenu(false);
  var show = open !== undefined ? open : !viewOpen;
  viewOpen = show;
  viewJustToggled = true;
  setTimeout(function() { viewJustToggled = false; }, 100);
  $view.classList.toggle('open', show);
  if (show) {
    setActiveView(topicView);
    if (history && history.pushState) {
      history.pushState({
        view: true
      }, '');
    }
    var first = $view.querySelector('a[data-view]');
    if (first) first.focus();
  }
}
window.addEventListener('popstate', function (e) {
  if (viewOpen) {
    viewOpen = false;
    $view.classList.remove('open');
    $viewBtn && $viewBtn.focus();
    e.stopImmediatePropagation();
    return;
  }
  if (menuOpen) {
    menuOpen = false;
    $menu.classList.remove('open');
    $menuBtn.focus();
    e.stopImmediatePropagation();
  }
});
$menuBtn.addEventListener('click', function (e) {
  e.stopPropagation();
  if (viewOpen) toggleView(false);
  toggleMenu();
});
if ($view) {
  $view.querySelectorAll('a').forEach(function (a) {
    return a.addEventListener('click', function () {
      return toggleView(false);
    });
  });
}
$menu.querySelectorAll('a').forEach(function (a) {
  return a.addEventListener('click', function () {
    return toggleMenu(false);
  });
});
document.getElementById('menuAuthBtn').addEventListener('click', function (e) {
  e.preventDefault();
  toggleMenu(false);
  if (isLoggedIn()) logout();else {
    navigate('/');
  }
});
// Mod menu action handlers
document.getElementById('menuModClose').addEventListener('click', function () {
  if (!CURRENT_TOPIC || !CURRENT_TOPIC.id) return;
  var topicId = CURRENT_TOPIC.id;
  var isClosed = !!CURRENT_TOPIC.closed;
  var action = isClosed ? 'Reopen' : 'Close';
  toggleMenu(false);
  confirm(action + ' this topic?').then(function (ok) {
    if (!ok) return;
    api('/t/' + topicId + '/status.json', {
      method: 'PUT',
      body: { status: 'closed', enabled: isClosed ? 'false' : 'true' }
    }).then(function () {
      return softRefresh();
    }).catch(function (e) {
      showAlert(e.message || 'Failed to ' + action.toLowerCase() + ' topic');
    });
  });
});
document.getElementById('menuModPin').addEventListener('click', function () {
  if (!CURRENT_TOPIC || !CURRENT_TOPIC.id) return;
  var topicId = CURRENT_TOPIC.id;
  var isPinned = !!(CURRENT_TOPIC.pinned || CURRENT_TOPIC.pinned_at);
  var action = isPinned ? 'Unpin' : 'Pin';
  toggleMenu(false);
  confirm(action + ' this topic?').then(function (ok) {
    if (!ok) return;
    api('/t/' + topicId + '/status.json', {
      method: 'PUT',
      body: { status: 'pinned', enabled: isPinned ? 'false' : 'true', until: isPinned ? '' : '2099-12-31' }
    }).then(function () {
      return softRefresh();
    }).catch(function (e) {
      showAlert(e.message || 'Failed to ' + action.toLowerCase() + ' topic');
    });
  });
});
document.getElementById('menuModArchive').addEventListener('click', function () {
  if (!CURRENT_TOPIC || !CURRENT_TOPIC.id) return;
  var topicId = CURRENT_TOPIC.id;
  var isArchived = !!CURRENT_TOPIC.archived;
  var action = isArchived ? 'Unarchive' : 'Archive';
  toggleMenu(false);
  confirm(action + ' this topic?').then(function (ok) {
    if (!ok) return;
    api('/t/' + topicId + '/status.json', {
      method: 'PUT',
      body: { status: 'archived', enabled: isArchived ? 'false' : 'true' }
    }).then(function () {
      return softRefresh();
    }).catch(function (e) {
      showAlert(e.message || 'Failed to ' + action.toLowerCase() + ' topic');
    });
  });
});
document.getElementById('menuModUnlist').addEventListener('click', function () {
  if (!CURRENT_TOPIC || !CURRENT_TOPIC.id) return;
  var topicId = CURRENT_TOPIC.id;
  var isVisible = CURRENT_TOPIC.visible !== false;
  var action = isVisible ? 'Unlist' : 'List';
  toggleMenu(false);
  confirm(action + ' this topic?').then(function (ok) {
    if (!ok) return;
    api('/t/' + topicId + '/status.json', {
      method: 'PUT',
      body: { status: 'visible', enabled: isVisible ? 'false' : 'true' }
    }).then(function () {
      return softRefresh();
    }).catch(function (e) {
      showAlert(e.message || 'Failed to ' + action.toLowerCase() + ' topic');
    });
  });
});
document.getElementById('menuModDelete').addEventListener('click', function () {
  if (!CURRENT_TOPIC || !CURRENT_TOPIC.id) return;
  var topicId = CURRENT_TOPIC.id;
  toggleMenu(false);
  confirm('Delete this topic? This cannot be undone.').then(function (ok) {
    if (!ok) return;
    api('/t/' + topicId + '.json', {
      method: 'DELETE'
    }).then(function () {
      navigate('/');
    }).catch(function (e) {
      showAlert(e.message || 'Failed to delete topic');
    });
  });
});
document.addEventListener('click', function (e) {
  if (!menuJustToggled && $menu.classList.contains('open') && !$menu.contains(e.target) && e.target !== $menuBtn) {
    toggleMenu(false);
  }
  if ($view && !viewJustToggled && $view.classList.contains('open') && !$view.contains(e.target) && e.target !== $viewBtn) {
    toggleView(false);
  }
});
var scale = parseInt(storageGet('jt_scale', '100') || '100');
function applyScale() {
  document.documentElement.style.fontSize = 15 * scale / 100 + 'px';
  document.getElementById('scaleLabel').textContent = scale + '%';
  updatePostActionCompact();
}
applyScale();
document.getElementById('scaleDown').addEventListener('click', function (e) {
  e.preventDefault();
  scale = Math.max(50, scale - 10);
  storageSet('jt_scale', scale);
  applyScale();
});
document.getElementById('scaleUp').addEventListener('click', function (e) {
  e.preventDefault();
  scale = Math.min(200, scale + 10);
  storageSet('jt_scale', scale);
  applyScale();
});
var $menuThemeBtn = document.getElementById('menuThemeBtn');
var sunSvg = '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="5"/><line x1="12" y1="1" x2="12" y2="3"/><line x1="12" y1="21" x2="12" y2="23"/><line x1="4.22" y1="4.22" x2="5.64" y2="5.64"/><line x1="18.36" y1="18.36" x2="19.78" y2="19.78"/><line x1="1" y1="12" x2="3" y2="12"/><line x1="21" y1="12" x2="23" y2="12"/><line x1="4.22" y1="19.78" x2="5.64" y2="18.36"/><line x1="18.36" y1="5.64" x2="19.78" y2="4.22"/></svg>';
var moonSvg = '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M21 12.79A9 9 0 1 1 11.21 3 7 7 0 0 0 21 12.79z"/></svg>';
var DUMBCOURSE_SETTINGS = window.DUMBCOURSE_SETTINGS || {};
var defaultTheme = DUMBCOURSE_SETTINGS.defaultTheme || '';
var defaultView = (DUMBCOURSE_SETTINGS.defaultView || 'latest').toLowerCase();
var showCategoryNames = DUMBCOURSE_SETTINGS.showCategoryNames !== false;
var topicPostersVisibility = (DUMBCOURSE_SETTINGS.topicPostersVisibility || '').toLowerCase();
if (!topicPostersVisibility) {
  var legacyShowTopicPosters = DUMBCOURSE_SETTINGS.showTopicPosters !== false;
  var legacyShowTopicPostersMobile = DUMBCOURSE_SETTINGS.showTopicPostersMobile !== false;
  var legacyShowTopicPostersDesktop = DUMBCOURSE_SETTINGS.showTopicPostersDesktop !== false;
  if (!legacyShowTopicPosters) {
    topicPostersVisibility = 'none';
  } else if (legacyShowTopicPostersMobile && legacyShowTopicPostersDesktop) {
    topicPostersVisibility = 'all';
  } else if (legacyShowTopicPostersMobile) {
    topicPostersVisibility = 'mobile';
  } else if (legacyShowTopicPostersDesktop) {
    topicPostersVisibility = 'desktop';
  } else {
    topicPostersVisibility = 'none';
  }
}
HCAPTCHA_ENABLED = !!DUMBCOURSE_SETTINGS.hcaptchaEnabled;
HCAPTCHA_SITE_KEY = DUMBCOURSE_SETTINGS.hcaptchaSiteKey || '';
if (!storageGet('jt_theme', '')) {
  if (defaultTheme === 'light' || defaultTheme === 'dark') {
    storageSet('jt_theme', defaultTheme);
  }
}
function applyTheme(light) {
  document.documentElement.classList.toggle('light', light);
  if ($menuThemeBtn) {
    $menuThemeBtn.innerHTML = light ? moonSvg + ' Dark Mode' : sunSvg + ' Light Mode';
  }
  storageSet('jt_theme', light ? 'light' : 'dark');
}
applyTheme(storageGet('jt_theme', '') === 'light');
if ($menuThemeBtn) {
  $menuThemeBtn.addEventListener('click', function () {
    applyTheme(!document.documentElement.classList.contains('light'));
  });
}
var navMode = 'dpad';
function getNavMode() {
  return navMode;
}
function setNavMode(mode) {
  navMode = mode;
  document.documentElement.setAttribute('data-nav-mode', mode);
  var viewport = document.querySelector('meta[name="viewport"]');
  viewport.content = 'width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no';
  updatePostTabindexes();
}
var postActionCompactTimer = null;
function updatePostActionCompact() {
  var actionRows = document.querySelectorAll('.post-actions');
  for (var i = 0; i < actionRows.length; i++) {
    var row = actionRows[i];
    row.classList.remove('compact');
    var buttons = row.querySelectorAll('button');
    if (!buttons.length) continue;
    var firstTop = buttons[0].offsetTop;
    var wraps = false;
    for (var j = 1; j < buttons.length; j++) {
      if (buttons[j].offsetTop > firstTop) {
        wraps = true;
        break;
      }
    }
    if (wraps) row.classList.add('compact');
  }
}
function schedulePostActionCompact() {
  if (postActionCompactTimer) clearTimeout(postActionCompactTimer);
  postActionCompactTimer = setTimeout(function () {
    updatePostActionCompact();
  }, 50);
}
function setPostBodyTabindex(post, active) {
  var items = post.querySelectorAll('.post-body a, .post-body button, .post-body input, .post-body textarea, .post-body select, .post-body summary, .post-body details, .post-body .spoiler, .post-body .spoiler-blurred, .post-body .poll, .post-body .poll-option, .post-body img, .post-body iframe, .post-body video, .post-body audio');
  items.forEach(function (el) {
    if (el.dataset.dumbTab === undefined) {
      var t = el.getAttribute('tabindex');
      el.dataset.dumbTab = t === null ? '' : t;
    }
    if (active) {
      if (el.dataset.dumbTab === '') {
        el.removeAttribute('tabindex');
      } else {
        el.setAttribute('tabindex', el.dataset.dumbTab);
      }
      if (!el.hasAttribute('tabindex') && (el.classList.contains('spoiler') || el.classList.contains('spoiler-blurred') || el.classList.contains('poll-option'))) {
        el.setAttribute('tabindex', '0');
      }
    } else {
      el.setAttribute('tabindex', '-1');
    }
  });
}
function updatePostTabindexes() {
  document.querySelectorAll('.post').forEach(function(post) {
    var active = post.classList.contains('active');
    if (!active) {
      post.querySelectorAll('.post-actions button, .post-reactions button, .post-reply-link').forEach(function(btn) {
        btn.setAttribute('tabindex', '-1');
      });
    }
    post.querySelectorAll('.post-author, .post-avatar-link').forEach(function (a) {
      a.setAttribute('tabindex', active ? '0' : '-1');
    });
    setPostBodyTabindex(post, active);
  });
  updatePostActionCompact();
}
setNavMode(navMode);
window.addEventListener('resize', schedulePostActionCompact);
function renderSearch() {
  return _renderSearch.apply(this, arguments);
} // ============ PULL TO REFRESH ============
function _renderSearch() {
  _renderSearch = _asyncToGenerator(/*#__PURE__*/_regenerator().m(function _callee28() {
    var qs, q, html, doSearch;
    return _regenerator().w(function (_context28) {
      while (1) switch (_context28.n) {
        case 0:
          qs = currentQuery();
          q = '';
          qs.split('&').forEach(function (p) {
            var kv = p.split('=');
            if (kv[0] === 'q') q = decodeURIComponent(kv[1] || '');
          });
          document.body.classList.add('search-mode');
          setTitle('Search');
          showBack(true);
          html = `<div class="search-bar">
    <input type="search" id="searchInput" value="${esc(q)}" placeholder="Search forums..." tabindex="0">
    <button id="searchGo" tabindex="0">Go</button>
  </div>`;
          html += '<div id="searchResults"></div>';
          $app.innerHTML = html;
          doSearch = /*#__PURE__*/function () {
            var _ref17 = _asyncToGenerator(/*#__PURE__*/_regenerator().m(function _callee27() {
              var query, results, _d4, rhtml, topics, users, _t25;
              return _regenerator().w(function (_context27) {
                while (1) switch (_context27.p = _context27.n) {
                  case 0:
                    query = document.getElementById('searchInput').value.trim();
                    if (query) {
                      _context27.n = 1;
                      break;
                    }
                    return _context27.a(2);
                  case 1:
                    if (query.length < 3) {
                      showAlert('Search needs at least 3 characters.');
                      return _context27.a(2);
                    }
                    setUrl('/search?q=' + encodeURIComponent(query), true);
                    results = document.getElementById('searchResults');
                    results.innerHTML = '<div class="loading">Searching...</div>';
                    _context27.p = 2;
                    _context27.n = 3;
                    return api(`/search.json?q=${encodeURIComponent(query)}`);
                  case 3:
                    _d4 = _context27.v;
                    mergeCategories(_d4.categories || _d4.topic_list && _d4.topic_list.categories || []);
                    rhtml = '';
                    topics = _d4.topics || [];
                    users = _d4.users || [];
                    if (users.length) {
                      rhtml += '<h3 style="padding:8px 12px;font-size:.9rem;color:var(--fg2)">Users</h3>';
                      rhtml += users.map(function (u) {
                        return `
          <a class="list-item" href="${userHref(u.username)}" tabindex="0">
            <div class="item-title">@${esc(u.username)}</div>
            ${u.name ? `<div class="item-meta">${esc(u.name)}</div>` : ''}
          </a>`;
                      }).join('');
                    }
                    if (topics.length) {
                      rhtml += '<h3 style="padding:8px 12px;font-size:.9rem;color:var(--fg2)">Topics</h3>';
                      rhtml += topics.map(function (t) {
                        return `
          <a class="list-item" href="${topicHref(t.id, t.slug)}" tabindex="0">
            <div class="item-title">${escEmoji(t.title)}</div>
            <div class="item-meta">${catBadge(t.category_id)}<span>${timeAgo(t.created_at)}</span></div>
          </a>`;
                      }).join('');
                    }
                    if (!rhtml) rhtml = '<div class="empty">No results found</div>';
                    results.innerHTML = rhtml;
                    _context27.n = 5;
                    break;
                  case 4:
                    _context27.p = 4;
                    _t25 = _context27.v;
                    results.innerHTML = '';
                    showAlert(_t25.message);
                  case 5:
                    return _context27.a(2);
                }
              }, _callee27, null, [[2, 4]]);
            }));
            return function doSearch() {
              return _ref17.apply(this, arguments);
            };
          }();
          document.getElementById('searchGo').addEventListener('click', doSearch);
          document.getElementById('searchInput').addEventListener('keydown', function (e) {
            if (e.key === 'Enter') doSearch();
          });
          document.getElementById('searchInput').focus();
          if (q) doSearch();
        case 1:
          return _context28.a(2);
      }
    }, _callee28);
  }));
  return _renderSearch.apply(this, arguments);
}
(function () {
  var startY = 0,
    pulling = false,
    ptr = null;
  function ensurePtr() {
    ptr = document.getElementById('ptr');
    if (!ptr) {
      ptr = document.createElement('div');
      ptr.id = 'ptr';
      ptr.textContent = 'Pull to refresh';
      $app.parentNode.insertBefore(ptr, $app);
    }
    return ptr;
  }
  document.addEventListener('touchstart', function (e) {
    if (window.scrollY === 0 && isLoggedIn() && !parseTopicPath(currentPath())) {
      startY = e.touches[0].clientY;
      pulling = true;
      ensurePtr();
    }
  }, {
    passive: true
  });
  document.addEventListener('touchmove', function (e) {
    if (!pulling) return;
    var dy = e.touches[0].clientY - startY;
    if (dy > 10 && dy < 150 && window.scrollY === 0) {
      ptr.classList.add('visible');
      ptr.textContent = dy > 70 ? 'Release to refresh' : 'Pull to refresh';
    } else if (dy <= 0) {
      ptr.classList.remove('visible');
      pulling = false;
    }
  }, {
    passive: true
  });
  document.addEventListener('touchend', /*#__PURE__*/function () {
    var _ref11 = _asyncToGenerator(/*#__PURE__*/_regenerator().m(function _callee11(e) {
      var dy, _t12;
      return _regenerator().w(function (_context11) {
        while (1) switch (_context11.p = _context11.n) {
          case 0:
            if (!(!pulling || !ptr)) {
              _context11.n = 1;
              break;
            }
            pulling = false;
            return _context11.a(2);
          case 1:
            dy = (e.changedTouches[0] && e.changedTouches[0].clientY || 0) - startY;
            if (!(dy > 70 && ptr.classList.contains('visible'))) {
              _context11.n = 5;
              break;
            }
            ptr.textContent = 'Refreshing...';
            ptr.classList.add('refreshing');
            _context11.p = 2;
            _context11.n = 3;
            return softRefresh();
          case 3:
            _context11.n = 5;
            break;
          case 4:
            _context11.p = 4;
            _t12 = _context11.v;
          case 5:
            if (ptr.classList.contains('refreshing')) {
              setTimeout(function () {
                ptr.classList.remove('visible', 'refreshing');
              }, 450);
            } else {
              ptr.classList.remove('visible', 'refreshing');
            }
            pulling = false;
          case 6:
            return _context11.a(2);
        }
      }, _callee11, null, [[2, 4]]);
    }));
    return function (_x5) {
      return _ref11.apply(this, arguments);
    };
  }(), {
    passive: true
  });
})();
function isElVisible(el) {
  return el.offsetParent !== null || el.offsetWidth > 0 || el.getBoundingClientRect().width > 0;
}
function getFocusables() {
  var sel = 'a[tabindex="0"],button:not(:disabled),[tabindex="0"],input,textarea,select';
  var overlay = document.querySelector('.confirm-overlay');
  if (overlay) {
    var overlayEls = [].slice.call(overlay.querySelectorAll(sel));
    return overlayEls.filter(function (el) {
      return isElVisible(el) && el.getAttribute('tabindex') !== '-1';
    });
  }
  if ($view && $view.classList.contains('open')) {
    var viewEls = [].slice.call($view.querySelectorAll('a,button'));
    return viewEls.filter(function (el) {
      return isElVisible(el) && el.getAttribute('tabindex') !== '-1';
    });
  }
  if ($menu && $menu.classList.contains('open')) {
    var menuEls = [].slice.call($menu.querySelectorAll('a,button'));
    return menuEls.filter(function (el) {
      return isElVisible(el) && el.getAttribute('tabindex') !== '-1';
    });
  }
  var all = [].slice.call(document.getElementById('topbar').querySelectorAll(sel)).concat([].slice.call($app.querySelectorAll(sel)));
  return all.filter(function (el) {
    return isElVisible(el) && el.getAttribute('tabindex') !== '-1';
  });
}
document.addEventListener('keydown', function (e) {
  var tag = document.activeElement && document.activeElement.tagName;
  var inInput = tag === 'INPUT' || tag === 'TEXTAREA' || tag === 'SELECT';
  if ((e.key === 'Enter' || e.key === ' ') && tag === 'DIV' && document.activeElement.hasAttribute('tabindex')) {
    e.preventDefault();
    document.activeElement.click();
    return;
  }
  if ((e.key === 'ArrowDown' || e.key === 'ArrowUp') && inInput) {
    var el = document.activeElement;
    if (tag === 'SELECT') return;
    if (tag === 'TEXTAREA') {
      if (e.key === 'ArrowDown' && el.selectionStart < el.value.length) return;
      if (e.key === 'ArrowUp' && el.selectionStart > 0) return;
    }
  }
  var isDown = e.key === 'ArrowDown' || e.key === 'ArrowRight';
  var isUp = e.key === 'ArrowUp' || e.key === 'ArrowLeft';
  if ((e.key === 'ArrowLeft' || e.key === 'ArrowRight') && inInput) return;
  if (isDown || isUp) {
    var els = getFocusables();
    if (!els.length) return;
    var idx = els.indexOf(document.activeElement);
    var next;
    if (isDown) {
      next = idx < 0 ? 0 : Math.min(idx + 1, els.length - 1);
    } else {
      next = idx < 0 ? 0 : Math.max(idx - 1, 0);
    }
    els[next].focus();
    e.preventDefault();
  }
});
document.addEventListener('focusin', function () {
  if (document.activeElement && document.activeElement !== document.body) {
    requestAnimationFrame(function () {
      var el = document.activeElement;
      var menuContainer = el.closest && el.closest('.menu-drop.open');
      if (menuContainer) {
        var cTop = menuContainer.scrollTop;
        var cHeight = menuContainer.clientHeight;
        var eTop = el.offsetTop;
        var eBottom = eTop + el.offsetHeight;
        if (eTop < cTop) menuContainer.scrollTop = eTop;
        else if (eBottom > cTop + cHeight) menuContainer.scrollTop = eBottom - cHeight;
        return;
      }
      var rect = el.getBoundingClientRect();
      var topH = document.getElementById('topbar').offsetHeight;
      var vh = window.innerHeight;
      var topLimit = topH + 6;
      var bottomLimit = vh - 6;
      if (rect.height > vh - topLimit - 6) {
        window.scrollBy(0, rect.top - topLimit);
        return;
      }
      if (rect.top < topLimit) {
        window.scrollBy(0, rect.top - topLimit);
      } else if (rect.bottom > bottomLimit) {
        window.scrollBy(0, rect.bottom - bottomLimit);
      }
    });
  }
});
function activatePost(post, skipFocus) {
  document.querySelectorAll('.post.active').forEach(function (p) {
    return deactivatePost(p);
  });
  post.classList.add('active');
  post.querySelectorAll('.post-actions button').forEach(function (b) {
    return b.setAttribute('tabindex', '0');
  });
  post.querySelectorAll('.post-reactions button').forEach(function (b) {
    return b.setAttribute('tabindex', '0');
  });
  post.querySelectorAll('.post-reply-link').forEach(function (b) {
    return b.setAttribute('tabindex', '0');
  });
  post.querySelectorAll('.post-author, .post-avatar-link').forEach(function (a) {
    return a.setAttribute('tabindex', '0');
  });
  setPostBodyTabindex(post, true);
  if (!skipFocus) {
    var first = post.querySelector('.post-reactions button') || post.querySelector('.post-actions button') || post.querySelector('.post-body a, .post-body button, .post-body input, .post-body textarea, .post-body select, .post-body summary, .post-body .spoiler, .post-body .spoiler-blurred, .post-body .poll-option, .post-body img, .post-body iframe, .post-body video, .post-body audio');
    if (first) first.focus();
  }
}
function deactivatePost(post) {
  post.classList.remove('active');
  post.querySelectorAll('.post-actions button').forEach(function (b) {
    return b.setAttribute('tabindex', '-1');
  });
  post.querySelectorAll('.post-reactions button').forEach(function (b) {
    return b.setAttribute('tabindex', '-1');
  });
  post.querySelectorAll('.post-reply-link').forEach(function (b) {
    return b.setAttribute('tabindex', '-1');
  });
  post.querySelectorAll('.post-author, .post-avatar-link').forEach(function (a) {
    return a.setAttribute('tabindex', '-1');
  });
  setPostBodyTabindex(post, false);
}
document.addEventListener('click', function (e) {
  var post = e.target.closest('.post');
  if (!post) return;
  var isActive = post.classList.contains('active');
  var inActions = e.target.closest('.post-actions') || e.target.closest('.post-reactions') || e.target.closest('.post-reply-link');
  if (!isActive) {
    if (inActions) {
      activatePost(post, true);
      // Defer focus check — btn.disabled in action handlers may not
      // have moved focus to body yet on some browsers
      requestAnimationFrame(function() {
        if (!document.activeElement || document.activeElement === document.body || document.activeElement === document.documentElement) {
          post.focus();
        }
      });
    } else {
      if (e.target.closest('.post-author, .post-avatar-link, .post-body a, .post-body button, .post-body input, .post-body textarea, .post-body select, .post-body summary, .post-body details, .post-body .poll, .post-body .poll-option, .post-body .spoiler, .post-body .spoiler-blurred, .post-body img, .post-body iframe, .post-body video, .post-body audio')) {
        e.preventDefault();
        e.stopPropagation();
      }
      activatePost(post);
    }
    return;
  }
  if (inActions) return;
  if (e.target.closest('.post-author, .post-avatar-link, .post-body a, .post-body button, .post-body input, .post-body textarea, .post-body select, .post-body summary, .post-body details, .post-body .poll, .post-body .poll-option, .post-body .spoiler, .post-body .spoiler-blurred, .post-body img, .post-body iframe, .post-body video, .post-body audio')) return;
  deactivatePost(post);
  post.focus();
});
function focusContent() {
  requestAnimationFrame(function () {
    var el = $app.querySelector('a,button:not(:disabled),[tabindex="0"]');
    if (el) el.focus();
  });
}
function init() {
  if (location.hash && location.hash.indexOf('#/') === 0) {
    var p = location.hash.slice(1);
    var url = makeUrl(p);
    if (history && history.replaceState) history.replaceState(null, '', url);else location.href = url;
  }
  var tasks = [loadSite(), loadManifest(), loadEmojiMap(), loadCategories()];
  Promise.all(tasks.map(function (t) {
    return t && t.catch ? t.catch(function () {}) : Promise.resolve();
  })).then(function () {
    return checkSession();
  }).then(function (loggedIn) {
    // Register push notifications if logged in and in native app (fire and forget)
    if (loggedIn && isNativeApp()) {
      registerPushNotifications().catch(function () {});
    }
    if (loggedIn) {
      refreshUnreadMessageCount();
      refreshUnreadNotifCount();
      registerWebPushBadges();
    }
    route();
  });
}
init();
// Refresh badges when user returns to the app/tab
document.addEventListener('visibilitychange', function () {
  if (!document.hidden && isLoggedIn()) {
    refreshUnreadNotifCount();
    refreshUnreadMessageCount();
  }
});
