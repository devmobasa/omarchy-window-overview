import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.Commons
import qs.Ui
import "model/OverviewModel.js" as OverviewModel

// Window overview / exposé for Omarchy: every normal workspace as a cell
// with live window thumbnails. Click a window to focus it, click a cell's
// header to switch to that workspace, drag a window onto another cell to
// move it there silently. Arrows + Enter navigate by keyboard; 1-9,0 jump
// straight to a workspace; Escape closes.
//
// Fully reactive: workspaces and windows come from Quickshell's Hyprland
// models, thumbnails from ScreencopyView over the toplevel-export protocol,
// and every action is a compositor dispatch (Lua provider syntax) — the
// plugin spawns no subprocess at all.
Item {
  id: root

  property string omarchyPath: Quickshell.env("OMARCHY_PATH")
  property var shell: null
  property var manifest: null

  property bool opened: false
  property var targetScreen: null
  property bool closingFromHost: false
  property int selectedIndex: -1
  property string dragAddress: ""
  property int scopeWorkspaceId: -1

  function open(payloadJson) {
    var focusedId = Hyprland.focusedWorkspace ? Number(Hyprland.focusedWorkspace.id) : -1
    root.scopeWorkspaceId = OverviewModel.parseScope(payloadJson) === "current" ? focusedId : -1
    root.targetScreen = targetScreenForOpen()
    root.selectedIndex = -1
    root.dragAddress = ""
    Hyprland.refreshWorkspaces()
    Hyprland.refreshToplevels()
    root.opened = true
    Qt.callLater(function () {
      if (root.opened) keyCatcher.forceActiveFocus()
    })
  }

  function close() {
    closingFromHost = true
    root.opened = false
    root.targetScreen = null
    root.selectedIndex = -1
    root.dragAddress = ""
    closingFromHost = false
  }

  function requestClose() {
    if (closingFromHost) return
    if (shell && typeof shell.hide === "function")
      shell.hide(manifest && manifest.id ? manifest.id : "community.window-overview")
    else root.opened = false
  }

  function status() {
    return JSON.stringify({
      opened: root.opened,
      screen: root.targetScreen ? String(root.targetScreen.name || "") : "",
      scope: root.scopeWorkspaceId > 0 ? "current" : "all",
      workspaces: root.workspaceCells.length,
      windows: root.flatWindows.length,
      selectedIndex: root.selectedIndex
    })
  }

  function targetScreenForOpen() {
    var screens = Quickshell.screens || []
    var focused = Hyprland.focusedMonitor
    for (var i = 0; i < screens.length; i++) {
      var monitor = Hyprland.monitorFor(screens[i])
      if (focused && monitor === focused) return screens[i]
      if (focused && String(screens[i].name || "") === String(focused.name || "")) return screens[i]
    }
    return screens.length > 0 ? screens[0] : null
  }

  // ---- reactive workspace/window model -------------------------------------
  readonly property var workspaceCells: {
    var workspaces = Hyprland.workspaces ? Hyprland.workspaces.values : []
    var byId = {}
    var ids = []
    for (var i = 0; i < workspaces.length; i++) {
      var workspace = workspaces[i]
      if (!workspace) continue
      byId[workspace.id] = workspace
      ids.push(workspace.id)
    }
    var sorted = OverviewModel.scopeWorkspaceIds(OverviewModel.sortWorkspaceIds(ids), root.scopeWorkspaceId)
    var cells = []
    for (var j = 0; j < sorted.length; j++) {
      var ws = byId[sorted[j]]
      var toplevels = ws.toplevels ? ws.toplevels.values : []
      var addresses = []
      for (var k = 0; k < toplevels.length; k++) {
        if (toplevels[k]) addresses.push(String(toplevels[k].address || ""))
      }
      cells.push({ workspaceId: ws.id, name: String(ws.name || ws.id), workspace: ws,
        toplevels: toplevels, addresses: addresses })
    }
    return cells
  }

  readonly property var flatWindows: OverviewModel.flattenWindows(workspaceCells)

  // Special workspaces (minimized/scratchpad stashes): shown as a bottom
  // strip; clicking a window restores it to the focused workspace.
  readonly property var specialCells: {
    var workspaces = Hyprland.workspaces ? Hyprland.workspaces.values : []
    var byId = {}
    var ids = []
    for (var i = 0; i < workspaces.length; i++) {
      var workspace = workspaces[i]
      if (!workspace) continue
      byId[workspace.id] = workspace
      ids.push(workspace.id)
    }
    var sorted = OverviewModel.sortSpecialIds(ids)
    var cells = []
    for (var j = 0; j < sorted.length; j++) {
      var ws = byId[sorted[j]]
      var toplevels = ws.toplevels ? ws.toplevels.values : []
      if (toplevels.length === 0) continue
      cells.push({ workspaceId: ws.id, label: OverviewModel.specialLabel(String(ws.name || ws.id)),
        toplevels: toplevels })
    }
    return cells
  }

  function restoreWindow(address) {
    var target = Hyprland.focusedWorkspace ? Number(Hyprland.focusedWorkspace.id) : 1
    var request = OverviewModel.restoreDispatch(address, target > 0 ? target : 1)
    dispatchAndClose(request)
  }

  function dispatchAndClose(request) {
    if (request === "") return
    Hyprland.dispatch(request)
    requestClose()
  }

  function focusWindow(address) {
    dispatchAndClose(OverviewModel.focusDispatch(address))
  }

  function moveWindow(address, workspaceId) {
    var request = OverviewModel.moveDispatch(address, workspaceId)
    if (request === "") return
    Hyprland.dispatch(request)
    dragAddress = ""
    Hyprland.refreshToplevels()
    Hyprland.refreshWorkspaces()
  }

  function focusWorkspace(workspaceId) {
    dispatchAndClose(OverviewModel.workspaceFocusDispatch(workspaceId))
  }

  function activateSelected() {
    if (selectedIndex < 0 || selectedIndex >= flatWindows.length) return
    focusWindow(flatWindows[selectedIndex].address)
  }

  Connections {
    target: Quickshell
    function onScreensChanged() {
      if (!root.opened) return
      var screens = Quickshell.screens || []
      if (!root.targetScreen || screens.indexOf(root.targetScreen) === -1) {
        root.targetScreen = root.targetScreenForOpen()
        if (!root.targetScreen) root.requestClose()
      }
    }
  }

  PanelWindow {
    id: panel
    visible: root.opened
    screen: root.targetScreen
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    WlrLayershell.namespace: "omarchy-window-overview"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: root.opened ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore

    Rectangle {
      anchors.fill: parent
      color: Color.menu.scrim
    }

    MouseArea {
      anchors.fill: parent
      onClicked: root.requestClose()
    }

    Item {
      id: keyCatcher
      anchors.fill: parent
      focus: true

      Keys.onPressed: function (event) {
        if (event.key === Qt.Key_Escape) {
          root.requestClose()
          event.accepted = true
        } else if (event.key === Qt.Key_Left || event.key === Qt.Key_Up
            || (event.key === Qt.Key_Tab && (event.modifiers & Qt.ShiftModifier))) {
          if (root.flatWindows.length > 0)
            root.selectedIndex = (root.selectedIndex - 1 + root.flatWindows.length) % root.flatWindows.length
          event.accepted = true
        } else if (event.key === Qt.Key_Right || event.key === Qt.Key_Down
            || event.key === Qt.Key_Tab) {
          if (root.flatWindows.length > 0)
            root.selectedIndex = (root.selectedIndex + 1) % root.flatWindows.length
          event.accepted = true
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter
            || event.key === Qt.Key_Space) {
          root.activateSelected()
          event.accepted = true
        } else if (event.text >= "0" && event.text <= "9") {
          var id = event.text === "0" ? 10 : Number(event.text)
          root.focusWorkspace(id)
          event.accepted = true
        }
      }

      // ---- the exposé grid -------------------------------------------------
      Grid {
        id: workspaceGrid
        anchors.centerIn: parent
        width: Math.floor(panel.width * 0.86)
        height: Math.floor(panel.height * 0.84)
        columns: OverviewModel.gridColumns(root.workspaceCells.length)
        columnSpacing: Style.space(16)
        rowSpacing: Style.space(16)

        readonly property int cellRows: Math.ceil(root.workspaceCells.length / columns)
        readonly property real cellWidth: (width - (columns - 1) * columnSpacing) / columns
        readonly property real cellHeight: (height - (cellRows - 1) * rowSpacing) / Math.max(1, cellRows)

        Repeater {
          model: root.workspaceCells

          BorderSurface {
            id: cell
            required property var modelData
            width: workspaceGrid.cellWidth
            height: workspaceGrid.cellHeight
            radius: Style.cornerRadius
            color: dropArea.containsDrag
              ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.16)
              : Color.menu.background
            borderSpec: Border.surfaceSpec("menu", "border",
              dropArea.containsDrag ? Color.accent : Color.menu.border,
              Math.max(1, Style.space(2)))

            DropArea {
              id: dropArea
              anchors.fill: parent
              keys: ["omarchy-window"]
              onDropped: function (drop) {
                root.moveWindow(root.dragAddress, cell.modelData.workspaceId)
                drop.accept()
              }
            }

            Column {
              anchors.fill: parent
              anchors.margins: Style.space(10)
              spacing: Style.space(6)

              // Workspace header: click to switch there.
              Item {
                width: parent.width
                height: headerText.implicitHeight

                Text {
                  id: headerText
                  text: "Workspace " + cell.modelData.workspaceId
                    + (cell.modelData.addresses.length > 0
                      ? " · " + cell.modelData.addresses.length : "")
                  color: cell.modelData.workspace && cell.modelData.workspace.focused
                    ? Color.accent : Qt.darker(Color.menu.text, 1.2)
                  font.family: Style.font.family
                  font.pixelSize: Style.font.bodySmall
                  font.bold: true
                }

                MouseArea {
                  anchors.fill: parent
                  onClicked: root.focusWorkspace(cell.modelData.workspaceId)
                }
              }

              Grid {
                id: tileArea
                width: parent.width
                height: parent.height - headerText.implicitHeight - Style.space(6)
                columns: OverviewModel.tileGrid(cell.modelData.toplevels.length).cols
                columnSpacing: Style.space(6)
                rowSpacing: Style.space(6)

                readonly property int tileRows: OverviewModel.tileGrid(cell.modelData.toplevels.length).rows
                readonly property real tileWidth: (width - (columns - 1) * columnSpacing) / Math.max(1, columns)
                readonly property real tileHeight: (height - (tileRows - 1) * rowSpacing) / Math.max(1, tileRows)

                Repeater {
                  model: cell.modelData.toplevels

                  Rectangle {
                    id: tile
                    required property var modelData
                    readonly property string tileAddress: String(modelData ? modelData.address || "" : "")
                    readonly property bool selected: root.selectedIndex >= 0
                      && root.flatWindows[root.selectedIndex]
                      && root.flatWindows[root.selectedIndex].address === tileAddress
                      && tileAddress !== ""

                    width: tileArea.tileWidth
                    height: tileArea.tileHeight
                    radius: Style.cornerRadius / 2
                    clip: true
                    color: Qt.rgba(Color.menu.text.r, Color.menu.text.g, Color.menu.text.b, 0.05)
                    border.width: selected ? 2 : 1
                    border.color: selected ? Color.accent
                      : Qt.rgba(Color.menu.text.r, Color.menu.text.g, Color.menu.text.b, 0.12)

                    Drag.active: tileDrag.active
                    Drag.keys: ["omarchy-window"]
                    Drag.hotSpot.x: width / 2
                    Drag.hotSpot.y: height / 2

                    ScreencopyView {
                      anchors.fill: parent
                      anchors.margins: 2
                      captureSource: tile.modelData && tile.modelData.wayland ? tile.modelData.wayland : null
                      live: root.opened
                      constraintSize: Qt.size(width, height)
                    }

                    Rectangle {
                      anchors.left: parent.left
                      anchors.right: parent.right
                      anchors.bottom: parent.bottom
                      height: titleText.implicitHeight + Style.space(4)
                      color: Qt.rgba(0, 0, 0, 0.55)

                      Text {
                        id: titleText
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: Style.space(6)
                        anchors.rightMargin: Style.space(6)
                        text: tile.modelData ? String(tile.modelData.title || "") : ""
                        color: "white"
                        font.family: Style.font.family
                        font.pixelSize: Style.font.caption
                        elide: Text.ElideRight
                      }
                    }

                    MouseArea {
                      id: tileMouse
                      anchors.fill: parent
                      onClicked: root.focusWindow(tile.tileAddress)
                    }

                    DragHandler {
                      id: tileDrag
                      onActiveChanged: {
                        if (active) {
                          root.dragAddress = tile.tileAddress
                        } else {
                          tile.Drag.drop()
                          tile.x = 0
                          tile.y = 0
                        }
                      }
                    }
                  }
                }
              }
            }
          }
        }
      }

      // Minimized / special-workspace strip: click a chip to restore that
      // window onto the focused workspace (and follow it).
      Row {
        visible: root.specialCells.length > 0
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Style.space(44)
        spacing: Style.space(16)

        Repeater {
          model: root.specialCells

          Row {
            id: specialGroup
            required property var modelData
            spacing: Style.space(6)

            Text {
              text: "󰘸 " + specialGroup.modelData.label
              color: Color.accent
              font.family: Style.font.family
              font.pixelSize: Style.font.bodySmall
              font.bold: true
              anchors.verticalCenter: parent.verticalCenter
            }

            Repeater {
              model: specialGroup.modelData.toplevels

              Rectangle {
                id: specialChip
                required property var modelData
                width: Math.min(chipText.implicitWidth + Style.space(16), Style.space(140))
                height: chipText.implicitHeight + Style.space(8)
                radius: Style.cornerRadius / 2
                color: chipMouse.containsMouse
                  ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.25)
                  : Qt.rgba(Color.menu.text.r, Color.menu.text.g, Color.menu.text.b, 0.08)
                border.width: 1
                border.color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.5)

                Text {
                  id: chipText
                  anchors.centerIn: parent
                  width: Math.min(implicitWidth, parent.width - Style.space(12))
                  text: specialChip.modelData ? String(specialChip.modelData.title || "window") : ""
                  color: Color.menu.text
                  font.family: Style.font.family
                  font.pixelSize: Style.font.caption
                  elide: Text.ElideRight
                }

                MouseArea {
                  id: chipMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  onClicked: root.restoreWindow(
                    specialChip.modelData ? String(specialChip.modelData.address || "") : "")
                }
              }
            }
          }
        }
      }

      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Style.space(18)
        text: "Click to focus · drag between workspaces · 1-9,0 jumps"
          + (root.specialCells.length > 0 ? " · minimized windows restore from below" : "")
          + " · Esc closes"
        color: Qt.darker(Color.menu.text, 1.4)
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
      }
    }
  }
}
