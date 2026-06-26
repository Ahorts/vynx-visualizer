pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.services
import qs.modules.common.models.hyprland
import qs.modules.common.functions as CF

Item {
    id: root

    property string extensionId: ""

    property list<real> points: Array.from({length: 50}, () => 0)

    property var registeredWidgets: []

    function registerWidget(w) {
        let list = registeredWidgets.slice()
        list.push(w)
        registeredWidgets = list
    }

    function unregisterWidget(w) {
        let list = registeredWidgets.filter(item => item !== w)
        registeredWidgets = list
    }

    readonly property bool isNeeded: {
        return registeredWidgets.some(w => w.isActuallyShown)
    }

    readonly property string extPath: {
        return ExtensionManager.installedExtensions[extensionId]?.installedPath ?? ""
    }
    readonly property string cavaConfigPath: extPath + "/scripts/cava_config"

    // Cava process
    Process {
        id: cavaProc
        running: root.isNeeded && (enableAnimations.value ?? true) && extPath !== ""
        onRunningChanged: {
            if (!cavaProc.running) {
                root.points = Array.from({length: 50}, () => 0);
            }
        }
        command: ["cava", "-p", cavaConfigPath]
        stdout: SplitParser {
            onRead: data => {
                const pts = data.split(";").map(p => parseFloat(p.trim())).filter(p => !isNaN(p));
                if (pts.length > 0) {
                    root.points = pts;
                }
            }
        }
    }

    HyprlandConfigOption {
        id: enableAnimations
        key: "animations:enabled"
    }

    Component.onCompleted: {}
}
