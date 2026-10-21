// RK Traders - billing screen logic
const cart = [];
let customer = null;
let offers = [];
fetch('/api/offers').then(r => r.json()).then(o => { offers = o; render(); }).catch(() => {});
const $ = id => document.getElementById(id);
const fmt = n => '₹' + n.toFixed(2);

// ---------- product search ----------
const search = $('search'), sug = $('suggest');
let timer, results = [], sel = -1, lastQuery = '';
search.addEventListener('input', () => { clearTimeout(timer); timer = setTimeout(doSearch, 120); });
search.addEventListener('keydown', e => {
  if (e.key === 'ArrowDown') { sel = Math.min(sel + 1, results.length - 1); paint(); e.preventDefault(); }
  else if (e.key === 'ArrowUp') { sel = Math.max(sel - 1, 0); paint(); e.preventDefault(); }
  else if (e.key === 'Enter') { e.preventDefault(); enterSearch(); }
  else if (e.key === 'Escape') hide();
});
async function doSearch() {
  const qv = search.value.trim();
  if (!qv) return hide();
  results = await (await fetch('/api/products/search?q=' + encodeURIComponent(qv))).json();
  lastQuery = qv;
  sel = results.length ? 0 : -1;
  paint();
}
async function enterSearch() {
  const v = search.value.trim();
  if (!v) return;
  clearTimeout(timer);
  if (v !== lastQuery) await doSearch();            // a scanner sends Enter before the search delay has fired
  if (search.value.trim() !== v) return;            // user kept typing meanwhile
  const exact = results.find(p => p.barcode && p.barcode === v);
  if (exact) addItem(exact, true);                  // scanned: keep the cursor here for the next packet
  else if (results[sel]) addItem(results[sel]);
}
function paint() {
  sug.innerHTML = results.map((p, i) =>
    `<div class="${i === sel ? 'sel' : ''}" onmousedown="addItem(results[${i}])">
       <span>${p.name}</span>
       <span class="meta ${p.qty <= 0 ? 'nostock' : ''}">${hasOffer(p) ? '<b class="offer-tag">OFFER</b> ' : ''}${fmt(p.selling_price)} / ${p.unit} · stock ${p.qty}</span></div>`).join('')
    || '<div class="meta">No product found</div>';
  sug.style.display = 'block';
}
function hide() { sug.style.display = 'none'; sel = -1; }
document.addEventListener('click', e => { if (!e.target.closest('.search-box')) { hide(); $('csuggest').style.display = 'none'; } });

// ---------- cart ----------
function addItem(p, scanned) {
  const ex = cart.find(r => r.product_id === p.id);
  if (ex) ex.quantity += 1;
  else cart.push({ product_id: p.id, name: p.name, unit: p.unit, gst_rate: p.gst_rate, category_id: p.category_id, stock: p.qty, quantity: 1, unit_price: p.selling_price });
  search.value = ''; lastQuery = ''; hide(); render();
  const idx = cart.findIndex(r => r.product_id === p.id);
  const row = document.querySelectorAll('#items tbody tr')[idx];
  if (row) { row.classList.add('just-added'); setTimeout(() => row.classList.remove('just-added'), 900); }
  if (scanned) { search.focus(); return; }
  const qtyInputs = document.querySelectorAll('#items tbody input.qty');
  if (qtyInputs[idx]) { qtyInputs[idx].focus(); qtyInputs[idx].select(); }
}

// ---------- barcode scanner while the cursor is somewhere else ----------
// A scanner types the whole code in a few milliseconds and ends with Enter. If that lands in a
// quantity or price box, take the code back out of that box and add the scanned item instead.
let burst = '', burstAt = 0, burstTarget = null, burstBefore = '';
document.addEventListener('keydown', e => {
  if (e.target === search || e.altKey || e.ctrlKey || e.metaKey) return;
  const now = Date.now();
  if (e.key.length === 1) {
    if (now - burstAt > 60) { burst = ''; burstTarget = e.target; burstBefore = (e.target && 'value' in e.target) ? e.target.value : ''; }
    burst += e.key; burstAt = now; return;
  }
  if (e.key === 'Enter' && burst.length >= 4 && now - burstAt < 60) {
    const code = burst; burst = '';
    e.preventDefault(); e.stopPropagation();
    if (burstTarget && 'value' in burstTarget) { burstTarget.value = burstBefore; burstTarget.dispatchEvent(new Event('input')); }
    search.value = code; enterSearch();
  } else if (e.key === 'Enter') burst = '';
}, true);
function render() {
  const tb = document.querySelector('#items tbody');
  if (!cart.length) { tb.innerHTML = '<tr><td colspan="9" class="empty">Search a product above to start the bill.</td></tr>'; calc(); return; }
  tb.innerHTML = cart.map((r, i) => `<tr>
    <td>${i + 1}</td><td><strong>${r.name}</strong>${r.quantity > r.stock ? ' <span class="low">(only ' + r.stock + ' in stock)</span>' : ''}</td>
    <td class="num"><input class="qty" type="number" step="0.001" min="0.001" value="${r.quantity}" data-i="${i}"></td>
    <td>${r.unit}</td>
    <td class="num">${CAN_EDIT_PRICE ? `<input class="price" type="number" step="0.01" min="0" value="${r.unit_price}" data-i="${i}">` : fmt(r.unit_price)}</td>
    <td class="num">${r.gst_rate}%</td>
    <td id="off${i}" class="offer-cell"></td>
    <td class="num" id="amt${i}">${fmt(r.quantity * r.unit_price)}</td>
    <td><span class="remove" onclick="cart.splice(${i},1);render()">✕</span></td></tr>`).join('');
  tb.querySelectorAll('input.qty').forEach(inp => {
    inp.oninput = () => { cart[inp.dataset.i].quantity = +inp.value || 0; updateRow(inp.dataset.i); };
    inp.onkeydown = e => { if (e.key === 'Enter') { search.focus(); e.preventDefault(); } };
  });
  tb.querySelectorAll('input.price').forEach(inp => {
    inp.oninput = () => { cart[inp.dataset.i].unit_price = +inp.value || 0; updateRow(inp.dataset.i); };
    inp.onkeydown = e => { if (e.key === 'Enter') { search.focus(); e.preventDefault(); } };
  });
  calc();
}
function updateRow(i) { calc(); }
function hasOffer(p) { return offers.some(o => (o.product_id === p.id) || (o.category_id && o.category_id === p.category_id)); }
function lineOffer(r) {
  let best = { name: '', disc: 0 }; const gross = r.quantity * r.unit_price;
  for (const o of offers) {
    let d = 0;
    if (o.type === 'product_pct' && o.product_id === r.product_id) d = gross * o.value / 100;
    else if (o.type === 'product_price' && o.product_id === r.product_id && o.value < r.unit_price) d = (r.unit_price - o.value) * r.quantity;
    else if (o.type === 'buy_x_get_y' && o.product_id === r.product_id && o.buy_qty && o.free_qty) d = Math.floor(r.quantity / (o.buy_qty + o.free_qty)) * o.free_qty * r.unit_price;
    else if (o.type === 'category_pct' && o.category_id && o.category_id === r.category_id) d = gross * o.value / 100;
    d = Math.round(Math.min(d, gross) * 100) / 100;
    if (d > best.disc) best = { name: o.name, disc: d };
  }
  return best;
}
function billOffer(after) {
  let best = { name: '', disc: 0 };
  for (const o of offers) {
    if (!(o.type === 'bill_pct' || o.type === 'bill_flat') || after < (o.min_bill || 0) || after <= 0) continue;
    let d = o.type === 'bill_pct' ? after * o.value / 100 : o.value;
    d = Math.round(Math.min(d, after) * 100) / 100;
    if (d > best.disc) best = { name: o.name, disc: d };
  }
  return best;
}

function calc() {
  const subtotal = cart.reduce((s, r) => s + r.quantity * r.unit_price, 0);
  const lo = cart.map(r => lineOffer(r));
  const lineTotal = lo.reduce((s, o) => s + o.disc, 0);
  const after = subtotal - lineTotal;
  const bo = billOffer(after);
  const offerTotal = lineTotal + bo.disc;
  let discount = +$('discount').value || 0;
  if (discount > after - bo.disc) discount = Math.max(0, after - bo.disc);
  const ratio = after ? (after - bo.disc - discount) / after : 1;
  let taxable = 0, tax = 0;
  cart.forEach((r, i) => {
    const net = (r.quantity * r.unit_price - lo[i].disc) * ratio; const t = net / (1 + r.gst_rate / 100); taxable += t; tax += net - t;
    const a = $('amt' + i), oc = $('off' + i);
    if (a) a.innerHTML = lo[i].disc ? `<s class="hint">${fmt(r.quantity * r.unit_price)}</s><br>${fmt(r.quantity * r.unit_price - lo[i].disc)}` : fmt(r.quantity * r.unit_price);
    if (oc) oc.innerHTML = lo[i].disc ? `<span class="offer-tag">${lo[i].name}</span><br><small>-${fmt(lo[i].disc)}</small>` : '';
  });
  const names = [...new Set(lo.filter(o => o.disc).map(o => o.name).concat(bo.disc ? [bo.name] : []))];
  $('offerline').style.display = offerTotal ? 'flex' : 'none';
  $('offername').textContent = names.join(', ');
  $('offerdisc').textContent = '-' + fmt(offerTotal);
  const exact = subtotal - offerTotal - discount, grand = Math.round(exact);
  $('n_items').textContent = cart.length;
  $('subtotal').textContent = fmt(subtotal);
  $('taxable').textContent = fmt(taxable);
  $('tax').textContent = fmt(tax);
  $('roundoff').textContent = fmt(grand - exact);
  $('grand').textContent = '₹' + grand;
  const paid = +$('paid').value || 0;
  $('remaining').textContent = '₹' + Math.max(0, grand - paid).toFixed(2);
  const recv = +$('received').value || 0;
  $('change').textContent = '₹' + (recv ? Math.max(0, recv - grand).toFixed(2) : '0');
}
$('discount').addEventListener('input', calc);
$('paid').addEventListener('input', calc);
$('received').addEventListener('input', calc);
document.querySelectorAll('input[name=mode]').forEach(r => r.addEventListener('change', () => {
  const credit = document.querySelector('input[name=mode]:checked').value === 'Credit';
  $('creditbox').style.display = credit ? 'block' : 'none';
  $('cashbox').style.display = credit ? 'none' : 'block';
  if (credit && !customer) { $('cust').focus(); }
}));

// ---------- customer ----------
const cust = $('cust'), csug = $('csuggest');
let ctimer;
cust.addEventListener('input', () => { customer = null; $('custinfo').textContent = ''; clearTimeout(ctimer); ctimer = setTimeout(custSearch, 150); });
async function custSearch() {
  const qv = cust.value.trim();
  if (!qv) { csug.style.display = 'none'; return; }
  const rows = await (await fetch('/api/customers/search?q=' + encodeURIComponent(qv))).json();
  csug.innerHTML = rows.map((c, i) => `<div onmousedown='pickCustomer(${JSON.stringify(c)})'><span>${c.name}</span><span class="meta">${c.phone || ''} · due ₹${c.credit_balance}</span></div>`).join('')
    || `<div class="meta" onmousedown="newCustomer()">Not found. Click to add "${qv}"</div>`;
  csug.style.display = 'block';
}
function pickCustomer(c) {
  customer = c; cust.value = c.name; csug.style.display = 'none';
  $('custinfo').textContent = (c.phone ? c.phone + ' · ' : '') + 'Udhaar due ₹' + (+c.credit_balance).toFixed(2);
}
async function newCustomer() {
  const name = prompt('Customer name:', cust.value.trim()); if (!name) return;
  const phone = prompt('Phone (optional):', '') || '';
  const r = await (await fetch('/api/customers', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ name, phone }) })).json();
  if (r.ok) pickCustomer(r); else alert(r.error);
}

// ---------- save ----------
async function save() {
  if (!cart.length) return alert('Bill is empty.');
  const mode = document.querySelector('input[name=mode]:checked').value;
  if (mode === 'Credit' && !customer) { alert('Select a customer for a credit (udhaar) bill.'); cust.focus(); return; }
  const body = { items: cart.map(r => ({ product_id: r.product_id, quantity: r.quantity, unit_price: r.unit_price })),
    discount: +$('discount').value || 0, payment_mode: mode, customer_id: customer ? customer.id : null,
    paid_amount: mode === 'Credit' ? (+$('paid').value || 0) : null };
  $('save').disabled = true;
  try {
    const r = await (await fetch('/api/sales', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body) })).json();
    if (r.ok) { window.open('/sales/' + r.id + '?print=1', '_blank'); clearBill(); }
    else alert(r.error || 'Could not save bill');
  } finally { $('save').disabled = false; }
}
function clearBill() {
  cart.length = 0; customer = null; cust.value = ''; $('custinfo').textContent = '';
  $('discount').value = 0; $('paid').value = 0; $('received').value = '';
  document.querySelector('input[name=mode][value=Cash]').checked = true;
  $('creditbox').style.display = 'none'; $('cashbox').style.display = 'block';
  render(); search.focus();
}
$('save').onclick = save;
$('clear').onclick = () => { if (!cart.length || confirm('Clear this bill?')) clearBill(); };
document.addEventListener('keydown', e => {
  if (e.key === 'F9') { e.preventDefault(); save(); }
  if (e.key === 'F2') { e.preventDefault(); search.focus(); }
});
render();
