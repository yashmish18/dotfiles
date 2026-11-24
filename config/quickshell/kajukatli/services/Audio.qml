pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

Singleton {
    id: root

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource
    readonly property bool ready: Pipewire.ready && sink !== null && sink.audio !== null

    readonly property real volume: ready ? sink.audio.volume : 0
    readonly property bool muted: ready ? sink.audio.muted : false
    readonly property real micVolume: source && source.audio ? source.audio.volume : 0
    readonly property bool micMuted: source && source.audio ? source.audio.muted : false

    readonly property var sinks: (Pipewire.nodes.values || []).filter(n => n.audio && n.isSink && !n.isStream)
    readonly property var streams: (Pipewire.nodes.values || []).filter(n => n.audio && n.isStream && !n.isSink)

    function name(node): string {
        if (!node) return "";
        return node.nickname || node.description || node.name;
    }
    function streamName(node): string {
        if (!node) return "";
        const p = node.properties || {};
        return p["application.name"] || node.description || node.name;
    }

    function setVolume(v: real) {
        if (!ready) return;
        sink.audio.muted = false;
        sink.audio.volume = Math.max(0, Math.min(1, v));
    }
    function toggleMute() {
        if (ready) sink.audio.muted = !sink.audio.muted;
    }
    function setMic(v: real) {
        if (source && source.audio) source.audio.volume = Math.max(0, Math.min(1, v));
    }
    function toggleMic() {
        if (source && source.audio) source.audio.muted = !source.audio.muted;
    }
    function useSink(node) {
        Pipewire.preferredDefaultAudioSink = node;
    }

    // volume and mute are only live on bound nodes
    PwObjectTracker {
        objects: [root.sink, root.source].concat(root.sinks || []).concat(root.streams || []).filter(Boolean)
    }
}
