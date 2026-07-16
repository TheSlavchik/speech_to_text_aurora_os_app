import QtQuick 2.0
import Sailfish.Silica 1.0
import ru.omstu.voicenotes 1.0
import "../Database.js" as Db

CoverBackground {
    id: cover
    objectName: "defaultCover"
    property string notesCount: "0"
    property bool modelReady: false
    property bool modelLoading: true

    function refreshCount() {
        notesCount = "" + Db.notesCount()
    }

    Component.onCompleted: {
        refreshCount()
        SpeechRecognizer.init()
        appWindow.coverPage = cover
    }

    onStatusChanged: {
        if (status === Cover.Active) {
            refreshCount()
        }
    }

    Connections {
        target: SpeechRecognizer
        onModelReadyChanged: {
            modelReady = SpeechRecognizer.modelReady
        }
        onLoadingChanged: {
            modelLoading = SpeechRecognizer.loading
        }
        onFinished: {
            refreshCount()
            // Saving is handled by ApplicationWindow (imperative connect)
        }
    }

    Item {
        anchors {
            fill: parent
            bottomMargin: Theme._coverActionsAreaHorizontalHeight
        }

        Column {
            anchors.centerIn: parent
            spacing: Theme.paddingSmall

            Label {
                anchors.horizontalCenter: parent.horizontalCenter
                text: {
                    if (modelLoading)
                        return qsTr("Загрузка модели...")
                    if (!modelReady && !SpeechRecognizer.recording)
                        return qsTr("Модель недоступна")
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
        enabled: modelReady && !SpeechRecognizer.recording

        CoverAction {
            iconSource: "image://theme/icon-m-mic"
            onTriggered: SpeechRecognizer.start()
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
        var h = Math.floor(s / 3600)
        var m = Math.floor((s % 3600) / 60)
        var sec = s % 60
        return (h < 10 ? "0" : "") + h + ":" + (m < 10 ? "0" : "") + m + ":" + (sec < 10 ? "0" : "") + sec
    }
}
