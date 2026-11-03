// Exposé model for the Omarchy window overview. Loaded by both the QML
// panel and the Node test harness, so it must stay dependency-free.
//
// Dispatches use Hyprland's Lua provider syntax (classic dispatcher strings
// fail under configProvider=lua — verified live). Addresses arrive from
// Quickshell WITHOUT the 0x prefix and from hyprctl WITH it; everything
// here normalizes to the 0x form the selectors expect.

function ensure0x(address) {
  var value = String(address == null ? "" : address).trim()
  if (value.length === 0) return ""
  return value.indexOf("0x") === 0 ? value : "0x" + value
}

// A window address is hex only; anything else must never reach the Lua
// string (addresses come from the compositor, but never trust interpolation).
function isValidAddress(address) {
  return /^0x[0-9a-fA-F]+$/.test(ensure0x(address))
}

function focusDispatch(address) {
  var addr = ensure0x(address)
  if (!isValidAddress(addr)) return ""
  return "hl.dsp.focus({ window = hl.get_window('address:" + addr + "') })"
}

function raiseDispatch(address) {
  var addr = ensure0x(address)
  if (!isValidAddress(addr)) return ""
  return "hl.dsp.window.alter_zorder({ mode = 'top', window = hl.get_window('address:" + addr + "') })"
}

function moveDispatch(address, workspaceId) {
  var addr = ensure0x(address)
  var id = Number(workspaceId)
  if (!isValidAddress(addr) || !isFinite(id) || id <= 0 || id !== Math.floor(id)) return ""
  return "hl.dsp.window.move({ workspace = tostring(" + id
    + "), window = hl.get_window('address:" + addr + "'), follow = false })"
}

function workspaceFocusDispatch(workspaceId) {
  var id = Number(workspaceId)
  if (!isFinite(id) || id <= 0 || id !== Math.floor(id)) return ""
  return "hl.dsp.focus({ workspace = tostring(" + id + ") })"
}

// Normal workspaces only (special/scratchpad ids are negative), sorted by id.
function sortWorkspaceIds(ids) {
  var list = []
  for (var i = 0; i < (ids ? ids.length : 0); i++) {
    var id = Number(ids[i])
    if (isFinite(id) && id > 0 && list.indexOf(id) === -1) list.push(id)
  }
  list.sort(function (a, b) { return a - b })
  return list
}

// Special workspaces (scratchpad, minimized, …) carry negative ids.
function sortSpecialIds(ids) {
  var list = []
  for (var i = 0; i < (ids ? ids.length : 0); i++) {
    var id = Number(ids[i])
    if (isFinite(id) && id < 0 && list.indexOf(id) === -1) list.push(id)
  }
  list.sort(function (a, b) { return a - b })
  return list
}

// "special:minimized" -> "minimized" for display.
function specialLabel(name) {
  return String(name == null ? "" : name).replace(/^special:/, "")
}

// Restoring a stashed window moves it to the target workspace AND follows
// (focus lands on it) — unlike the silent drag-move.
function restoreDispatch(address, workspaceId) {
  var addr = ensure0x(address)
  var id = Number(workspaceId)
  if (!isValidAddress(addr) || !isFinite(id) || id <= 0 || id !== Math.floor(id)) return ""
  return "hl.dsp.window.move({ workspace = tostring(" + id
    + "), window = hl.get_window('address:" + addr + "') })"
}

// Workspace grid: near-square, biased one column wider (screens are wide).
function gridColumns(count) {
  var n = Math.max(1, Number(count) || 1)
  return Math.min(n, Math.ceil(Math.sqrt(n)))
}

// Window tiles inside one workspace cell: near-square mini-grid.
function tileGrid(count) {
  var n = Math.max(0, Number(count) || 0)
  if (n === 0) return { cols: 1, rows: 1 }
  var cols = Math.ceil(Math.sqrt(n))
  return { cols: cols, rows: Math.ceil(n / cols) }
}

// Flatten workspaces to a keyboard-navigable window order:
// [{ workspaceId, address }] sorted by workspace then by given order.
function flattenWindows(cells) {
  var flat = []
  var list = cells || []
  for (var i = 0; i < list.length; i++) {
    var cell = list[i]
    for (var j = 0; j < (cell.addresses ? cell.addresses.length : 0); j++) {
      flat.push({ workspaceId: cell.workspaceId, address: cell.addresses[j] })
    }
  }
  return flat
}

if (typeof module !== "undefined") {
  module.exports = {
    ensure0x: ensure0x,
    isValidAddress: isValidAddress,
    focusDispatch: focusDispatch,
    raiseDispatch: raiseDispatch,
    moveDispatch: moveDispatch,
    workspaceFocusDispatch: workspaceFocusDispatch,
    restoreDispatch: restoreDispatch,
    sortWorkspaceIds: sortWorkspaceIds,
    sortSpecialIds: sortSpecialIds,
    specialLabel: specialLabel,
    gridColumns: gridColumns,
    tileGrid: tileGrid,
    flattenWindows: flattenWindows
  }
}
