import QtQuick
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions as CF
import qs.modules.common.widgets
import qs.modules.ii.background.widgets
import qs.modules.common.models.hyprland
import Quickshell

AbstractBackgroundWidget {
    id: root

    // Override AbstractBackgroundWidget layout to pin at bottom of the root window
    // Doing this because qs crashes after fullscreen. Might be caused by losing the parent
    // since the background is offloaded when apps go fullscreen
    property var activeParent: null
    onParentChanged: {
        if (parent !== null) {
            activeParent = parent
        }
    }
    parent: QsWindow.window ? QsWindow.window.contentItem : activeParent
    x: 0
    y: QsWindow.window ? QsWindow.window.height - height : 0
    width: QsWindow.window ? QsWindow.window.width : 0
    draggable: false

    property string extensionId: ""
    readonly property bool isCovered: QsWindow.window ? (QsWindow.window.isCovered ?? false) : false
    readonly property bool hasFullscreen: QsWindow.window ? (QsWindow.window.hasFullscreen ?? false) : false
    readonly property var _configs: ExtensionManager.extensionConfigs[extensionId] || {}

    readonly property var config: ({
        height: _configs.height ?? 500,
        targetBarWidth: _configs.targetBarWidth ?? 20,
        barSpacing: _configs.barSpacing ?? 4,
        barRounding: _configs.barRounding ?? 0.4,
        smoothing: _configs.smoothing ?? 0.2,
        dataAveraging: _configs.dataAveraging ?? 0.3,
        opacity: _configs.opacity ?? 0.8,
        mono: _configs.mono ?? false,
        fillOpacity: _configs.fillOpacity ?? 0.5,
        borderWidth: _configs.borderWidth ?? 3
    })

    readonly property bool isActuallyShown: {
        if (!(configEntry?.enable ?? true)) return false;
        if (GlobalStates.screenLocked) {
            return _configs.showWhenLocked ?? true;
        }
        
        let hideFull = _configs.hideWhenFullscreen ?? true;
        let hideCovered = _configs.hideWhenCovered ?? true;
        
        if (hideFull && hasFullscreen) return false;
        if (hideCovered && isCovered) return false;
        return true;
    }

    // Cava Stuff
    readonly property var cavaService: ExtensionServices.loaded[extensionId + ".visualizerService"] || null
    property list<real> points: cavaService ? cavaService.points : []

    property color primaryColor: Appearance.colors.colPrimary

    readonly property color fillColor: Qt.rgba(primaryColor.r, primaryColor.g, primaryColor.b, config.fillOpacity)

    height: config.height
    opacity: (isActuallyShown && (enableAnimations.value ?? true)) ? 1 : 0
    visible: opacity > 0
    Behavior on opacity { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }

    readonly property int barCount: Math.max(1, Math.floor(width / (config.targetBarWidth + config.barSpacing)))
    readonly property real exactWidth: (width - (config.barSpacing * (barCount - 1))) / barCount
    
    property real activityOpacity: 0
    Behavior on activityOpacity { NumberAnimation { duration: 500; easing.type: Easing.OutCubic } }

    readonly property var targetPoints: {
        let raw = points;
        if (!raw || raw.length === 0) return Array(barCount).fill(0);
        let count = barCount;
        let mapped = new Array(count);
        let rawLenM1 = raw.length - 1;

        for (let i = 0; i < count; i++) {
            let progress = i / (count - 1 || 1);
            let relPos = config.mono ? (Math.abs(progress - 0.5) * 2) * rawLenM1 : progress * rawLenM1;
            let low = Math.floor(relPos), high = Math.ceil(relPos), mix = relPos - low;
            mapped[i] = (raw[low] * (1 - mix)) + (raw[high] * (high < raw.length ? mix : 0));
        }

        if (config.dataAveraging <= 0) return mapped;
        let smoothed = new Array(count);
        let sW = config.dataAveraging * 0.25; 
        for (let j = 0; j < count; j++) {
            let p = mapped[Math.max(0, j - 1)];
            let n = mapped[Math.min(count - 1, j + 1)];
            smoothed[j] = (p * sW) + (mapped[j] * (1.0 - 2 * sW)) + (n * sW);
        }
        return smoothed;
    }

    Row {
        id: visualizerRow
        anchors.fill: parent
        spacing: root.config.barSpacing
        opacity: root.config.opacity * root.activityOpacity
        visible: opacity > 0
        
        Repeater {
            model: root.barCount
            delegate: Rectangle {
                width: root.exactWidth
                height: Math.max(2, (root.targetPoints[index] / 1000) * root.height)
                anchors.bottom: parent.bottom
                topLeftRadius: width * root.config.barRounding
                topRightRadius: width * root.config.barRounding
                bottomLeftRadius: 0
                bottomRightRadius: 0
                color: root.primaryColor
                border.width: root.config.borderWidth
                border.color: root.fillColor

                Behavior on height { NumberAnimation { duration: root.config.smoothing * 1000; easing.type: Easing.Linear } }
            }
        }
    }

    Timer { id: silenceTimer; interval: 1000; onTriggered: root.activityOpacity = 0 }
    
    HyprlandConfigOption {
        id: enableAnimations
        key: "animations:enabled"
    }

    onCavaServiceChanged: {
        if (cavaService) {
            cavaService.registerWidget(root)
        }
    }

    onPointsChanged: {
        if (points.some(p => p > 0)) {
            root.activityOpacity = 1.0;
            silenceTimer.restart();
        }
    }

    Component.onCompleted: {
        if (cavaService) {
            cavaService.registerWidget(root)
        }
    }

    Component.onDestruction: {
        if (cavaService) {
            cavaService.unregisterWidget(root)
        }
    }
}
