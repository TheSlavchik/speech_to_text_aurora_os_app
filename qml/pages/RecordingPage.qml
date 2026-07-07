import QtQuick 2.0
import Sailfish.Silica 1.0
import Nemo.Notifications 1.0
import ru.omstu.STT 1.0
import "../Database.js" as Db

Page {
    id: recordingPage
    objectName: "recordingPage"
    allowedOrientations: Orientation.All

    property int recordDuration: 0

    function formatTime(seconds) {
        var s = Math.floor(seconds)
        var min = Math.floor(s / 60)
        var sec = s % 60
        return (min < 10 ? "0" : "") + min + ":" + (sec < 10 ? "0" : "") + sec
    }

    // Offline speech recognition — uses the global instance from STT.qml.
    Connections {
        target: SpeechRecognizer

        onFinished: {
            var clean = text ? text.trim() : ""
            if (clean.length === 0) {
                // Nothing intelligible was captured.
                statusNotification.previewBody = qsTr("Речь не распознана. Попробуйте записать ещё раз.")
                statusNotification.publish()
                return
            }

            var now = new Date()
            var dateStr = Qt.formatDateTime(now, "dd.MM.yyyy hh:mm")
            var title = qsTr("Запись от %1").arg(dateStr)
            var durStr = formatTime(durationSec)

            var newId = Db.addNote(title, dateStr, clean, durStr, audioPath)
            pageStack.replace(Qt.resolvedUrl("NoteViewPage.qml"), {
                noteId: newId,
                noteTitle: title,
                noteDate: dateStr,
                noteText: clean,
                noteDuration: durStr,
                noteAudio: audioPath
            })
        }

        onErrorOccurred: {
            statusNotification.previewBody = message
            statusNotification.publish()
        }
    }

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: column.height

        Column {
            id: column
            width: parent.width

            PageHeader {
                title: SpeechRecognizer.recording ? qsTr("Запись") :
                       SpeechRecognizer.finalizing ? qsTr("Расшифровка") :
                       SpeechRecognizer.loading ? qsTr("Загрузка модели") :
                       qsTr("Готов к записи")
            }

            // Model loading indicator (model is loaded once, in background).
            Item {
                width: parent.width
                height: Theme.itemSizeExtraLarge
                visible: SpeechRecognizer.loading

                BusyIndicator {
                    anchors.centerIn: parent
                    running: SpeechRecognizer.loading
                    size: BusyIndicatorSize.Medium
                }
            }

            // Signal level visualization.
            Item {
                id: signalLevelContainer
                width: parent.width
                height: Theme.itemSizeExtraLarge * 2
                visible: SpeechRecognizer.recording

                Rectangle {
                    anchors.centerIn: parent
                    width: Theme.itemSizeExtraLarge * 1.5
                    height: Theme.itemSizeExtraLarge * 1.5
                    radius: width / 2
                    color: Qt.rgba(Theme.highlightColor.r, Theme.highlightColor.g, Theme.highlightColor.b, 0.1)
                    border.color: Theme.highlightColor
                    border.width: 2
                }

                Rectangle {
                    anchors.centerIn: parent
                    width: Theme.itemSizeMedium + SpeechRecognizer.level * Theme.itemSizeLarge
                    height: Theme.itemSizeMedium + SpeechRecognizer.level * Theme.itemSizeLarge
                    radius: width / 2
                    color: SpeechRecognizer.level < 0.7 ? Theme.highlightColor : Theme.errorColor
                    opacity: 0.3 + SpeechRecognizer.level * 0.5
                }

                Label {
                    anchors.centerIn: parent
                    text: qsTr("MIC")
                    color: Theme.highlightColor
                    font.pixelSize: Theme.fontSizeLarge
                    font.weight: Font.Bold
                }
            }

            // Duration display.
            Label {
                anchors.horizontalCenter: parent.horizontalCenter
                text: formatTime(SpeechRecognizer.durationSec)
                color: SpeechRecognizer.recording ? Theme.errorColor : Theme.primaryColor
                font.pixelSize: Theme.fontSizeExtraLarge
                font.weight: Font.Light
                visible: SpeechRecognizer.recording
            }

            Item { width: 1; height: Theme.paddingLarge }

            // Live transcription (interim + accepted text).
            Item {
                width: parent.width - 2 * Theme.horizontalPageMargin
                anchors.horizontalCenter: parent.horizontalCenter
                height: liveColumn.height
                visible: SpeechRecognizer.recording || SpeechRecognizer.finalizing

                Column {
                    id: liveColumn
                    width: parent.width

                    Label {
                        width: parent.width
                        text: SpeechRecognizer.finalizing ? qsTr("Завершаем расшифровку...")
                                                    : qsTr("Распознавание речи...")
                        color: Theme.secondaryColor
                        font.pixelSize: Theme.fontSizeSmall
                        horizontalAlignment: Text.AlignHCenter
                    }

                    Item { width: 1; height: Theme.paddingSmall }

                    ProgressBar {
                        width: parent.width
                        indeterminate: true
                        visible: SpeechRecognizer.finalizing
                    }

                    Item { width: 1; height: Theme.paddingSmall }

                    Label {
                        width: parent.width
                        text: {
                            var acc = SpeechRecognizer.fullText
                            var part = SpeechRecognizer.partialText
                            if (part.length > 0)
                                return (acc.length > 0 ? acc + " " : "") + part
                            return acc
                        }
                        color: Theme.primaryColor
                        font.pixelSize: Theme.fontSizeSmall
                        wrapMode: Text.WordWrap
                        horizontalAlignment: Text.AlignHCenter
                        visible: text.length > 0
                    }


                }
            }

            Item { width: 1; height: Theme.paddingLarge }

            // Control buttons row: Отмена | Пауза | Запись/Стоп
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: Theme.paddingLarge

                Rectangle {
                    width: Theme.itemSizeExtraLarge * 1.2
                    height: Theme.itemSizeExtraLarge * 1.2
                    radius: width / 2
                    color: Qt.rgba(Theme.errorColor.r, Theme.errorColor.g, Theme.errorColor.b, 0.8)
                    visible: SpeechRecognizer.recording || SpeechRecognizer.finalizing

                    IconButton {
                        anchors.centerIn: parent
                        icon.source: "image://theme/icon-m-cancel"
                        icon.width: Theme.iconSizeLarge
                        icon.height: Theme.iconSizeLarge
                        width: parent.width
                        height: parent.height
                        onClicked: SpeechRecognizer.cancel()
                    }
                }

                Rectangle {
                    width: Theme.itemSizeExtraLarge * 1.2
                    height: Theme.itemSizeExtraLarge * 1.2
                    radius: width / 2
                    color: Theme.highlightColor
                    opacity: (SpeechRecognizer.recording && !SpeechRecognizer.finalizing) ? 0.7 : 0.3
                    visible: SpeechRecognizer.recording

                    IconButton {
                        anchors.centerIn: parent
                        icon.source: SpeechRecognizer.paused ? "image://theme/icon-m-play"
                                                             : "image://theme/icon-m-pause"
                        icon.width: Theme.iconSizeLarge
                        icon.height: Theme.iconSizeLarge
                        width: parent.width
                        height: parent.height
                        enabled: SpeechRecognizer.recording && !SpeechRecognizer.finalizing
                        onClicked: {
                            if (SpeechRecognizer.paused) {
                                SpeechRecognizer.resume()
                            } else {
                                SpeechRecognizer.pause()
                            }
                        }
                    }
                }

                Rectangle {
                    width: Theme.itemSizeExtraLarge * 1.2
                    height: Theme.itemSizeExtraLarge * 1.2
                    radius: width / 2
                    color: SpeechRecognizer.recording ? Theme.errorColor : Theme.highlightColor
                    opacity: (SpeechRecognizer.modelReady && !SpeechRecognizer.finalizing) ? 1.0 : 0.4
                    visible: !SpeechRecognizer.finalizing

                    IconButton {
                        anchors.centerIn: parent
                        icon.source: SpeechRecognizer.recording ? "image://theme/icon-m-stop"
                                                           : "image://theme/icon-m-mic"
                        icon.width: Theme.iconSizeLarge
                        icon.height: Theme.iconSizeLarge
                        width: parent.width
                        height: parent.height
                        enabled: SpeechRecognizer.modelReady && !SpeechRecognizer.finalizing
                        onClicked: {
                            if (SpeechRecognizer.recording) {
                                SpeechRecognizer.stop()
                            } else {
                                SpeechRecognizer.start()
                            }
                        }
                    }
                }
            }

            Item { width: 1; height: Theme.paddingMedium }

            Label {
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width - 2 * Theme.horizontalPageMargin
                text: {
                    if (SpeechRecognizer.loading) return qsTr("Загрузка модели распознавания...")
                    if (!SpeechRecognizer.modelReady) return qsTr("Модель распознавания недоступна")
                    if (SpeechRecognizer.recording) return qsTr("Нажмите стоп, чтобы завершить запись")
                    if (SpeechRecognizer.finalizing) return qsTr("Ожидайте завершения расшифровки")
                    return qsTr("Нажмите на микрофон, чтобы начать запись")
                }
                color: Theme.secondaryColor
                font.pixelSize: Theme.fontSizeExtraSmall
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
            }
        }

        VerticalScrollDecorator {}
    }

    Notification {
        id: statusNotification
    }
}
