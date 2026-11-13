self.addEventListener("push", (event) => {
  let payload = {};
  if (event.data) {
    try {
      payload = event.data.json();
    } catch (error) {
      payload = { body: event.data.text() };
    }
  }
  event.waitUntil(
    self.registration.showNotification(payload.title || "Haidware staff", {
      body: payload.body || "A new update is waiting in your staff inbox.",
      icon: "/icons/Icon-192.png",
      tag: payload.tag || "haidware-staff-update",
      data: { url: payload.url || "/ordernotification" },
    }),
  );
});

self.addEventListener("notificationclick", (event) => {
  event.notification.close();
  const target = new URL(
    event.notification.data.url || "/ordernotification",
    self.location.origin,
  ).href;
  event.waitUntil(
    self.clients.matchAll({ type: "window", includeUncontrolled: true }).then((clients) => {
      for (const client of clients) {
        if (client.url === target && "focus" in client) {
          return client.focus();
        }
      }
      return self.clients.openWindow(target);
    }),
  );
});
