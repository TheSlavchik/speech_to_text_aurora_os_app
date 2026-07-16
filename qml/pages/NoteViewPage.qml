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

    // --- Фиксированная верхняя панель ---
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

    // --- Кастомное выпадающее меню ---
    Rectangle {
        id: dropdownMenu
        visible: false
        z: 101
        width: Theme.itemSizeLarge * 3.5
        height: Math.min(menuColumn.height + Theme.paddingMedium * 2, 5 * Theme.itemSizeSmall + Theme.paddingMedium * 2)
        color: Theme.overlayBackgroundColor
        radius: 12
        border.color: Theme.rgba(Theme.secondaryColor, 0.3)
        border.width: 1
        clip: true

        anchors {
            top: topBar.bottom
            right: parent.right
            rightMargin: Theme.horizontalPageMargin
        }

        SilicaFlickable {
            anchors.fill: parent
            contentHeight: menuColumn.height + Theme.paddingMedium * 2

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
                    text: qsTr("Экспорт в файл")
                    color: parent.down ? Theme.highlightColor : Theme.primaryColor
                    font.pixelSize: Theme.fontSizeSmall
                }
            }

            BackgroundItem {
                width: parent.width
                height: Theme.itemSizeSmall
                onClicked: {
                    dropdownMenu.visible = false
                    renameDialog.open()
                }
                Label {
                    anchors {
                        left: parent.left
                        leftMargin: Theme.paddingLarge
                        verticalCenter: parent.verticalCenter
                    }
                    text: qsTr("Переименовать")
                    color: parent.down ? Theme.highlightColor : Theme.primaryColor
                    font.pixelSize: Theme.fontSizeSmall
                }
            }

            BackgroundItem {
                width: parent.width
                height: Theme.itemSizeSmall
                onClicked: {
                    dropdownMenu.visible = false
                    editTextDialog.textArea.text = noteText
                    editTextDialog.open()
                }
                Label {
                    anchors {
                        left: parent.left
                        leftMargin: Theme.paddingLarge
                        verticalCenter: parent.verticalCenter
                    }
                    text: qsTr("Редактировать")
                    color: parent.down ? Theme.highlightColor : Theme.primaryColor
                    font.pixelSize: Theme.fontSizeSmall
                }
            }

            BackgroundItem {
                width: parent.width
                height: Theme.itemSizeSmall
                onClicked: {
                    dropdownMenu.visible = false
                    Db.getNoteDetails(noteId, function(details) {
                        detailsDialog.fileName = details.fileName || ""
                        detailsDialog.filePath = details.filePath || ""
                        detailsDialog.fileSize = details.fileSize || ""
                        detailsDialog.fileDuration = details.duration || ""
                        detailsDialog.fileType = details.type || ""
                        detailsDialog.created = details.created || ""
                        detailsDialog.modified = details.modified || ""
                        detailsDialog.fileTags = details.tags || ""
                        detailsDialog.open()
                    })
                }
                Label {
                    anchors {
                        left: parent.left
                        leftMargin: Theme.paddingLarge
                        verticalCenter: parent.verticalCenter
                    }
                    text: qsTr("Подробности")
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
                    text: qsTr("Удалить")
                    color: parent.down ? Theme.highlightColor : Theme.primaryColor
                    font.pixelSize: Theme.fontSizeSmall
                }
            }
        }
        }
    }

    // --- Диалог переименования ---
    Dialog {
        id: renameDialog
        property alias nameField: nameField
        allowedOrientations: Orientation.All
        Column {
            width: parent.width
            spacing: Theme.paddingMedium

            // Кастомный заголовок с иконками
            Item {
                width: parent.width
                height: Theme.itemSizeMedium

                IconButton {
                    id: cancelRenameButton
                    anchors { left: parent.left; leftMargin: Theme.paddingMedium; verticalCenter: parent.verticalCenter }
                    icon.source: "image://theme/icon-m-close"
                    onClicked: renameDialog.reject()
                }

                Label {
                    anchors { horizontalCenter: parent.horizontalCenter; verticalCenter: parent.verticalCenter }
                    text: qsTr("Переименовать")
                    color: Theme.primaryColor
                    font.pixelSize: Theme.fontSizeMedium
                }

                IconButton {
                    id: confirmRenameButton
                    anchors { right: parent.right; rightMargin: Theme.paddingMedium; verticalCenter: parent.verticalCenter }
                    icon.source: "image://theme/icon-m-acknowledge"
                    enabled: nameField.text.trim().length > 0
                    onClicked: {
                        if (nameField.text.trim().length > 0 && noteId >= 0) {
                            Db.updateNoteTitle(noteId, nameField.text.trim())
                            noteTitle = nameField.text.trim()
                            renameDialog.accept()
                        }
                    }
                }
            }

            TextField {
                id: nameField
                width: parent.width
                placeholderText: qsTr("Название заметки")
                text: noteTitle
            }
        }
        onAccepted: {
            if (nameField.text.trim().length > 0 && noteId >= 0) {
                Db.updateNoteTitle(noteId, nameField.text.trim())
                noteTitle = nameField.text.trim()
            }
        }
    }

    // --- Диалог редактирования текста ---
    Dialog {
        id: editTextDialog
        property alias textArea: textArea
        allowedOrientations: Orientation.All
        Column {
            width: parent.width
            spacing: Theme.paddingMedium

            // Кастомный заголовок с иконками
            Item {
                width: parent.width
                height: Theme.itemSizeMedium

                IconButton {
                    id: cancelEditButton
                    anchors { left: parent.left; leftMargin: Theme.paddingMedium; verticalCenter: parent.verticalCenter }
                    icon.source: "image://theme/icon-m-close"
                    onClicked: editTextDialog.reject()
                }

                Label {
                    anchors { horizontalCenter: parent.horizontalCenter; verticalCenter: parent.verticalCenter }
                    text: qsTr("Редактировать")
                    color: Theme.primaryColor
                    font.pixelSize: Theme.fontSizeMedium
                }

                IconButton {
                    id: saveEditButton
                    anchors { right: parent.right; rightMargin: Theme.paddingMedium; verticalCenter: parent.verticalCenter }
                    icon.source: "image://theme/icon-m-acknowledge"
                    onClicked: {
                        if (noteId >= 0) {
                            Db.updateNoteText(noteId, textArea.text)
                            noteText = textArea.text
                            editTextDialog.accept()
                        }
                    }
                }
            }

            TextArea {
                id: textArea
                width: parent.width
                height: pageStack.currentPage.height * 0.6
                text: noteText
            }
        }
        onAccepted: {
            if (noteId >= 0) {
                Db.updateNoteText(noteId, textArea.text)
                noteText = textArea.text
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

    // --- Диалог подробностей ---
    Dialog {
        id: detailsDialog
        allowedOrientations: Orientation.All

        property string fileName: ""
        property string filePath: ""
        property string fileSize: ""
        property string fileDuration: ""
        property string fileType: ""
        property string created: ""
        property string modified: ""
        property string fileTags: ""

        Column {
            width: parent.width
            spacing: Theme.paddingMedium

            Item {
                width: parent.width
                height: Theme.itemSizeMedium

                Label {
                    anchors.centerIn: parent
                    text: qsTr("Подробности")
                    color: Theme.primaryColor
                    font.pixelSize: Theme.fontSizeMedium
                }
            }

            Item { width: 1; height: Theme.paddingSmall }

            Column {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                spacing: Theme.paddingMedium

                Item {
                    width: parent.width; height: detailColumn.height
                    Column {
                        id: detailColumn
                        width: parent.width; spacing: 2
                        Label { text: qsTr("Имя файла"); color: Theme.secondaryColor; font.pixelSize: Theme.fontSizeSmall }
                        Label { text: detailsDialog.fileName; color: Theme.primaryColor; font.pixelSize: Theme.fontSizeSmall; wrapMode: Text.WordWrap }
                    }
                }
                Item {
                    width: parent.width; height: detailColumn2.height
                    Column {
                        id: detailColumn2
                        width: parent.width; spacing: 2
                        Label { text: qsTr("Путь"); color: Theme.secondaryColor; font.pixelSize: Theme.fontSizeSmall }
                        Label { text: detailsDialog.filePath; color: Theme.primaryColor; font.pixelSize: Theme.fontSizeSmall; wrapMode: Text.WordWrap }
                    }
                }
                Item {
                    width: parent.width; height: detailColumn3.height
                    Column {
                        id: detailColumn3
                        width: parent.width; spacing: 2
                        Label { text: qsTr("Размер"); color: Theme.secondaryColor; font.pixelSize: Theme.fontSizeSmall }
                        Label { text: detailsDialog.fileSize; color: Theme.primaryColor; font.pixelSize: Theme.fontSizeSmall }
                    }
                }
                Item {
                    width: parent.width; height: detailColumn4.height
                    Column {
                        id: detailColumn4
                        width: parent.width; spacing: 2
                        Label { text: qsTr("Продолжительность"); color: Theme.secondaryColor; font.pixelSize: Theme.fontSizeSmall }
                        Label { text: detailsDialog.fileDuration; color: Theme.primaryColor; font.pixelSize: Theme.fontSizeSmall }
                    }
                }
                Item {
                    width: parent.width; height: detailColumn5.height
                    Column {
                        id: detailColumn5
                        width: parent.width; spacing: 2
                        Label { text: qsTr("Тип"); color: Theme.secondaryColor; font.pixelSize: Theme.fontSizeSmall }
                        Label { text: detailsDialog.fileType; color: Theme.primaryColor; font.pixelSize: Theme.fontSizeSmall }
                    }
                }
                Item {
                    width: parent.width; height: detailColumn8.height
                    visible: detailsDialog.fileTags !== ""
                    Column {
                        id: detailColumn8
                        width: parent.width; spacing: 2
                        Label { text: qsTr("Теги"); color: Theme.secondaryColor; font.pixelSize: Theme.fontSizeSmall }
                        Label { text: detailsDialog.fileTags; color: Theme.primaryColor; font.pixelSize: Theme.fontSizeSmall; wrapMode: Text.WordWrap }
                    }
                }
                Item {
                    width: parent.width; height: detailColumn6.height
                    Column {
                        id: detailColumn6
                        width: parent.width; spacing: 2
                        Label { text: qsTr("Создание записи"); color: Theme.secondaryColor; font.pixelSize: Theme.fontSizeSmall }
                        Label { text: detailsDialog.created; color: Theme.primaryColor; font.pixelSize: Theme.fontSizeSmall }
                    }
                }
                Item {
                    width: parent.width; height: detailColumn7.height
                    visible: detailsDialog.modified !== ""
                    Column {
                        id: detailColumn7
                        width: parent.width; spacing: 2
                        Label { text: qsTr("Изменение заметки"); color: Theme.secondaryColor; font.pixelSize: Theme.fontSizeSmall }
                        Label { text: detailsDialog.modified; color: Theme.primaryColor; font.pixelSize: Theme.fontSizeSmall }
                    }
                }
            }
        }
    }

    Component.onDestruction: audioPlayer.stop()

    Notification {
        id: notificationPanel
    }
}
