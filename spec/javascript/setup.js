/**
 * Jest Test Setup
 * Provides mocks for Service Worker APIs
 */

// Mock Cache API
global.caches = {
  open: jest.fn(),
  match: jest.fn(),
  keys: jest.fn(),
  delete: jest.fn()
};

// Mock Cache object
const createMockCache = () => ({
  match: jest.fn(),
  matchAll: jest.fn(),
  add: jest.fn(),
  addAll: jest.fn(),
  put: jest.fn(),
  delete: jest.fn(),
  keys: jest.fn()
});

// Helper to set up cache mock
global.setupCacheMock = () => {
  const mockCache = createMockCache();
  global.caches.open.mockResolvedValue(mockCache);
  return mockCache;
};

// Mock self (ServiceWorkerGlobalScope)
global.self = {
  skipWaiting: jest.fn().mockResolvedValue(),
  clients: {
    claim: jest.fn().mockResolvedValue()
  },
  location: {
    origin: 'http://localhost:3000'
  }
};

// Mock fetch
global.fetch = jest.fn();

// Mock console methods to reduce noise in tests
global.console = {
  ...console,
  log: jest.fn(),
  warn: jest.fn(),
  error: jest.fn()
};

// Mock Response class
global.Response = class Response {
  constructor(body, init = {}) {
    this.body = body;
    this.status = init.status || 200;
    this.statusText = init.statusText || 'OK';
    this.headers = new Map(Object.entries(init.headers || {}));
    this.type = init.type || 'basic';
    this.ok = this.status >= 200 && this.status < 300;
  }

  clone() {
    return new Response(this.body, {
      status: this.status,
      statusText: this.statusText,
      headers: Object.fromEntries(this.headers),
      type: this.type
    });
  }

  async json() {
    return JSON.parse(this.body);
  }

  async text() {
    return this.body;
  }
};

// Mock Request class
global.Request = class Request {
  constructor(url, init = {}) {
    this.url = url;
    this.method = init.method || 'GET';
    this.headers = new Map(Object.entries(init.headers || {}));
    this.mode = init.mode || 'cors';
    this.signal = init.signal;
  }

  clone() {
    return new Request(this.url, {
      method: this.method,
      headers: Object.fromEntries(this.headers),
      mode: this.mode
    });
  }
};

// Mock AbortController
global.AbortController = class AbortController {
  constructor() {
    this.signal = { aborted: false };
    this.abortHandlers = [];
  }

  abort() {
    this.signal.aborted = true;
    this.abortHandlers.forEach(handler => handler());
  }
};

// Helper to create mock responses
global.createMockResponse = (body, options = {}) => {
  return new Response(
    typeof body === 'string' ? body : JSON.stringify(body),
    {
      status: options.status || 200,
      statusText: options.statusText || 'OK',
      headers: options.headers || { 'Content-Type': 'application/json' },
      type: options.type || 'basic'
    }
  );
};

// Helper to create mock requests
global.createMockRequest = (url, options = {}) => {
  return new Request(url, {
    method: options.method || 'GET',
    headers: options.headers || {},
    mode: options.mode || 'cors'
  });
};

// Reset all mocks before each test
beforeEach(() => {
  jest.clearAllMocks();

  // Reset cache mocks
  if (global.caches) {
    global.caches.open = jest.fn();
    global.caches.match = jest.fn();
    global.caches.keys = jest.fn();
    global.caches.delete = jest.fn();
  }

  // Reset fetch mock
  if (global.fetch) {
    global.fetch = jest.fn();
  }

  // Reset self mocks
  if (global.self) {
    global.self.skipWaiting = jest.fn().mockResolvedValue();
    global.self.clients = {
      claim: jest.fn().mockResolvedValue()
    };
  }
});
