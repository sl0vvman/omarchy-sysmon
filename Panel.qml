# SPDX-License-Identifier: MIT

import QtQuick
import Quickshell
import Quickshell.Io

// Three compact vertical gauges: CPU load, RAM usage, disk usage.
// Each gauge has a dim track and a filled column, sitting on a faint rounded
// card so it reads as a mini chart rather than a wireless-signal icon.
// Hover shows the numbers, click runs the configured command.
Item {
  id: root

  property var bar
  property var settings

  readonly property int intervalSec: {
    var value = settings && settings.refreshIntervalSec !== undefined
      ? Number(settings.refreshIntervalSec) : 10
    if (!isFinite(value) || value < 2) return 10
    return Math.min(3600, Math.round(value))
  }
  readonly property string clickCommand: {
    var value = settings && settings.clickCommand !== undefined
      ? String(settings.clickCommand) : ""
    return value !== "" ? value : "omarchy-launch-or-focus-tui btop"
  }
  // The helper script ships next to this file inside the plugin directory.
  readonly property string scriptPath: decodeURIComponent(
    String(Qt.resolvedUrl("sysmon")).replace(/^file:\/\//, ""))

  property int cpu: 0
  property int ram: 0
  property int disk: 0
  property string tip: "CPU / RAM / disk"
  property bool tooltipHovered: hoverArea.containsMouse

  readonly property color fg: bar ? bar.foreground : "#ffffff"
  readonly property color accent: bar ? bar.urgent : "#ff5555"

  implicitWidth: 27
  implicitHeight: bar ? bar.barSize : 26

  function load(raw) {
    try {
      var data = JSON.parse(String(raw || ""))
      root.cpu = Math.round(Number(data.cpu) || 0)
      root.ram = Math.round(Number(data.ram) || 0)
      root.disk = Math.round(Number(data.disk) || 0)
      if (data.tooltip) root.tip = String(data.tooltip)
    } catch (e) {
      // Keep the last known values when a poll fails.
    }
  }

  function barHeight(value) {
    var pct = Math.max(0, Math.min(100, Number(value) || 0))
    return Math.max(2, Math.round(11 * (1 + pct) / 100))
  }

  function barColor(value) {
    return Number(value) >= 85 ? root.accent : root.fg
  }

  component MetricBar: Item {
    id: metric
    property int value: 0
    width: 4
    height: 13

    Rectangle {
      anchors.fill: parent
      radius: 1
      color: root.fg
      opacity: 0.22
    }
    Rectangle {
      anchors.bottom: parent.bottom
      width: parent.width
      radius: 1
      height: root.barHeight(metric.value)
      color: root.barColor(metric.value)
    }
  }

  Rectangle {
    anchors.centerIn: graph
    width: graph.width + 7
    height: graph.height + 5
    radius: 3
    color: root.fg
    opacity: 0.07
  }

  Item {
    id: graph
    width: 18
    height: 13
    anchors.centerIn: parent

    MetricBar { x: 0; value: root.cpu }
    MetricBar { x: 7; value: root.ram }
    MetricBar { x: 14; value: root.disk }
  }

  MouseArea {
    id: hoverArea
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onEntered: if (root.bar && root.tip) root.bar.showTooltip(root, root.tip)
    onExited: if (root.bar) root.bar.hideTooltip(root)
    onClicked: if (root.bar) root.bar.run(root.clickCommand)
  }

  Process {
    id: poll
    command: ["bash", root.scriptPath]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.load(text)
    }
  }

  Timer {
    interval: root.intervalSec * 1000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: if (!poll.running) poll.running = true
  }
}
