(() => {
  const app = document.getElementById("guest-app");
  const config = JSON.parse(document.getElementById("guest-config").textContent);
  const state = {
    screen: "loading",
    history: [],
    deviceId: config.device_id || "",
    propertyName: "",
    room: "",
    bank: {},
    items: [],
    services: [],
    requestingServiceId: null,
    serviceMessage: "",
    serviceError: "",
    whatsappMessages: [],
    department: "kitchen",
    category: "All",
    selectedItem: null,
    detailQuantity: 1,
    cart: new Map(),
    senderName: "",
    orderNumber: "",
    orderLines: [],
    submitting: false,
    error: "",
    submissionError: "",
  };

  const escapeHtml = (value) => String(value ?? "")
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#39;");
  const money = (value) => `N${Math.round(Number(value) || 0).toLocaleString("en-NG")}`;
  const timeLabel = (minutes) => `${Number(minutes) || 0} min`;
  const greeting = () => {
    const hour = new Date().getHours();
    if (hour < 12) return "Good morning";
    if (hour < 17) return "Good afternoon";
    return "Good evening";
  };
  const departmentIcon = (department) => {
    const icons = {
      kitchen: '<path d="M4 3v7a3 3 0 0 0 6 0V3M7 3v18m10-18v18m0-18c0 3 3 4 3 7v2h-3"/>',
      bar: '<path d="M3 4h18l-8 9v5l4 2H7l4-2V13L3 4Zm6 5h10"/>',
      services: '<path d="M18 9a6 6 0 0 0-12 0c0 7-3 7-3 9h18c0-2-3-2-3-9ZM10 22h4M12 2V1"/>',
    };
    return `<svg class="guest-category-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">${icons[department]}</svg>`;
  };
  const departmentCard = ({ category, number, title, description }) => `
    <button class="guest-department department-${category}" data-action="department" data-department="${category}">
      <span class="guest-department-top"><span>${number} / ${category === "services" ? "CONCIERGE" : category.toUpperCase()}</span><span class="guest-department-arrow">↗</span></span>
      <span class="guest-department-visual">${departmentIcon(category)}</span>
      <span class="guest-department-copy"><strong>${title}</strong><span>${description}</span></span>
    </button>`;
  const cartLines = () => state.items
    .filter((item) => state.cart.has(String(item.id)))
    .map((item) => ({ item, quantity: state.cart.get(String(item.id)) }));
  const cartCount = () => [...state.cart.values()].reduce((sum, quantity) => sum + quantity, 0);
  const total = () => cartLines().reduce((sum, line) => sum + Number(line.item.price) * line.quantity, 0);
  const art = (index = 0, imageUrl = "", alt = "") => imageUrl
    ? `<div class="guest-food-art guest-food-image"><img src="${escapeHtml(imageUrl)}" alt="${escapeHtml(alt)}" loading="lazy"></div>`
    : `<div class="guest-food-art variant-${index % 3}" data-art="${index % 2 ? "◉" : "≋"}" aria-hidden="true"></div>`;
  const badge = () => `<span class="guest-badge">${cartCount()}</span>`;
  const panelHeader = (title, trailing = "") => `
    <header class="guest-page-header">
      <button class="guest-back" data-action="back" aria-label="Go back">‹</button>
      <h1>${escapeHtml(title)}</h1>
      ${trailing}
    </header>`;
  const cartButton = () => `<button class="guest-icon-button" data-action="cart" aria-label="Open cart">🛒${badge()}</button>`;
  const button = (label, action, extra = "") => `<button class="guest-primary guest-full" data-action="${action}" ${extra}>${escapeHtml(label)}</button>`;

  function navigate(screen) {
    state.history.push(state.screen);
    state.screen = screen;
    state.submissionError = "";
    render();
    window.scrollTo(0, 0);
  }

  function goBack() {
    state.screen = state.history.pop() || "home";
    state.submissionError = "";
    render();
  }

  function totalRows() {
    return `<div class="guest-totals">
      <div class="guest-total-row grand"><span>Total</span><strong>${money(total())}</strong></div>
    </div>`;
  }

  function renderHome() {
    const cards = [
      departmentCard({
        category: "kitchen",
        number: "01",
        title: "Kitchen",
        description: "Thoughtfully prepared dining",
      }),
      departmentCard({
        category: "bar",
        number: "02",
        title: "Bar",
        description: "Signature drinks & moments",
      }),
      departmentCard({
        category: "services",
        number: "03",
        title: "Guest Services",
        description: "Considered care, on request",
      }),
    ];
    return `<section class="guest-screen">
      <header class="guest-topbar">
        <span class="guest-location"><span class="guest-property-name">${escapeHtml(state.propertyName || "HAIDWARE HOSPITALITY")}</span><span>${escapeHtml(state.room || "Your location")}</span></span>
        <span class="guest-tools">${cartButton()}</span>
      </header>
      <div class="guest-home-intro"><p class="guest-eyebrow">A STAY, BEAUTIFULLY SERVED</p><h1 class="guest-greeting">${greeting()} 👋</h1><p class="guest-subtitle">How may we make your experience exceptional?</p></div>
      <div class="guest-departments">${cards.join("")}</div>
      <p class="guest-home-footnote"><span></span> Your comfort is our priority</p>
    </section>`;
  }

  function renderMenu() {
    const filtered = state.items.filter((item) => item.department === state.department);
    const categories = ["All", ...new Set(filtered.map((item) => item.category || "Other"))];
    const visible = state.category === "All"
      ? filtered
      : filtered.filter((item) => (item.category || "Other") === state.category);
    return `<section class="guest-screen">
      ${panelHeader(state.department === "bar" ? "Bar" : "Kitchen", cartButton())}
      <nav class="guest-categories" aria-label="Menu categories">
        ${categories.map((category) => `<button class="guest-chip ${category === state.category ? "active" : ""}" data-action="category" data-category="${escapeHtml(category)}">${escapeHtml(category)}</button>`).join("")}
      </nav>
      ${visible.length ? `<div class="guest-items">${visible.map((item, index) => `<button class="guest-item" data-action="item" data-item-id="${escapeHtml(item.id)}">
        ${art(index, item.image_url, item.name)}
        <span class="guest-item-copy"><strong class="guest-item-name">${escapeHtml(item.name)}</strong><span class="guest-item-description">${escapeHtml(item.description || "")}</span>
          <span class="guest-item-bottom"><strong class="guest-price">${money(item.price)}</strong><span class="guest-add" aria-hidden="true">+</span></span>
        </span>
      </button>`).join("")}</div>` : `<div class="guest-center">No items in this category yet.</div>`}
    </section>`;
  }

  function renderDetail() {
    const item = state.selectedItem;
    return `<section class="guest-screen">
      ${panelHeader("Item Detail")}
      <div class="guest-detail">
        ${art(state.items.indexOf(item), item.image_url, item.name)}
        <div class="guest-detail-copy">
          <h2>${escapeHtml(item.name)}</h2>
          <p>${escapeHtml(item.description || "")}</p>
          <div class="guest-detail-price">${money(item.price)}</div>
          <div class="guest-stepper">
            <button data-action="detail-quantity" data-change="-1" aria-label="Decrease quantity">−</button>
            <span>${state.detailQuantity}</span>
            <button data-action="detail-quantity" data-change="1" aria-label="Increase quantity" ${state.detailQuantity >= 50 ? "disabled" : ""}>+</button>
          </div>
        </div>
      </div>
      <div class="guest-estimate"><span>◷ &nbsp;Estimated order time</span><strong>${timeLabel(item.preparation_minutes)}</strong></div>
      ${button("Add to Cart", "add-to-cart")}
    </section>`;
  }

  function renderCart() {
    const lines = cartLines();
    return `<section class="guest-screen">
      ${panelHeader("Your Cart")}
      ${lines.length ? `<div class="guest-cart-list">${lines.map((line, index) => `<div class="guest-cart-line">
        ${art(index, line.item.image_url, line.item.name)}
        <span><strong>${escapeHtml(line.item.name)}</strong><small>${money(line.item.price)}</small></span>
        <span class="guest-stepper">
          <button data-action="cart-quantity" data-item-id="${escapeHtml(line.item.id)}" data-change="-1" aria-label="Decrease quantity">−</button>
          <span>${line.quantity}</span>
          <button data-action="cart-quantity" data-item-id="${escapeHtml(line.item.id)}" data-change="1" aria-label="Increase quantity" ${line.quantity >= 50 ? "disabled" : ""}>+</button>
        </span>
      </div>`).join("")}</div>
      ${totalRows()}${button("Proceed to Checkout", "checkout")}`
      : `<div class="guest-center"><p class="guest-empty-title">Your cart is empty</p><span>Browse the menu to add something delicious.</span><button class="guest-primary" data-action="back">Browse Menu</button></div>`}
    </section>`;
  }

  function renderCheckout() {
    return `<section class="guest-screen guest-stack">
      ${panelHeader("Checkout")}
      <p class="guest-section-label">Please make payment to:</p>
      <div class="guest-panel guest-bank">
        <div class="guest-bank-row"><span>Bank</span><strong>${escapeHtml(state.bank.bank_name || "Not configured")}</strong></div>
        <div class="guest-bank-row"><span>Account Name</span><strong>${escapeHtml(state.bank.account_name || "Not configured")}</strong></div>
        <div class="guest-bank-row"><span>Account Number</span><strong>${escapeHtml(state.bank.account_number || "Not configured")}</strong></div>
      </div>
      <p class="guest-note">Use the sender name shown on your bank transfer.</p>
      <form id="sender-form" class="guest-stack">
        <label class="guest-section-label" for="sender-name">Name on bank transfer</label>
        <input class="guest-input" id="sender-name" name="sender_name" autocomplete="name" required maxlength="120" placeholder="Enter sender name" value="${escapeHtml(state.senderName)}">
        ${totalRows()}
        <button class="guest-primary guest-full" type="submit">I have paid&nbsp; →</button>
      </form>
    </section>`;
  }

  function renderPaymentPreview() {
    const message = `Hello Reception,\n\nI have completed a bank transfer.\nOrder: Assigned when order is confirmed\nDevice ID Number: ${state.deviceId}\nName on bank transfer: ${state.senderName}\nAmount: ${money(total())}\n\nPlease confirm receipt of payment.`;
    return `<section class="guest-screen guest-stack">
      ${panelHeader("Confirm Order")}
      <h2 class="guest-section-label">Payment message preview</h2>
      <div class="guest-panel guest-payment-message">${escapeHtml(message)}</div>
      <p class="guest-note">Generated message preview. This is not sent automatically.</p>
      ${state.submissionError ? `<p class="guest-error" role="alert">${escapeHtml(state.submissionError)}</p>` : ""}
      ${button(state.submitting ? "Submitting…" : "Confirm Order", "confirm-order", state.submitting ? "disabled" : "")}
    </section>`;
  }

  function renderConfirmation() {
    const messages = state.whatsappMessages.map((message) => `
      <article class="guest-whatsapp-message">
        <span><strong>${escapeHtml(message.department)}</strong>${message.staff_name ? `<small>Assigned to ${escapeHtml(message.staff_name)}</small>` : ""}</span>
        ${message.whatsapp_url
          ? `<a class="guest-whatsapp-button" href="${escapeHtml(message.whatsapp_url)}" target="_blank" rel="noopener noreferrer"><span aria-hidden="true">↗</span> Open WhatsApp</a>`
          : `<small class="guest-whatsapp-status">${escapeHtml(message.detail || "No WhatsApp contact is assigned.")}</small>`}
      </article>`).join("");
    return `<section class="guest-screen guest-stack guest-confirm">
      <div class="guest-check" aria-hidden="true">✓</div>
      <h1 class="guest-thanks">Thank You!</h1>
      <p class="guest-subtitle">Your order will be confirmed shortly.</p>
      <span class="guest-section-label">Order Number</span>
      <strong class="guest-order-number">${escapeHtml(state.orderNumber)}</strong>
      <p class="guest-note">Please expect your order within the estimated time below.</p>
      <div class="guest-panel guest-confirm-lines">
        ${state.orderLines.map((line) => `<div class="guest-confirm-line"><span>${escapeHtml(line.name)} × ${Number(line.quantity) || 0}</span><strong>${timeLabel(line.preparation_minutes)}</strong></div>`).join("")}
      </div>
      <section class="guest-whatsapp-panel">
        <div><h2>Send your payment message</h2><p>Open WhatsApp and tap Send to notify your assigned team. Messages are not sent automatically.</p></div>
        ${messages || `<p class="guest-whatsapp-status">No WhatsApp staff contact is configured. Please contact reception to confirm your payment.</p>`}
      </section>
      ${button("Back to Home", "home")}
    </section>`;
  }

  function renderServices() {
    return `<section class="guest-screen guest-stack">
      ${panelHeader("Guest Services")}
      <p class="guest-services-intro">A little extra care, whenever you need it.</p>
      <div class="guest-services-list">
        ${state.services.length ? state.services.map((service) => `
          <article class="guest-service-card">
            ${departmentIcon("services")}
            <span><strong>${escapeHtml(service.name)}</strong><small>${escapeHtml(service.description || service.department)}</small></span>
            <button class="guest-service-request" data-action="request-service" data-service-id="${Number(service.id)}" ${state.requestingServiceId !== null ? "disabled" : ""}>${state.requestingServiceId === service.id ? "Requesting…" : "Request"}</button>
          </article>`).join("") : `<div class="guest-center">No guest services are available right now.</div>`}
      </div>
      ${state.serviceError ? `<p class="guest-error" role="alert">${escapeHtml(state.serviceError)}</p>` : ""}
      ${state.serviceMessage ? `<p class="guest-service-success" role="status">${escapeHtml(state.serviceMessage)}</p>` : ""}
    </section>`;
  }

  function renderStatus() {
    if (state.screen === "loading") {
      return `<section class="guest-screen"><div class="guest-center"><span class="guest-spinner"></span><strong>Opening ${escapeHtml(state.room || "your location")}…</strong><span>Loading the available menu</span></div></section>`;
    }
    return `<section class="guest-screen"><div class="guest-center"><strong class="guest-empty-title">Unable to open this location</strong><span>${escapeHtml(state.error)}</span><button class="guest-primary" data-action="retry">Try Again</button></div></section>`;
  }

  function render() {
    const screens = {
      loading: renderStatus,
      error: renderStatus,
      home: renderHome,
      services: renderServices,
      menu: renderMenu,
      detail: renderDetail,
      cart: renderCart,
      checkout: renderCheckout,
      payment: renderPaymentPreview,
      confirmation: renderConfirmation,
    };
    app.innerHTML = (screens[state.screen] || renderHome)();
  }

  async function requestJson(url, options) {
    const response = await fetch(url, options);
    let data;
    try {
      data = await response.json();
    } catch {
      throw new Error("The ordering service returned an invalid response.");
    }
    if (!response.ok) throw new Error(data.error || `Request failed (${response.status}).`);
    return data;
  }

  async function connect() {
    state.screen = "loading";
    state.error = "";
    render();
    if (!/^\d{4,12}$/.test(state.deviceId)) {
      state.error = "This QR code does not contain a valid room or table ID.";
      state.screen = "error";
      render();
      return;
    }
    try {
      const session = await requestJson(config.session_url, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ device_id: state.deviceId }),
      });
      state.room = session.room || session.device_name || "HAIDWARE";
      state.propertyName = session.property?.name || "";
      state.bank = session.payment_details || {};
      const menu = await requestJson(config.menu_url, {
        headers: { "X-Device-ID": state.deviceId },
      });
      const services = await requestJson(config.services_url, {
        headers: { "X-Device-ID": state.deviceId },
      });
      if (!Array.isArray(menu.items)) throw new Error("The portal returned an invalid menu.");
      if (!Array.isArray(services.services)) throw new Error("The portal returned an invalid services list.");
      state.items = menu.items.filter((item) =>
        item && Number.isInteger(item.id) && typeof item.name === "string" &&
        Number.isFinite(Number(item.price)) && Number.isInteger(item.preparation_minutes) &&
        (item.department === "kitchen" || item.department === "bar"));
      state.services = services.services.filter((service) =>
        service && Number.isInteger(service.id) && typeof service.name === "string");
      state.screen = "home";
      state.history = [];
      render();
    } catch (error) {
      state.error = error instanceof Error ? error.message : "Could not connect to the ordering portal.";
      state.screen = "error";
      render();
    }
  }

  async function submitOrder() {
    if (state.submitting || !cartLines().length) return;
    state.submitting = true;
    state.submissionError = "";
    render();
    try {
      const result = await requestJson(config.orders_url, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          device_id: state.deviceId,
          sender_name: state.senderName,
          expected_total: total().toFixed(2),
          items: cartLines().map((line) => ({
            item_id: Number(line.item.id),
            quantity: line.quantity,
          })),
        }),
      });
      if (typeof result.order_number !== "string" || !Array.isArray(result.items)) {
        throw new Error("The portal returned an invalid order confirmation.");
      }
      state.orderNumber = result.order_number;
      state.orderLines = result.items;
      state.whatsappMessages = Array.isArray(result.whatsapp_messages)
        ? result.whatsapp_messages
        : [];
      state.submitting = false;
      state.screen = "confirmation";
      state.history = [];
      render();
      window.scrollTo(0, 0);
    } catch (error) {
      state.submitting = false;
      state.submissionError = error instanceof Error ? error.message : "Could not submit the order.";
      render();
    }
  }

  async function requestService(serviceId) {
    state.requestingServiceId = serviceId;
    state.serviceError = "";
    state.serviceMessage = "";
    render();
    try {
      const result = await requestJson(config.service_requests_url, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ device_id: state.deviceId, service_id: serviceId }),
      });
      state.serviceMessage = `Your request is on its way · Ref ${result.request_id}`;
    } catch (error) {
      state.serviceError = error instanceof Error ? error.message : "Could not request this service.";
    } finally {
      state.requestingServiceId = null;
      render();
    }
  }

  app.addEventListener("click", (event) => {
    const target = event.target.closest("[data-action]");
    if (!target) return;
    const { action } = target.dataset;
    if (action === "back") return goBack();
    if (action === "cart") return navigate("cart");
    if (action === "retry") return connect();
    if (action === "department") {
      if (target.dataset.department === "services") return navigate("services");
      state.department = target.dataset.department;
      state.category = "All";
      return navigate("menu");
    }
    if (action === "request-service") return requestService(Number(target.dataset.serviceId));
    if (action === "category") {
      state.category = target.dataset.category;
      return render();
    }
    if (action === "item") {
      state.selectedItem = state.items.find((item) => String(item.id) === target.dataset.itemId);
      if (!state.selectedItem) return;
      state.detailQuantity = 1;
      return navigate("detail");
    }
    if (action === "detail-quantity") {
      state.detailQuantity = Math.max(1, Math.min(50, state.detailQuantity + Number(target.dataset.change)));
      return render();
    }
    if (action === "add-to-cart") {
      const id = String(state.selectedItem.id);
      state.cart.set(id, Math.min(50, (state.cart.get(id) || 0) + state.detailQuantity));
      return navigate("cart");
    }
    if (action === "cart-quantity") {
      const id = target.dataset.itemId;
      const next = (state.cart.get(id) || 0) + Number(target.dataset.change);
      if (next <= 0) state.cart.delete(id);
      else state.cart.set(id, Math.min(50, next));
      return render();
    }
    if (action === "checkout") {
      if (cartLines().length) navigate("checkout");
      return;
    }
    if (action === "confirm-order") return submitOrder();
    if (action === "home") {
      state.cart.clear();
      state.history = [];
      state.screen = "home";
      return render();
    }
  });

  app.addEventListener("submit", (event) => {
    if (event.target.id !== "sender-form") return;
    event.preventDefault();
    const form = new FormData(event.target);
    state.senderName = String(form.get("sender_name") || "").trim();
    if (!state.senderName) return;
    navigate("payment");
  });

  render();
  connect();
})();
