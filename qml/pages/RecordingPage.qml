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
        target: globalRecognizer

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
                title: globalRecognizer.recording ? qsTr("Запись") :
                       globalRecognizer.finalizing ? qsTr("Расшифровка") :
                       globalRecognizer.loading ? qsTr("Загрузка модели") :
                       qsTr("Готов к записи")
            }

            // Model loading indicator (model is loaded once, in background).
            Item {
                width: parent.width
                height: Theme.itemSizeExtraLarge
                visible: globalRecognizer.loading

                BusyIndicator {
                    anchors.centerIn: parent
                    running: globalRecognizer.loading
                    size: BusyIndicatorSize.Medium
                }
            }

            // Signal level visualization.
            Item {
                id: signalLevelContainer
                width: parent.width
                height: Theme.itemSizeExtraLarge * 2
                visible: globalRecognizer.recording

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
                    width: Theme.itemSizeMedium + globalRecognizer.level * Theme.itemSizeLarge
                    height: Theme.itemSizeMedium + globalRecognizer.level * Theme.itemSizeLarge
                    radius: width / 2
                    color: globalRecognizer.level < 0.7 ? Theme.highlightColor : Theme.errorColor
                    opacity: 0.3 + globalRecognizer.level * 0.5
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
                text: formatTime(globalRecognizer.durationSec)
                color: globalRecognizer.recording ? Theme.errorColor : Theme.primaryColor
                font.pixelSize: Theme.fontSizeExtraLarge
                font.weight: Font.Light
                visible: globalRecognizer.recording
            }

            Item { width: 1; height: Theme.paddingLarge }

            // Live transcription (interim + accepted text).
            Item {
                width: parent.width - 2 * Theme.horizontalPageMargin
                anchors.horizontalCenter: parent.horizontalCenter
                height: liveColumn.height
                visible: globalRecognizer.recording || globalRecognizer.finalizing

                Column {
                    id: liveColumn
                    width: parent.width

                    Label {
                        width: parent.width
                        text: globalRecognizer.finalizing ? qsTr("Завершаем расшифровку...")
                                                    : qsTr("Распознавание речи...")
                        color: Theme.secondaryColor
                        font.pixelSize: Theme.fontSizeSmall
                        horizontalAlignment: Text.AlignHCenter
                    }

                    Item { width: 1; height: Theme.paddingSmall }

                    ProgressBar {
                        width: parent.width
                        indeterminate: true
                        visible: globalRecognizer.finalizing
                    }

                    Item { width: 1; height: Theme.paddingSmall }

                    Label {
                        width: parent.width
                        text: {
                            var acc = globalRecognizer.fullText
                            var part = globalRecognizer.partialText
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
                        onClicked: globalRecognizer.cancel()
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
                color: globalRecognizer.recording ? Theme.errorColor : Theme.highlightColor
                opacity: (globalRecognizer.modelReady && !globalRecognizer.finalizing) ? 1.0 : 0.4
                visible: !globalRecognizer.finalizing

                IconButton {
                    anchors.centerIn: parent
                    icon.source: globalRecognizer.recording ? "image://theme/icon-m-stop"
                                                       : "image://theme/icon-m-mic"
                    icon.width: Theme.iconSizeLarge
                    icon.height: Theme.iconSizeLarge
                    width: parent.width
                    height: parent.height
                    enabled: globalRecognizer.modelReady && !globalRecognizer.finalizing
                    onClicked: {
                        if (globalRecognizer.recording) {
                            globalRecognizer.stop()
                        } else {
                            globalRecognizer.start()
                        }
                    }
                }
            }

            Item { width: 1; height: Theme.paddingMedium }

            Label {
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width - 2 * Theme.horizontalPageMargin
                text: {
                    if (globalRecognizer.loading) return qsTr("Загрузка модели распознавания...")
                    if (!globalRecognizer.modelReady) return qsTr("Модель распознавания недоступна")
                    if (globalRecognizer.recording) return qsTr("Нажмите стоп, чтобы завершить запись")
                    if (globalRecognizer.finalizing) return qsTr("Ожидайте завершения расшифровки")
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
