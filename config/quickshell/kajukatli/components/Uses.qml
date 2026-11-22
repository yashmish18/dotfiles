import QtQuick

// "i'm showing this service right now": counts itself into service.consumers while active,
// so cava / weather / system stats only run when something on screen actually needs them.
QtObject {
    property var service: null
    property bool active: true
    property bool counted: false

    function sync() {
        if (!service || active === counted) return;
        service.consumers += active ? 1 : -1;
        counted = active;
    }
    onActiveChanged: sync()
    onServiceChanged: sync()
    Component.onCompleted: sync()
    Component.onDestruction: if (counted && service) service.consumers -= 1
}
