import QtQuick 2.0
import Sailfish.Silica 1.0
import "../Database.js" as Db

CoverBackground {
    id: cover
    objectName: "defaultCover"

    property string notesCount: "0"

    function refreshCount() {
        notesCount = "" + Db.notesCount()
    }

    Component.onCompleted: refreshCount()

    onStatusChanged: {
        if (status === Cover.Active) {
            refreshCount()
        }
    }

    Column {
        anchors.centerIn: parent
        spacing: Theme.paddingSmall

        // Recording indicator
        Label {
            anchors.horizontalCenter: parent.horizontalCenter
            text: globalRecognizer.recording ? qsTr("Идёт запись...") : qsTr("Заметок: %1").arg(notesCount)
            color: globalRecognizer.recording ? Theme.errorColor : Theme.primaryColor
            font.pixelSize: Theme.fontSizeMedium
        }

        Label {
            anchors.horizontalCenter: parent.horizontalCenter
            text: formatTime(globalRecognizer.durationSec)
            color: Theme.secondaryColor
            font.pixelSize: Theme.fontSizeSmall
            visible: globalRecognizer.recording
        }
    }

    function formatTime(seconds) {
        var s = Math.floor(seconds)
        var min = Math.floor(s / 60)
        var sec = s % 60
        return (min < 10 ? "0" : "") + min + ":" + (sec < 10 ? "0" : "") + sec
    }
}
