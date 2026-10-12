/* SPDX-License-Identifier: GPL-3.0-only */
import QtQuick

// Keep desktop MouseArea dragging, but let a finger scroll a panel row.
// Symbol grids can opt into direct dragging with a horizontal first move.
QtObject {
    id: root

    required property MouseArea mouseArea
    required property Item item
    property bool allowHorizontalTouchDrag: false
    property bool touchPress: false
    property bool touchClaimed: false
    property bool directionPending: false
    property point pressPosition

    readonly property bool dragAllowed: !touchPress || touchClaimed
    // MouseArea's drag target takes the grab after its movement threshold.
    // Keeping preventStealing false lets Flickable see the initial press and
    // avoids changing MouseArea's grab policy halfway through that press.
    readonly property bool preventStealing: false

    function updateDirection(position) {
        if (!touchPress || !directionPending || !mouseArea.pressed) {
            return
        }
        const dx = Math.abs(position.x - pressPosition.x)
        const dy = Math.abs(position.y - pressPosition.y)
        if (Math.max(dx, dy) < 6) {
            return
        }
        directionPending = false
        if (allowHorizontalTouchDrag && dx > dy) {
            touchClaimed = true
            ui.setTouchDragEditing(item, true)
        }
    }

    function finish() {
        if (touchPress) {
            ui.watchTouchDrag(item, null)
            ui.setTouchDragEditing(item, false)
        }
        directionPending = false
        // Keep the decision until the next press: changing dragAllowed here
        // could re-arm a mouse drag while MouseArea is releasing/cancelling.
    }

    property Connections events: Connections {
        target: root.mouseArea
        function onPressed(mouse) {
            root.touchPress = ui.isTouchInput(root.item)
            root.touchClaimed = false
            root.directionPending = root.touchPress
            root.pressPosition = root.mouseArea.mapToItem(null, mouse.x, mouse.y)
            if (root.touchPress) {
                ui.watchTouchDrag(root.item, root)
            }
        }
        function onReleased(mouse) { root.finish() }
        function onCanceled() { root.finish() }
    }
}
