const menus = new Map();
const root = document.getElementById('menus');

function post(name, payload = {}) {
  fetch(`https://${GetParentResourceName()}/${name}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json; charset=UTF-8' },
    body: JSON.stringify(payload)
  }).catch(() => {});
}

function play() { post('playsound', {}); }
function keyOf(namespace, name) { return `${namespace}:${name}`; }

function clamp(value, min, max) {
  return Math.min(Math.max(value, min), max);
}

function getChildren(element) {
  return element && (element.children || element.options || element.items || element.menu || element.submenu || null);
}

function normalizeMenu(namespace, name, data) {
  const menu = {
    namespace,
    name,
    title: data.title || 'NODE7 MENU',
    subtext: data.subtext || data.subtitle || '',
    align: data.align || 'top-left',
    elements: Array.isArray(data.elements) ? data.elements : [],
    selected: Number.isInteger(data.selected) ? data.selected : 0,
    stack: []
  };
  menu.selected = clamp(menu.selected, 0, Math.max(menu.elements.length - 1, 0));
  return menu;
}

function currentElements(menu) {
  if (!menu.stack.length) return menu.elements;
  return menu.stack[menu.stack.length - 1].elements;
}

function currentTitle(menu) {
  if (!menu.stack.length) return menu.title;
  return menu.stack[menu.stack.length - 1].title || menu.title;
}

function currentSubtext(menu) {
  if (!menu.stack.length) return menu.subtext;
  return menu.stack[menu.stack.length - 1].subtext || menu.subtext;
}

function selectedElement(menu) {
  const elements = currentElements(menu);
  return elements[menu.selected] || null;
}

function buildPayload(menu) {
  const elements = currentElements(menu).map((element, index) => ({
    ...element,
    selected: index === menu.selected
  }));
  const current = elements[menu.selected] || {};
  return {
    _namespace: menu.namespace,
    _name: menu.name,
    current,
    elements
  };
}

function sliderPercent(element) {
  const min = Number(element.min ?? 0);
  const max = Number(element.max ?? 100);
  const value = Number(element.value ?? min);
  if (max <= min) return 0;
  return clamp(((value - min) / (max - min)) * 100, 0, 100);
}

function renderMenu(menu) {
  const id = keyOf(menu.namespace, menu.name);
  let el = document.getElementById(`menu-${CSS.escape(id)}`);
  if (!el) {
    el = document.createElement('section');
    el.id = `menu-${id}`;
    root.appendChild(el);
  }

  const elements = currentElements(menu);
  menu.selected = clamp(menu.selected, 0, Math.max(elements.length - 1, 0));
  const title = currentTitle(menu);
  const subtext = currentSubtext(menu);
  const align = menu.align || 'top-left';

  el.className = `node7-menu ${align}`;
  el.innerHTML = `
    <header class="menu-header">
      <div class="brand-row">
        <img src="assets/node7-mark.svg" alt="NODE7">
        <div class="brand-kicker">NODE7</div>
      </div>
      <h1 class="menu-title"></h1>
      <div class="menu-subtext"></div>
    </header>
    <div class="menu-list" role="menu"></div>
    <footer class="menu-footer">
      <span><span class="key">↑↓</span> Navigate</span>
      <span><span class="key">Enter</span> Select</span>
      <span><span class="key">Back</span> Close</span>
    </footer>
  `;

  el.querySelector('.menu-title').textContent = title;
  el.querySelector('.menu-subtext').textContent = subtext;
  const list = el.querySelector('.menu-list');

  if (!elements.length) {
    const empty = document.createElement('div');
    empty.className = 'menu-row selected';
    empty.innerHTML = '<div><div class="menu-label">No options available</div><div class="menu-desc">This menu opened without elements.</div></div>';
    list.appendChild(empty);
    return;
  }

  elements.forEach((element, index) => {
    const row = document.createElement('div');
    row.className = `menu-row ${index === menu.selected ? 'selected' : ''}`;
    row.setAttribute('role', 'menuitem');
    const left = document.createElement('div');
    const label = document.createElement('div');
    label.className = 'menu-label';
    label.textContent = element.label ?? element.title ?? String(element.value ?? 'Option');
    left.appendChild(label);
    if (element.desc || element.description) {
      const desc = document.createElement('div');
      desc.className = 'menu-desc';
      desc.textContent = element.desc || element.description;
      left.appendChild(desc);
    }
    row.appendChild(left);

    const children = getChildren(element);
    if (Array.isArray(children)) {
      const arrow = document.createElement('div');
      arrow.className = 'menu-arrow';
      arrow.textContent = '›';
      row.appendChild(arrow);
    } else if (element.type === 'slider') {
      const wrap = document.createElement('div');
      wrap.className = 'slider-wrap';
      const track = document.createElement('div');
      track.className = 'slider-track';
      const fill = document.createElement('div');
      fill.className = 'slider-fill';
      fill.style.width = `${sliderPercent(element)}%`;
      track.appendChild(fill);
      const val = document.createElement('div');
      val.className = 'slider-value';
      val.textContent = String(element.value ?? element.min ?? 0);
      wrap.appendChild(track);
      wrap.appendChild(val);
      row.appendChild(wrap);
    } else {
      const meta = document.createElement('div');
      meta.className = 'menu-meta';
      meta.textContent = element.rightLabel || element.badge || '';
      row.appendChild(meta);
    }

    row.addEventListener('mouseenter', () => {
      menu.selected = index;
      renderMenu(menu);
      post('menu_change', buildPayload(menu));
    });
    row.addEventListener('click', () => submit(menu));
    list.appendChild(row);
  });
}

function openMenu(namespace, name, data) {
  const menu = normalizeMenu(namespace, name, data || {});
  menus.set(keyOf(namespace, name), menu);
  renderMenu(menu);
}

function closeMenu(namespace, name) {
  const id = keyOf(namespace, name);
  menus.delete(id);
  const el = document.getElementById(`menu-${id}`);
  if (el) el.remove();
}

function topMenu() {
  const values = Array.from(menus.values());
  return values[values.length - 1] || null;
}

function change(menu, direction) {
  const elements = currentElements(menu);
  if (!elements.length) return;
  menu.selected = (menu.selected + direction + elements.length) % elements.length;
  renderMenu(menu);
  play();
  post('menu_change', buildPayload(menu));
}

function adjustSlider(menu, direction) {
  const element = selectedElement(menu);
  if (!element || element.type !== 'slider') return false;
  const min = Number(element.min ?? 0);
  const max = Number(element.max ?? 100);
  const hop = Number(element.hop ?? element.step ?? 1);
  const current = Number(element.value ?? min);
  element.value = clamp(current + direction * hop, min, max);
  renderMenu(menu);
  play();
  post('menu_change', buildPayload(menu));
  return true;
}

function submit(menu) {
  const element = selectedElement(menu);
  if (!element) return;
  const children = getChildren(element);
  if (Array.isArray(children)) {
    menu.stack.push({
      title: element.label || element.title || menu.title,
      subtext: element.desc || element.description || '',
      elements: children,
      previousSelected: menu.selected
    });
    menu.selected = 0;
    renderMenu(menu);
    play();
    post('menu_change', buildPayload(menu));
    return;
  }
  post('menu_submit', buildPayload(menu));
}

function back(menu) {
  if (menu.stack.length) {
    const old = menu.stack.pop();
    menu.selected = old.previousSelected || 0;
    renderMenu(menu);
    play();
    post('menu_change', buildPayload(menu));
    return;
  }
  post('menu_cancel', buildPayload(menu));
}

function handleControl(control) {
  const menu = topMenu();
  if (!menu) return;
  if (control === 'TOP') change(menu, -1);
  if (control === 'DOWN') change(menu, 1);
  if (control === 'LEFT') adjustSlider(menu, -1);
  if (control === 'RIGHT') adjustSlider(menu, 1);
  if (control === 'ENTER') submit(menu);
  if (control === 'BACKSPACE') back(menu);
}

window.addEventListener('message', (event) => {
  const data = event.data || {};
  if (data.ak_menubase_action === 'openMenu') {
    openMenu(data.ak_menubase_namespace, data.ak_menubase_name, data.ak_menubase_data);
  }
  if (data.ak_menubase_action === 'closeMenu') {
    closeMenu(data.ak_menubase_namespace, data.ak_menubase_name);
  }
  if (data.ak_menubase_action === 'forceClose') {
    menus.clear();
    root.innerHTML = '';
  }
  if (data.ak_menubase_action === 'controlPressed') {
    handleControl(data.ak_menubase_control);
  }
});

window.addEventListener('keydown', (event) => {
  const key = event.key.toLowerCase();
  if (key === 'arrowup' || key === 'w') { event.preventDefault(); handleControl('TOP'); }
  if (key === 'arrowdown' || key === 's') { event.preventDefault(); handleControl('DOWN'); }
  if (key === 'arrowleft' || key === 'a') { event.preventDefault(); handleControl('LEFT'); }
  if (key === 'arrowright' || key === 'd') { event.preventDefault(); handleControl('RIGHT'); }
  if (key === 'enter') { event.preventDefault(); handleControl('ENTER'); }
  if (key === 'escape' || key === 'backspace') { event.preventDefault(); handleControl('BACKSPACE'); }
});
