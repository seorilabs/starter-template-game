// 실제 AppsInToss SDK 연결은 제품 어댑터를 등록한 뒤 활성화한다.
export function installHost(handlers, target = globalThis) {
  const supported = new Set(['leaderboard', 'analyticsPreference', 'supportCode']);
  target.SeorilabsHost = Object.freeze({
    request(operation, serialized) {
      if (!supported.has(operation) || typeof handlers[operation] !== 'function') return false;
      const payload = JSON.parse(serialized);
      handlers[operation](payload);
      return true;
    },
  });
  return () => { delete target.SeorilabsHost; };
}
