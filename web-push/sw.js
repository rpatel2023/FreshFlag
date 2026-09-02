self.addEventListener('push', (event) => {
  let payload = {};
  try {
    payload = event.data?.json() ?? {};
  } catch {
    payload = {body: event.data?.text() ?? ''};
  }

  const title = typeof payload.title === 'string' && payload.title.trim() !== ''
    ? payload.title
    : 'Fresh Flag reminder';
  const body = typeof payload.body === 'string' ? payload.body : '';
  const tag = typeof payload.tag === 'string' ? payload.tag : undefined;
  const data = typeof payload.data === 'object' && payload.data != null
    ? payload.data
    : {};

  event.waitUntil(self.registration.showNotification(title, {
    body,
    tag,
    icon: '/icon.svg',
    badge: '/icon.svg',
    data,
  }));
});

self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  event.waitUntil((async () => {
    const windows = await clients.matchAll({type: 'window', includeUncontrolled: true});
    for (const windowClient of windows) {
      if ('focus' in windowClient) return windowClient.focus();
    }
    return clients.openWindow('/');
  })());
});
