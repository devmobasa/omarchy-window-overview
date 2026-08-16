const assert = require('node:assert/strict')
const model = require('../model/OverviewModel.js')

// ---- address hygiene --------------------------------------------------------

assert.equal(model.ensure0x('563e004c1e40'), '0x563e004c1e40', 'Quickshell form gains the prefix')
assert.equal(model.ensure0x('0x563e004c1e40'), '0x563e004c1e40')
assert.equal(model.ensure0x(''), '')
assert.equal(model.isValidAddress('563e004c1e40'), true)
assert.equal(model.isValidAddress('0xdeadBEEF'), true)
assert.equal(model.isValidAddress("0xdead'); os.execute('rm"), false, 'nothing unhex reaches the Lua string')
assert.equal(model.isValidAddress(''), false)

// ---- dispatch builders ------------------------------------------------------

assert.equal(model.focusDispatch('563e004c1e40'),
  "hl.dsp.focus({ window = hl.get_window('address:0x563e004c1e40') })")
assert.equal(model.focusDispatch('nope'), '', 'invalid addresses build nothing')

assert.equal(model.moveDispatch('0xabc', 3),
  "hl.dsp.window.move({ workspace = tostring(3), window = hl.get_window('address:0xabc'), follow = false })")
assert.equal(model.moveDispatch('0xabc', 0), '', 'workspace ids are positive integers')
assert.equal(model.moveDispatch('0xabc', 2.5), '')
assert.equal(model.moveDispatch('zz', 3), '')

assert.equal(model.workspaceFocusDispatch(4), "hl.dsp.focus({ workspace = tostring(4) })")
assert.equal(model.workspaceFocusDispatch(-1), '')

// ---- layout math ------------------------------------------------------------

assert.deepEqual(model.sortWorkspaceIds([3, 1, 2, 1, -98, 0, 'x']), [1, 2, 3],
  'special and invalid ids drop; duplicates collapse')
assert.deepEqual(model.sortWorkspaceIds(null), [])
assert.deepEqual(model.sortSpecialIds([3, -98, -99, -98, 0]), [-99, -98],
  'special workspaces are the negative ids')
assert.equal(model.specialLabel('special:minimized'), 'minimized')
assert.equal(model.specialLabel('special:scratchpad'), 'scratchpad')
assert.equal(model.specialLabel('plain'), 'plain')

assert.equal(model.restoreDispatch('0xabc', 2),
  "hl.dsp.window.move({ workspace = tostring(2), window = hl.get_window('address:0xabc') })",
  'restore follows the window (no follow=false)')
assert.equal(model.restoreDispatch('zz', 2), '')
assert.equal(model.restoreDispatch('0xabc', -5), '', 'never restore into a special workspace')

assert.equal(model.gridColumns(1), 1)
assert.equal(model.gridColumns(4), 2)
assert.equal(model.gridColumns(5), 3)
assert.equal(model.gridColumns(9), 3)
assert.equal(model.gridColumns(10), 4)

assert.deepEqual(model.tileGrid(0), { cols: 1, rows: 1 })
assert.deepEqual(model.tileGrid(1), { cols: 1, rows: 1 })
assert.deepEqual(model.tileGrid(2), { cols: 2, rows: 1 })
assert.deepEqual(model.tileGrid(5), { cols: 3, rows: 2 })

const flat = model.flattenWindows([
  { workspaceId: 1, addresses: ['0xa', '0xb'] },
  { workspaceId: 2, addresses: [] },
  { workspaceId: 3, addresses: ['0xc'] }
])
assert.equal(flat.length, 3)
assert.deepEqual(flat[2], { workspaceId: 3, address: '0xc' })

console.log('ok - overview model')
