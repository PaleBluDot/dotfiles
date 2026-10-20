import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// GitHub bar widget: icon + badge (unread notifications + review requests),
// dropdown with notifications, review requests, your open PRs and assigned issues.
// Data comes from status.py, which only talks to the gh CLI.
Panel {
  id: root
  moduleName: "pale.github"
  ipcTarget: "pale.github"
  manageIpc: false

  readonly property string helperPath: String(Qt.resolvedUrl("status.py")).replace(/^file:\/\//, "")
  readonly property int refreshIntervalSec: {
    var n = Number(settings && settings.refreshIntervalSec)
    return isFinite(n) && n >= 60 ? n : 300
  }

  // GitHub clones folder, opened in a terminal.
  readonly property string localDir: "~/Projects/github.com"
  readonly property string localPath: Quickshell.env("HOME") + "/Projects/github.com"

  readonly property var sectionDefs: [
    { key: "notifications", title: "NOTIFICATIONS", icon: "󰂚", empty: "No unread notifications" },
    { key: "reviews", title: "REVIEW REQUESTS", icon: "", empty: "Nothing waiting for your review" },
    { key: "mine", title: "MY OPEN PULL REQUESTS", icon: "", empty: "No open pull requests" },
    { key: "issues", title: "ASSIGNED ISSUES", icon: "", empty: "No assigned issues" }
  ]

  property bool installed: true
  property bool authenticated: false
  property bool loaded: false
  property string user: ""
  property string lastError: ""
  property var sections: ({})
  property int localCount: 0
  property int remoteCount: 0
  property string remoteUrl: "https://github.com"
  property bool cursorActive: false
  property int cursorIndex: 0
  property string _out: ""

  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color urgent: bar ? bar.urgent : Color.urgent
  readonly property color dim: Qt.darker(foreground, 1.55)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  function section(key) { return sections && sections[key] ? sections[key] : { count: 0, capped: false, items: [], more: "https://github.com" } }
  function countText(s) { return s.capped ? s.count + "+" : String(s.count) }
  readonly property int badgeCount: section("notifications").count + section("reviews").count

  // Flat list of clickable rows, in display order, for keyboard navigation.
  readonly property var rows: {
    var out = [{ kind: "local" }, { kind: "remote" }]
    if (!authenticated) { out.push({ kind: "login" }); return out }
    for (var i = 0; i < sectionDefs.length; i++) {
      var s = section(sectionDefs[i].key)
      for (var j = 0; j < s.items.length; j++) out.push({ kind: "item", url: s.items[j].url, key: sectionDefs[i].key, index: j })
      if (s.count > s.items.length) out.push({ kind: "more", url: s.more, key: sectionDefs[i].key })
    }
    return out
  }
  function rowIndexOf(kind, key, index) {
    for (var i = 0; i < rows.length; i++) {
      var r = rows[i]
      if (r.kind === kind && (key === undefined || r.key === key) && (index === undefined || r.index === index)) return i
    }
    return -1
  }

  function refresh() {
    if (statusProcess.running) return
    root._out = ""
    statusProcess.command = ["python3", "-I", root.helperPath]
    statusProcess.running = true
  }

  function apply(raw) {
    var p
    try { p = JSON.parse(raw) } catch (e) { lastError = "Could not read gh output"; return }
    installed = p.installed === true
    authenticated = p.authenticated === true
    user = String(p.user || "")
    sections = p.sections || {}
    localCount = Number(p.local && p.local.count) || 0
    remoteCount = Number(p.remote && p.remote.count) || 0
    remoteUrl = String(p.remote && p.remote.url || "https://github.com")
    lastError = String(p.error || "")
    loaded = true
    if (cursorIndex >= rows.length) cursorIndex = Math.max(0, rows.length - 1)
  }

  function openUrl(url) {
    if (!url) return
    Quickshell.execDetached(["xdg-open", String(url)])
    root.close()
  }

  function openLocal() {
    Quickshell.execDetached(["uwsm-app", "--", "xdg-terminal-exec", "--dir=" + root.localPath])
    root.close()
  }

  function login() {
    Quickshell.execDetached(["omarchy-launch-floating-terminal-with-presentation", "gh auth login && echo && echo 'Logged in. You can close this window.'"])
    loginRefresh.restart()
  }

  function activate(i) {
    var r = rows[i]
    if (!r) return
    if (r.kind === "login") login()
    else if (r.kind === "local") openLocal()
    else if (r.kind === "remote") openUrl(root.remoteUrl)
    else openUrl(r.url)
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onOpenedChanged: if (opened) {
    cursorActive = false
    cursorIndex = 0
    if (panelFlick) panelFlick.contentY = 0
    refresh()
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  Component.onCompleted: refresh()

  Timer {
    interval: root.refreshIntervalSec * 1000
    repeat: true
    running: true
    onTriggered: root.refresh()
  }

  // After `gh auth login`, poll a few times until the login shows up.
  Timer {
    id: loginRefresh
    property int ticks: 0
    interval: 5000
    repeat: true
    onTriggered: {
      ticks += 1
      root.refresh()
      if (root.authenticated || ticks >= 24) { running = false; ticks = 0 }
    }
  }

  Process {
    id: statusProcess
    running: false
    command: []
    stdout: StdioCollector { id: statusStdout; waitForEnd: true; onStreamFinished: root._out = text }
    onExited: function(exitCode) {
      var out = String(statusStdout.text || root._out || "")
      if (exitCode === 0 && out !== "") root.apply(out)
      else root.lastError = "gh status check failed"
    }
  }

  IpcHandler {
    target: root.ipcTarget
    function open(): void { root.open() }
    function close(): void { root.close() }
    function toggle(): void { root.toggle() }
    function refresh(): string { root.refresh(); return "ok" }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.badgeCount > 0 && !root.vertical ? "\uf09b " + root.badgeCount : "\uf09b"
    slotSize: Style.bar.iconSlot * (root.badgeCount > 0 && !root.vertical ? (root.badgeCount > 9 ? 2.4 : 1.9) : 1)
    tooltipText: ""
    opacity: root.authenticated ? 1.0 : 0.6
    onPressed: function(buttonCode) {
      if (buttonCode === Qt.RightButton) root.refresh()
      else if (buttonCode === Qt.MiddleButton) root.openUrl("https://github.com/notifications")
      else root.toggle()
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(400))
    contentHeight: panel.fittedContentHeight(column.implicitHeight, Style.space(600))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onMoveRequested: function(dx, dy) {
        if (!root.cursorActive) { root.cursorActive = true; return }
        if (dy !== 0 && root.rows.length > 0)
          root.cursorIndex = Math.max(0, Math.min(root.rows.length - 1, root.cursorIndex + dy))
      }
      onActivateRequested: if (root.cursorActive) root.activate(root.cursorIndex)
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onTextKey: function(t) {
        if (t === "r" || t === "R") root.refresh()
        else if (t === "n" || t === "N") root.openUrl("https://github.com/notifications")
      }

      Flickable {
        id: panelFlick
        anchors.fill: parent
        contentWidth: width
        contentHeight: column.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick
        interactive: contentHeight > height
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

        Column {
          id: column
          width: panelFlick.width
          spacing: Style.space(12)

          PanelHero {
            width: parent.width
            title: "GitHub"
            meta: !root.installed ? "gh is not installed"
              : !root.loaded ? "Loading…"
              : root.authenticated ? "@" + root.user
              : "Not logged in"
            foreground: root.foreground
            fontFamily: root.fontFamily
            iconComponent: Component {
              Text {
                text: ""
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.display
              }
            }
            // Local / remote repo counts, inline with the GitHub @user header.
            trailingControl: Component {
              Row {
                spacing: Style.space(6)
                Chip_ {
                  glyph: "󰉋"
                  count: root.localCount
                  hint: "Local repos in " + root.localDir + " — open in terminal"
                  rowIndex: root.rowIndexOf("local")
                  onActivated: root.openLocal()
                }
                Chip_ {
                  visible: root.authenticated
                  glyph: "󰅟"
                  count: root.remoteCount
                  hint: "Your repos on GitHub (you + your orgs) — open your profile"
                  rowIndex: root.rowIndexOf("remote")
                  onActivated: root.openUrl(root.remoteUrl)
                }
              }
            }
          }

          Text {
            textFormat: Text.PlainText
            visible: root.lastError !== ""
            width: parent.width
            text: root.lastError
            color: root.urgent
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
            wrapMode: Text.WordWrap
          }

          Row_ {
            visible: root.loaded && root.installed && !root.authenticated
            width: parent.width
            rowIndex: root.rowIndexOf("login")
            glyph: "󰌆"
            title: "Log in to GitHub"
            meta: "Runs gh auth login in a terminal"
            onActivated: root.login()
          }

          Repeater {
            model: root.authenticated ? root.sectionDefs : []
            Column {
              id: sectionCol
              required property var modelData
              readonly property var info: root.section(modelData.key)
              width: column.width
              spacing: Style.space(6)

              PanelSectionHeader {
                text: sectionCol.modelData.title + "  " + root.countText(sectionCol.info)
                foreground: root.foreground
                fontFamily: root.fontFamily
              }

              Text {
                visible: sectionCol.info.items.length === 0
                width: parent.width
                text: sectionCol.modelData.empty
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.bodySmall
                leftPadding: Style.space(10)
              }

              Repeater {
                model: sectionCol.info.items
                Row_ {
                  required property var modelData
                  required property int index
                  width: sectionCol.width
                  rowIndex: root.rowIndexOf("item", sectionCol.modelData.key, index)
                  glyph: sectionCol.modelData.icon
                  title: String(modelData.title || "")
                  meta: String(modelData.meta || "")
                  onActivated: root.openUrl(modelData.url)
                }
              }

              Row_ {
                visible: sectionCol.info.count > sectionCol.info.items.length
                width: sectionCol.width
                rowIndex: root.rowIndexOf("more", sectionCol.modelData.key)
                glyph: "󰁔"
                title: "View all " + root.countText(sectionCol.info) + " on GitHub"
                meta: ""
                onActivated: root.openUrl(sectionCol.info.more)
              }
            }
          }
        }
      }
    }
  }

  component Chip_: CursorSurface {
    id: chip
    property string glyph: ""
    property int count: 0
    property string hint: ""
    property int rowIndex: -1
    signal activated()

    hasCursor: root.cursorActive && rowIndex >= 0 && root.cursorIndex === rowIndex
    foreground: root.foreground
    implicitWidth: chipRow.implicitWidth + Style.space(16)
    implicitHeight: chipRow.implicitHeight + Style.space(8)

    MouseArea {
      id: chipMouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onEntered: if (chip.rowIndex >= 0) { root.cursorActive = true; root.cursorIndex = chip.rowIndex }
      onClicked: chip.activated()
    }

    Row {
      id: chipRow
      anchors.centerIn: parent
      spacing: Style.space(6)
      Text {
        text: chip.glyph
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.icon
        anchors.verticalCenter: parent.verticalCenter
      }
      Text {
        text: String(chip.count)
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.body
        anchors.verticalCenter: parent.verticalCenter
      }
    }

    PanelToolTip {
      visible: chipMouse.containsMouse
      text: chip.hint
      fontFamily: root.fontFamily
    }
  }

  component Row_: CursorSurface {
    id: row
    property int rowIndex: -1
    property string glyph: ""
    property string title: ""
    property string meta: ""
    signal activated()

    hasCursor: root.cursorActive && rowIndex >= 0 && root.cursorIndex === rowIndex
    foreground: root.foreground
    implicitHeight: content.implicitHeight + Style.spacing.rowPaddingX

    MouseArea {
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onEntered: if (row.rowIndex >= 0) { root.cursorActive = true; root.cursorIndex = row.rowIndex }
      onClicked: row.activated()
    }

    RowLayout {
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      anchors.leftMargin: Style.space(10)
      anchors.rightMargin: Style.space(10)
      spacing: Style.space(8)

      Text {
        textFormat: Text.PlainText
        text: row.glyph
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.icon
        Layout.alignment: Qt.AlignVCenter
      }

      ColumnLayout {
        id: content
        Layout.fillWidth: true
        spacing: Style.space(1)

        Text {
          textFormat: Text.PlainText
          Layout.fillWidth: true
          text: row.title
          color: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.body
          elide: Text.ElideRight
        }

        Text {
          textFormat: Text.PlainText
          visible: row.meta !== ""
          Layout.fillWidth: true
          text: row.meta
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          elide: Text.ElideRight
        }
      }
    }
  }
}
