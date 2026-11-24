import QtQuick
import qs.services
import qs.components

// one desktop widget, placed where you left it. handle it directly:
//   drag            move it anywhere
//   ctrl + drag     make it bigger or smaller (ctrl + scroll works too)
//   double-click    put it back where it started, at its normal size
//   right-click     its menu: bigger, smaller, put back, hide, settings
// the position is a fraction of the room it has to move in, so it lands in the same place
// on any screen; it also shrinks itself rather than ever hang off an edge.
Item {
    id: root
    property string name: ""
    property var fallback: ({ x: 0.5, y: 0.5 })
    property bool editable: true      // false for the copy drawn behind the subject
    property bool shown: true
    property bool gripOnly: false     // only the top strip drags it (a widget you type in)
    property bool ghost: false        // invisible but still grabbable (its look is drawn elsewhere)
    // "auto" placement: a function (w, h, areaW, areaH) → { x, y } as fractions, or null
    property var autoPlace: null
    default property alias content: holder.data

    readonly property Item item: holder.children.length > 0 ? holder.children[0] : null
    readonly property var saved: Config.pos(name, fallback)
    readonly property var p: {
        if (saved.auto && autoPlace && parent) {
            const a = autoPlace(iw * k0, ih * k0, parent.width, parent.height);
            if (a) return Object.assign({}, saved, a);
        }
        return saved;
    }
    property real live: -1            // the size while you drag the corner handle (saved on release)
    readonly property real k0: live > 0 ? Math.min(live, fit) : Math.max(0.3, Math.min(saved.s !== undefined ? saved.s : 1, fit))
    readonly property real iw: item ? item.implicitWidth : 0
    readonly property real ih: item ? item.implicitHeight : 0
    // your size, but never bigger than the screen allows
    readonly property real fit: iw > 0 && ih > 0 && parent ? Math.min(parent.width * 0.96 / iw, parent.height * 0.96 / ih) : 1
    readonly property real k: k0

    visible: shown || opacity > 0
    opacity: shown ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: 320; easing.type: Easing.OutQuad } }
    width: shown ? iw * k : 0
    height: shown ? ih * k : 0

    function place() {
        x = Qt.binding(() => Math.round(Math.max(0, parent.width - width) * p.x));
        y = Qt.binding(() => Math.round(Math.max(0, parent.height - height) * p.y));
    }
    Component.onCompleted: place()

    Item {
        id: holder
        width: root.iw
        height: root.ih
        scale: root.k
        transformOrigin: Item.TopLeft
        opacity: root.ghost ? 0 : 1
    }

    // ---------------------------------------------------------------- handling
    // a faint outline while you hold or hover it, so you know what you've got
    Rectangle {
        visible: root.editable && (Ui.editing || drag.active || stripDrag.active || hover.hovered && hover.point.modifiers & Qt.ControlModifier)
        anchors.fill: parent
        anchors.margins: -8
        radius: Theme.radiusSmall
        color: (drag.active || stripDrag.active) ? Theme.alpha(Theme.primary, 0.1) : "transparent"
        border.width: 1.5
        border.color: Theme.alpha(Theme.primary, (drag.active || stripDrag.active) ? 1 : 0.6)
    }
    HoverHandler {
        id: hover
        enabled: root.editable
    }
    // the notepad (gripOnly) is moved by a strip along its top, so the rest of it is for the
    // cursor; every other widget is moved by grabbing it anywhere, as before
    Item {
        id: dragZone
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: root.gripOnly && !Ui.editing ? Math.min(parent.height, 22) : 0
    }
    function dropped() {
        const fx = root.parent.width - root.width > 0 ? root.x / (root.parent.width - root.width) : 0.5;
        const fy = root.parent.height - root.height > 0 ? root.y / (root.parent.height - root.height) : 0.5;
        Config.setPos(root.name, fx, fy);
        root.place();
    }
    DragHandler {
        id: drag
        enabled: root.editable && root.shown && !(root.gripOnly && !Ui.editing)
        acceptedModifiers: Qt.NoModifier
        target: root
        xAxis.minimum: 0
        xAxis.maximum: Math.max(0, root.parent.width - root.width)
        yAxis.minimum: 0
        yAxis.maximum: Math.max(0, root.parent.height - root.height)
        dragThreshold: 6
        cursorShape: Qt.ClosedHandCursor
        onActiveChanged: { Ui.dragging = active; if (!active) root.dropped(); }
    }
    DragHandler {
        id: stripDrag
        parent: dragZone
        enabled: root.editable && root.shown && root.gripOnly && !Ui.editing
        acceptedModifiers: Qt.NoModifier
        target: root
        xAxis.minimum: 0
        xAxis.maximum: Math.max(0, root.parent.width - root.width)
        yAxis.minimum: 0
        yAxis.maximum: Math.max(0, root.parent.height - root.height)
        dragThreshold: 6
        cursorShape: Qt.ClosedHandCursor
        onActiveChanged: { Ui.dragging = active; if (!active) root.dropped(); }
    }
    WheelHandler {
        enabled: root.editable && root.shown
        acceptedModifiers: Qt.ControlModifier
        onWheel: e => Config.setScale(root.name, Math.max(0.3, Math.min(2.5, (root.saved.s !== undefined ? root.saved.s : 1) + (e.angleDelta.y > 0 ? 0.08 : -0.08))))
    }
    TapHandler {
        enabled: root.editable && root.shown
        onDoubleTapped: Config.resetWidget(root.name)
    }
    // right-click: the widget's menu (bigger, smaller, move back, hide…) right where you clicked
    TapHandler {
        enabled: root.editable && root.shown
        acceptedButtons: Qt.RightButton
        onTapped: (pt, button) => {
            const q = root.mapToItem(root.parent, pt.position.x, pt.position.y);
            Ui.widgetMenuX = q.x;
            Ui.widgetMenuY = q.y;
            Ui.widgetMenuOwner = root.parent;
            Ui.widgetMenu = root.name;
        }
    }

    // resizing: hold ctrl and drag the widget (a dot shows at its corner while ctrl is down, and
    // always in arrange mode). it is never there otherwise: a permanent handle sat on top of
    // the player's buttons and made them impossible to press.
    readonly property bool ctrlHover: hover.hovered && !!(hover.point.modifiers & Qt.ControlModifier)
    function resizeStart() { resizeK = root.k; resizeW = Math.max(40, root.width); }
    function resizeBy(dx: real) { root.live = Math.max(0.3, Math.min(2.5, resizeK * (resizeW + dx) / resizeW)); }
    function resizeEnd() {
        if (root.live > 0) Config.setScale(root.name, root.live);
        root.live = -1;
    }
    property real resizeK: 1
    property real resizeW: 100
    DragHandler {
        id: ctrlResize
        enabled: root.editable && root.shown
        target: null
        acceptedModifiers: Qt.ControlModifier
        cursorShape: Qt.SizeFDiagCursor
        onActiveChanged: { Ui.dragging = active; if (active) root.resizeStart(); else root.resizeEnd(); }
        onActiveTranslationChanged: if (active) root.resizeBy(activeTranslation.x)
    }
    Item {
        id: grip
        width: 20
        height: 20
        x: root.width - width
        y: root.height - height
        z: 50
        visible: root.editable && root.shown && (Ui.editing || root.ctrlHover || ctrlResize.active || resize.active)
        Rectangle {
            anchors.centerIn: parent
            width: 12
            height: 12
            radius: 6
            color: (resize.active || ctrlResize.active) ? Theme.primary : Theme.alpha(Theme.primary, 0.7)
            border.width: 2
            border.color: Theme.alpha("#ffffff", 0.85)
        }
        HoverHandler { cursorShape: Qt.SizeFDiagCursor }
        DragHandler {
            id: resize
            target: null
            cursorShape: Qt.SizeFDiagCursor
            onActiveChanged: { Ui.dragging = active; if (active) root.resizeStart(); else root.resizeEnd(); }
            onActiveTranslationChanged: if (active) root.resizeBy(activeTranslation.x)
        }
    }
}
