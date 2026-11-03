const assert = require('node:assert/strict')
const fs = require('node:fs')
const path = require('node:path')

const root = path.resolve(__dirname, '..')
function read(relative) {
  return fs.readFileSync(path.join(root, relative), 'utf8')
}

const manifest = JSON.parse(read('manifest.json'))
assert.equal(manifest.schemaVersion, 1)
assert.equal(manifest.id, 'community.window-overview')
assert.deepEqual(manifest.kinds, ['panel'])
assert.equal(manifest.entryPoints.panel, 'Overview.qml')
assert.match(read('LICENSE'), /MIT License/)

const panel = read('Overview.qml')

// Host lifecycle contract (same shape the Nexus panel established).
assert.match(panel, /^Item \{/m, 'plugin entry point is an Item')
assert.match(panel, /function open\(payloadJson\)/)
assert.match(panel, /function close\(\)/)
assert.match(panel, /function status\(\)/)
assert.match(panel, /property bool opened/)
assert.match(panel, /closingFromHost/)
assert.match(panel, /shell\.hide\(/)
assert.match(panel, /visible: root\.opened/)
assert.match(panel, /WlrLayershell\.keyboardFocus: root\.opened \? WlrKeyboardFocus\.Exclusive : WlrKeyboardFocus\.None/)
assert.match(panel, /WlrLayershell\.layer: WlrLayer\.Overlay/)
assert.match(panel, /exclusionMode: ExclusionMode\.Ignore/)
assert.match(panel, /Qt\.Key_Escape/)

// Fully reactive: no subprocesses, no timers. Actions are compositor
// dispatches built exclusively by the validated model (nothing unhex can
// reach the Lua string).
assert.doesNotMatch(panel, /\bProcess\s*\{|\bTimer\s*\{/, 'no polling, no subprocesses')
assert.doesNotMatch(panel, /execDetached|bash -c|sh -c|hyprctl/, 'no shell-outs at all')
assert.match(panel, /OverviewModel\.focusDispatch/)
assert.match(panel, /OverviewModel\.moveDispatch/)
assert.match(panel, /OverviewModel\.workspaceFocusDispatch/)
assert.match(panel, /OverviewModel\.sortWorkspaceIds/)
assert.match(panel, /OverviewModel\.flattenWindows/)
assert.match(panel, /OverviewModel\.parseScope\(payloadJson\)/, 'open() honours the scope payload')
assert.match(panel, /OverviewModel\.scopeWorkspaceIds\(/)
assert.match(panel, /if \(request === ""\) return/, 'empty (rejected) dispatches never fire')
assert.match(panel, /Hyprland\.dispatch\(request\)/)

// Thumbnails: live screencopy of each toplevel, active only while open.
assert.match(panel, /ScreencopyView \{/)
assert.match(panel, /captureSource: tile\.modelData && tile\.modelData\.wayland/)
assert.match(panel, /live: root\.opened/)

// Drag-and-drop between workspaces uses a typed drag key so foreign drags
// never trigger a move.
assert.match(panel, /keys: \["omarchy-window"\]/)
assert.match(panel, /Drag\.keys: \["omarchy-window"\]/)
assert.match(read('model/OverviewModel.js'), /follow = false/,
  'moves are silent — the overview stays put')

// Minimized/special windows restore onto the focused workspace and follow.
assert.match(panel, /OverviewModel\.sortSpecialIds/)
assert.match(panel, /OverviewModel\.specialLabel/)
assert.match(panel, /OverviewModel\.restoreDispatch/)
assert.match(panel, /restoreWindow/)

// Theme integration comes from shared tokens.
assert.match(panel, /import qs\.Commons/)
assert.match(panel, /import qs\.Ui/)
assert.doesNotMatch(panel, /#[0-9a-fA-F]{6}/)

console.log('ok - window overview contract')
