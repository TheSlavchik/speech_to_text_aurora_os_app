import QtQuick 2.0
import Sailfish.Silica 1.0
import QtMultimedia 5.6
import Nemo.Notifications 1.0
import ru.omstu.voicenotes 1.0
import "../Database.js" as Db

Page {
    id: noteViewPage
    objectName: "noteViewPage"
    allowedOrientations: Orientation.All

    property int noteId: -1
    property string noteTitle: ""
    property string noteDate: ""
    property string noteText: ""
    property string noteDuration: ""
    property string noteAudio: ""

    function formatTime(seconds) {
        var s = Math.floor(seconds)
        var min = Math.floor(s / 60)
        var sec = s % 60
        return (min < 10 ? "0" : "") + min + ":" + (sec < 10 ? "0" : "") + sec
    }

    function sanitizeFileName(name) {
        var clean = name.replace(/[^0-9A-Za-zА-Яа-яЁё _-]/g, "_")
        if (clean.length === 0) {
            clean = "note"
        }
        return clean
    }

    function exportToFile() {
        try {
            var dir = StandardPaths.documents
            var path = dir.toString().replace(/^file:\/\//, "")
            var fileName = sanitizeFileName(noteTitle) + ".txt"
            var fullPath = path + "/" + fileName
            var content = noteTitle + "\n" + noteDate + "\n\n" + noteText

            var ok = SpeechRecognizer.saveTextToFile("file://" + fullPath, content)
            if (ok) {
                notificationPanel.previewBody = qsTr("Текст сохранён: %1").arg(fullPath)
            } else {
                notificationPanel.previewBody = qsTr("Не удалось сохранить файл")
            }
            notificationPanel.publish()
        } catch (e) {
            notificationPanel.previewBody = qsTr("Не удалось сохранить файл")
            notificationPanel.publish()
        }
    }

    function copyToClipboard() {
        Clipboard.text = noteText
        notificationPanel.previewBody = qsTr("Текст скопирован в буфер обмена")
        notificationPanel.publish()
    }

    Audio {
        id: audioPlayer
        source: noteAudio
        autoLoad: true
    }

    // --- Фоновая область для закрытия меню при клике мимо него ---
    MouseArea {
        id: menuDismissArea
        anchors.fill: parent
        visible: dropdownMenu.visible
        z: 99
        onClicked: dropdownMenu.visible = false
    }

    // --- Фиксированная верхняя панель вместо старого PageHeader ---
    Item {
        id: topBar
        width: parent.width
        height: Theme.itemSizeMedium
        anchors.top: parent.top
        z: 100

        IconButton {
            id: menuButton
            anchors {
                right: parent.right
                verticalCenter: parent.verticalCenter
                rightMargin: Theme.horizontalPageMargin
            }
            icon.source: "image://theme/icon-m-more"
            onClicked: dropdownMenu.visible = !dropdownMenu.visible
        }
    }

    // --- Кастомное выпадающее меню на три точки ---
    Rectangle {
        id: dropdownMenu
        visible: false
        z: 101
        width: Theme.itemSizeLarge * 3.5
        height: menuColumn.height + Theme.paddingMedium * 2
        color: Theme.overlayBackgroundColor // Специальный цвет темы для перекрывающих меню
        radius: 12
        border.color: Theme.rgba(Theme.secondaryColor, 0.3) // Рамка по всему периметру
        border.width: 1

        anchors {
            top: topBar.bottom
            right: parent.right
            rightMargin: Theme.horizontalPageMargin
        }

        Column {
            id: menuColumn
            width: parent.width
            anchors.centerIn: parent

            BackgroundItem {
                width: parent.width
                height: Theme.itemSizeSmall
                onClicked: {
                    dropdownMenu.visible = false
                    copyToClipboard()
                }
                Label {
                    anchors {
                        left: parent.left
                        leftMargin: Theme.paddingLarge
                        verticalCenter: parent.verticalCenter
                    }
                    text: qsTr("Копировать текст")
                    color: parent.down ? Theme.highlightColor : Theme.primaryColor
                    font.pixelSize: Theme.fontSizeSmall
                }
            }

            BackgroundItem {
                width: parent.width
                height: Theme.itemSizeSmall
                onClicked: {
                    dropdownMenu.visible = false
                    exportToFile()
                }
                Label {
                    anchors {
                        left: parent.left
                        leftMargin: Theme.paddingLarge
                        verticalCenter: parent.verticalCenter
                    }
                    text: qsTr("Экспортировать в файл")
                    color: parent.down ? Theme.highlightColor : Theme.primaryColor
                    font.pixelSize: Theme.fontSizeSmall
                }
            }

            BackgroundItem {
                width: parent.width
                height: Theme.itemSizeSmall
                onClicked: {
                    dropdownMenu.visible = false
                    remorse.execute(qsTr("Удаление заметки"), function() {
                        if (noteId >= 0) {
                            Db.deleteNote(noteId)
                        }
                        pageStack.pop()
                    })
                }
                Label {
                    anchors {
                        left: parent.left
                        leftMargin: Theme.paddingLarge
                        verticalCenter: parent.verticalCenter
                    }
                    text: qsTr("Удалить заметку")
                    color: parent.down ? Theme.highlightColor : Theme.primaryColor
                    font.pixelSize: Theme.fontSizeSmall
                }
            }
        }
    }

    SilicaFlickable {
        id: flickable
        anchors.fill: parent
        contentHeight: column.height + Theme.paddingLarge

        RemorsePopup { id: remorse }

        Column {
            id: column
            width: parent.width
            spacing: Theme.paddingLarge

            // Отступ сверху, чтобы контент плавно уходил под фиксированную кнопку меню при скролле
            Item {
                width: parent.width
                height: Theme.itemSizeMedium
            }

            // --- Блок заголовка и метаданных ---
            Column {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                spacing: Theme.paddingSmall

                Label {
                    id: titleLabel
                    width: parent.width
                    text: noteTitle
                    color: Theme.highlightColor
                    font.pixelSize: Theme.fontSizeExtraLarge
                    font.weight: Font.Bold
                    wrapMode: Text.WordWrap
                }

                Row {
                    width: parent.width
                    spacing: Theme.paddingMedium

                    Label {
                        text: noteDate
                        color: Theme.secondaryColor
                        font.pixelSize: Theme.fontSizeSmall
                    }
                    Label {
                        text: "•"
                        color: Theme.secondaryColor
                        font.pixelSize: Theme.fontSizeSmall
                        visible: noteDuration !== ""
                    }
                    Label {
                        text: noteDuration
                        color: Theme.secondaryColor
                        font.pixelSize: Theme.fontSizeSmall
                        visible: noteDuration !== ""
                    }
                }
            }

            // --- Блок аудиоплеера (Карточка) ---
            Item {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                height: playerBackground.height
                visible: noteAudio !== ""

                Rectangle {
                    id: playerBackground
                    width: parent.width
                    height: playerControls.height + Theme.paddingMedium * 2
                    color: Theme.rgba(Theme.highlightBackgroundColor, 0.1)
                    radius: 12

                    Row {
                        id: playerControls
                        anchors {
                            left: parent.left
                            right: parent.right
                            verticalCenter: parent.verticalCenter
                            margins: Theme.paddingMedium
                        }
                        spacing: Theme.paddingMedium

                        IconButton {
                            id: playButton
                            icon.source: audioPlayer.playbackState === Audio.PlayingState
                                          ? "image://theme/icon-m-pause"
                                          : "image://theme/icon-m-play"
                            icon.width: Theme.iconSizeMedium
                            icon.height: Theme.iconSizeMedium
                            width: Theme.itemSizeSmall
                            height: Theme.itemSizeSmall
                            onClicked: {
                                if (audioPlayer.playbackState === Audio.PlayingState) {
                                    audioPlayer.pause()
                                } else {
                                    audioPlayer.play()
                                }
                            }
                        }

                        Item {
                            width: parent.width - playButton.width - timeLabel.width - Theme.paddingMedium * 2
                            height: Theme.itemSizeSmall
                            anchors.verticalCenter: parent.verticalCenter

                            Slider {
                                id: playbackSlider
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width
                                minimumValue: 0
                                maximumValue: audioPlayer.duration > 0 ? audioPlayer.duration : 1
                                stepSize: 1
                                enabled: audioPlayer.seekable
                                handleVisible: true

                                onDownChanged: {
                                    if (!down) {
                                        audioPlayer.seek(value)
                                    }
                                }
                            }

                            Binding {
                                target: playbackSlider
                                property: "value"
                                value: audioPlayer.position
                                when: !playbackSlider.down
                            }
                        }

                        Label {
                            id: timeLabel
                            anchors.verticalCenter: parent.verticalCenter
                            text: formatTime(audioPlayer.position / 1000)
                            color: Theme.secondaryColor
                            font.pixelSize: Theme.fontSizeExtraSmall
                        }
                    }
                }
            }

            // --- Блок текста (Расшифровка) ---
            Label {
                id: transcriptionText
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                text: noteText
                color: Theme.primaryColor
                font.pixelSize: Theme.fontSizeMedium
                wrapMode: Text.WordWrap
                textFormat: Text.PlainText
                visible: noteText !== ""
            }
        }

        VerticalScrollDecorator {}
    }

    Component.onDestruction: audioPlayer.stop()

    Notification {
        id: notificationPanel
    }
}
