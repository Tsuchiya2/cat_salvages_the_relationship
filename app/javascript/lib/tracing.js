/**
 * Tracing - Distributed Tracing Support
 * Generates and propagates trace IDs for request correlation
 */

// Current trace ID stored in closure
let currentTraceId = null;

/**
 * Generate a new UUID v4 trace ID
 * Uses crypto.randomUUID() if available, otherwise fallback
 * @returns {string} UUID v4 string
 */
export function generateTraceId() {
  // Modern browsers support crypto.randomUUID()
  if (typeof crypto !== 'undefined' && crypto.randomUUID) {
    return crypto.randomUUID();
  }

  // Fallback for older browsers
  return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, (c) => {
    const r = Math.random() * 16 | 0;
    const v = c === 'x' ? r : (r & 0x3 | 0x8);
    return v.toString(16);
  });
}

/**
 * Get the current trace ID
 * Generates a new one if not set
 * @returns {string} Current trace ID
 */
export function getCurrentTraceId() {
  if (!currentTraceId) {
    currentTraceId = generateTraceId();
  }
  return currentTraceId;
}

/**
 * Set the trace ID for the current context
 * @param {string} traceId - The trace ID to set
 */
export function setTraceId(traceId) {
  currentTraceId = traceId;
}

/**
 * Clear the current trace ID
 */
export function clearTraceId() {
  currentTraceId = null;
}

/**
 * Execute a function within a trace context
 * Creates a new trace ID for the duration of the function
 * @param {Function} fn - Function to execute
 * @param {string} [traceId] - Optional trace ID (generates new one if not provided)
 * @returns {*} Result of the function
 */
export function withTrace(fn, traceId = null) {
  const previousTraceId = currentTraceId;
  currentTraceId = traceId || generateTraceId();

  try {
    return fn();
  } finally {
    currentTraceId = previousTraceId;
  }
}

/**
 * Execute an async function within a trace context
 * @param {Function} fn - Async function to execute
 * @param {string} [traceId] - Optional trace ID
 * @returns {Promise<*>} Result of the async function
 */
export async function withTraceAsync(fn, traceId = null) {
  const previousTraceId = currentTraceId;
  currentTraceId = traceId || generateTraceId();

  try {
    return await fn();
  } finally {
    currentTraceId = previousTraceId;
  }
}

/**
 * Create headers object with trace ID for fetch requests
 * @param {Object} [existingHeaders={}] - Existing headers to merge with
 * @returns {Object} Headers with X-Trace-Id
 */
export function getTraceHeaders(existingHeaders = {}) {
  return {
    ...existingHeaders,
    'X-Trace-Id': getCurrentTraceId()
  };
}

/**
 * Wrap fetch to automatically include trace headers
 * @param {string|Request} input - Fetch input
 * @param {Object} [init={}] - Fetch init options
 * @returns {Promise<Response>} Fetch response
 */
export function tracedFetch(input, init = {}) {
  const headers = getTraceHeaders(init.headers || {});
  return fetch(input, { ...init, headers });
}
