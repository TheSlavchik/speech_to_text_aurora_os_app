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

    // Offline speech recognition backed by the bundled Vosk model.
    SpeechRecognizer {
        id: recognizer

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

    // Load the model once when the page is first shown.
    Component.onCompleted: recognizer.init()

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: column.height

        Column {
            id: column
            width: parent.width

            PageHeader {
                title: recognizer.recording ? qsTr("Запись") :
                       recognizer.finalizing ? qsTr("Расшифровка") :
                       recognizer.loading ? qsTr("Загрузка модели") :
                       qsTr("Готов к записи")
            }

            // Model loading indicator (model is loaded once, in background).
            Item {
                width: parent.width
                height: Theme.itemSizeExtraLarge
                visible: recognizer.loading

                BusyIndicator {
                    anchors.centerIn: parent
                    running: recognizer.loading
                    size: BusyIndicatorSize.Medium
                }
            }

            // Signal level visualization.
            Item {
                id: signalLevelContainer
                width: parent.width
                height: Theme.itemSizeExtraLarge * 2
                visible: recognizer.recording

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
                    width: Theme.itemSizeMedium + recognizer.level * Theme.itemSizeLarge
                    height: Theme.itemSizeMedium + recognizer.level * Theme.itemSizeLarge
                    radius: width / 2
                    color: recognizer.level < 0.7 ? Theme.highlightColor : Theme.errorColor
                    opacity: 0.3 + recognizer.level * 0.5
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
                text: formatTime(recognizer.durationSec)
                color: recognizer.recording ? Theme.errorColor : Theme.primaryColor
                font.pixelSize: Theme.fontSizeExtraLarge
                font.weight: Font.Light
                visible: recognizer.recording || recognizer.durationSec > 0
            }

            Item { width: 1; height: Theme.paddingLarge }

            // Live transcription (interim + accepted text).
            Item {
                width: parent.width - 2 * Theme.horizontalPageMargin
                anchors.horizontalCenter: parent.horizontalCenter
                height: liveColumn.height
                visible: recognizer.recording || recognizer.finalizing

                Column {
                    id: liveColumn
                    width: parent.width

                    Label {
                        width: parent.width
                        text: recognizer.finalizing ? qsTr("Завершаем расшифровку...")
                                                    : qsTr("Распознавание речи...")
                        color: Theme.secondaryColor
                        font.pixelSize: Theme.fontSizeSmall
                        horizontalAlignment: Text.AlignHCenter
                    }

                    Item { width: 1; height: Theme.paddingSmall }

                    ProgressBar {
                        width: parent.width
                        indeterminate: true
                        visible: recognizer.finalizing
                    }

                    Item { width: 1; height: Theme.paddingSmall }

                    Label {
                        width: parent.width
                        text: {
                            var acc = recognizer.fullText
                            var part = recognizer.partialText
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

                    Item { width: 1; height: Theme.paddingMedium }

                    Button {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: qsTr("Отменить")
                        onClicked: recognizer.cancel()
                    }
                }
            }

            Item { width: 1; height: Theme.paddingLarge }

            // Record / Stop button.
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: Theme.itemSizeExtraLarge * 1.2
                height: Theme.itemSizeExtraLarge * 1.2
                radius: width / 2
                color: recognizer.recording ? Theme.errorColor : Theme.highlightColor
                opacity: (recognizer.modelReady && !recognizer.finalizing) ? 1.0 : 0.4
                visible: !recognizer.finalizing

                IconButton {
                    anchors.centerIn: parent
                    icon.source: recognizer.recording ? "image://theme/icon-m-stop"
                                                       : "image://theme/icon-m-mic"
                    icon.width: Theme.iconSizeLarge
                    icon.height: Theme.iconSizeLarge
                    width: parent.width
                    height: parent.height
                    enabled: recognizer.modelReady && !recognizer.finalizing
                    onClicked: {
                        if (recognizer.recording) {
                            recognizer.stop()
                        } else {
                            recognizer.start()
                        }
                    }
                }
            }

            Item { width: 1; height: Theme.paddingMedium }

            Label {
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width - 2 * Theme.horizontalPageMargin
                text: {
                    if (recognizer.loading) return qsTr("Загрузка модели распознавания...")
                    if (!recognizer.modelReady) return qsTr("Модель распознавания недоступна")
                    if (recognizer.recording) return qsTr("Нажмите стоп, чтобы завершить запись")
                    if (recognizer.finalizing) return qsTr("Ожидайте завершения расшифровки")
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
