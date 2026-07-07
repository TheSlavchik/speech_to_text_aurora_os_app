import QtQuick 2.0
import Sailfish.Silica 1.0
import "../Database.js" as Db

CoverBackground {
    id: cover
    objectName: "defaultCover"

    property bool isRecording: false
    property string recordDuration: "00:00"
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

    CoverTemplate {
        objectName: "applicationCover"
        primaryText: isRecording ? qsTr("Идёт запись...") : qsTr("STT")
        secondaryText: isRecording ? recordDuration :
                        qsTr("Заметок: %1").arg(notesCount)
        icon {
            source: Qt.resolvedUrl("../icons/STT.svg")
            sourceSize { width: icon.width; height: icon.height }
        }
    }

    // Recording indicator on cover
    Rectangle {
        anchors {
            bottom: parent.bottom
            horizontalCenter: parent.horizontalCenter
            bottomMargin: Theme.paddingLarge
        }
        width: parent.width * 0.6
        height: Theme.paddingSmall
        radius: height / 2
        visible: isRecording
        color: Theme.errorColor

        SequentialAnimation on opacity {
            loops: Animation.Infinite
            PropertyAnimation { to: 0.4; duration: 800 }
            PropertyAnimation { to: 1.0; duration: 800 }
        }
    }
}