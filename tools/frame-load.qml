import QtQuick
import QtQuick.Window
Window {
    visible: true
    visibility: Window.FullScreen
    title: "T531 compositor frame workload"
    color: "#15253b"
    Rectangle {
        width: 160; height: 160; y: 320
        color: "#ffc857"
        SequentialAnimation on x {
            loops: Animation.Infinite
            NumberAnimation { from: 0; to: 1120; duration: 1800 }
            NumberAnimation { from: 1120; to: 0; duration: 1800 }
        }
    }
    Text { x: 30; y: 30; text: "SM-T531 frame pacing"; color: "white"; font.pixelSize: 32 }
    Timer { interval: 25000; running: true; onTriggered: Qt.quit() }
}
