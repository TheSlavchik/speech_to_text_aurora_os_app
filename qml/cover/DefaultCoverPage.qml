import QtQuick 2.0
import Sailfish.Silica 1.0
import ru.omstu.STT 1.0
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

    Connections {
        target: SpeechRecognizer
        onFinished: refreshCount()
    }

    // Reserve space above the CoverActionList by applying a bottom margin.
    Item {
        anchors {
            fill: parent
            bottomMargin: SpeechRecognizer.recording ? Theme._coverActionsAreaHorizontalHeight : 0
        }

        Column {
            anchors.centerIn: parent
            spacing: Theme.paddingSmall

            Label {
                anchors.horizontalCenter: parent.horizontalCenter
                text: {
                    if (SpeechRecognizer.paused)
                        return qsTr("Пауза")
                    if (SpeechRecognizer.recording)
                        return qsTr("Идёт запись...")
                    return qsTr("Заметок: %1").arg(notesCount)
                }
                color: (SpeechRecognizer.recording && !SpeechRecognizer.paused)
                       ? Theme.errorColor : Theme.primaryColor
                font.pixelSize: Theme.fontSizeMedium
            }

            Label {
                anchors.horizontalCenter: parent.horizontalCenter
                text: formatTime(SpeechRecognizer.durationSec)
                color: Theme.secondaryColor
                font.pixelSize: Theme.fontSizeSmall
                visible: SpeechRecognizer.recording
            }
        }
    }

    CoverActionList {
        enabled: SpeechRecognizer.recording

        CoverAction {
            iconSource: "image://theme/icon-m-cancel"
            onTriggered: SpeechRecognizer.cancel()
        }
        CoverAction {
            iconSource: SpeechRecognizer.paused ? "image://theme/icon-m-play"
                                                : "image://theme/icon-m-pause"
            onTriggered: {
                if (SpeechRecognizer.paused) {
                    SpeechRecognizer.resume()
                } else {
                    SpeechRecognizer.pause()
                }
            }
        }
        CoverAction {
            iconSource: "image://theme/icon-m-stop"
            onTriggered: SpeechRecognizer.stop()
        }
    }

    function formatTime(seconds) {
        var s = Math.floor(seconds)
        var min = Math.floor(s / 60)
        var sec = s % 60
        return (min < 10 ? "0" : "") + min + ":" + (sec < 10 ? "0" : "") + sec
    }
}
