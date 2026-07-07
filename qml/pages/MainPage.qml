import QtQuick 2.0
import Sailfish.Silica 1.0
import "../Database.js" as Db

Page {
    id: mainPage
    objectName: "mainPage"
    allowedOrientations: Orientation.All

    property bool modelLoaded: false
    property bool isRecording: false

    // Notes are loaded from persistent storage (SQLite).
    ListModel {
        id: notesModel
    }

    // Filtered model for search
    ListModel {
        id: filteredModel
    }

    function filterNotes(query) {
        filteredModel.clear()
        if (query === "") {
            for (var i = 0; i < notesModel.count; i++) {
                filteredModel.append(notesModel.get(i))
            }
        } else {
            var lowerQuery = query.toLowerCase()
            for (var j = 0; j < notesModel.count; j++) {
                var note = notesModel.get(j)
                if (note.title.toLowerCase().indexOf(lowerQuery) !== -1 ||
                    note.text.toLowerCase().indexOf(lowerQuery) !== -1) {
                    filteredModel.append(note)
                }
            }
        }
    }

    function reloadNotes() {
        Db.loadNotes(notesModel)
        filterNotes(searchField.text)
    }

    Component.onCompleted: {
        // No on-device model yet: mark it ready right away.
        modelLoaded = true
        reloadNotes()
    }

    onStatusChanged: {
        // Refresh the list when returning from the recording page.
        if (status === PageStatus.Active) {
            reloadNotes()
        }
    }

    SilicaFlickable {
        id: flickable
        anchors.fill: parent
        contentHeight: column.height

        Column {
            id: column
            width: parent.width

            PageHeader {
                id: pageHeader
                title: qsTr("SpeechToText")
                extraContent.children: [
                    IconButton {
                        objectName: "aboutButton"
                        icon.source: "image://theme/icon-m-about"
                        anchors.verticalCenter: parent.verticalCenter
                        onClicked: pageStack.push(Qt.resolvedUrl("AboutPage.qml"))
                    }
                ]
            }

            // Model loading indicator
            Item {
                width: parent.width
                height: modelLoaded ? 0 : modelLoadingColumn.height + Theme.paddingMedium
                visible: !modelLoaded
                clip: true

                Behavior on height { NumberAnimation { duration: 300 } }

                Column {
                    id: modelLoadingColumn
                    width: parent.width - 2 * Theme.horizontalPageMargin
                    anchors.horizontalCenter: parent.horizontalCenter

                    Item { width: 1; height: Theme.paddingSmall }

                    Label {
                        width: parent.width
                        text: qsTr("Загрузка модели распознавания речи...")
                        color: palette.secondaryColor
                        font.pixelSize: Theme.fontSizeSmall
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                    }

                    Item { width: 1; height: Theme.paddingSmall }

                    ProgressBar {
                        id: modelProgressBar
                        width: parent.width
                        indeterminate: true
                        visible: !modelLoaded
                    }
                }
            }

            // Recording indicator bar (shown when recording in background)
            Item {
                width: parent.width
                height: isRecording ? recordingBar.height + Theme.paddingSmall : 0
                visible: isRecording
                clip: true

                Behavior on height { NumberAnimation { duration: 200 } }

                Rectangle {
                    id: recordingBar
                    width: parent.width
                    height: Theme.itemSizeSmall
                    color: Theme.errorColor

                    Row {
                        anchors.centerIn: parent
                        spacing: Theme.paddingMedium

                        Rectangle {
                            id: recordingDot
                            width: Theme.paddingSmall
                            height: Theme.paddingSmall
                            radius: width / 2
                            color: "white"

                            SequentialAnimation on opacity {
                                loops: Animation.Infinite
                                PropertyAnimation { to: 0.3; duration: 600 }
                                PropertyAnimation { to: 1.0; duration: 600 }
                            }
                        }

                        Label {
                            text: qsTr("Идёт запись...")
                            color: "white"
                            font.pixelSize: Theme.fontSizeSmall
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: pageStack.push(Qt.resolvedUrl("RecordingPage.qml"))
                    }
                }
            }

            // Search field
            SearchField {
                id: searchField
                width: parent.width
                placeholderText: qsTr("Поиск по заметкам...")
                visible: false
                onTextChanged: filterNotes(text)
            }

            // Notes list
            SilicaListView {
                id: notesListView
                width: parent.width
                height: Math.max(mainPage.height - column.y - recordButton.height - Theme.paddingLarge, emptyLabel.height + Theme.paddingLarge)
                model: filteredModel
                delegate: noteDelegate
                spacing: 0
                header: headerComponent

                PullDownMenu {
                    id: pullDownMenu
                    MenuItem {
                        text: qsTr("О программе")
                        onClicked: pageStack.push(Qt.resolvedUrl("AboutPage.qml"))
                    }
                    MenuItem {
                        text: searchField.visible ? qsTr("Скрыть поиск") : qsTr("Поиск")
                        onClicked: searchField.visible = !searchField.visible
                    }
                }

                ViewPlaceholder {
                    enabled: filteredModel.count === 0
                    text: qsTr("Нет заметок")
                    hintText: qsTr("Нажмите на микрофон, чтобы начать запись")
                }
            }
        }
    }

    Component {
        id: headerComponent
        Item {
            width: parent.width
            height: Theme.paddingSmall
        }
    }

    Component {
        id: noteDelegate
        BackgroundItem {
            id: delegateItem
            width: parent.width
            height: noteColumn.height + 2 * Theme.paddingMedium

            RemorseItem { id: remorse }

            function removeNote() {
                remorse.execute(delegateItem, qsTr("Удаление заметки"), function() {
                    Db.deleteNote(noteId)
                    reloadNotes()
                })
            }

            Column {
                id: noteColumn
                x: Theme.horizontalPageMargin
                y: Theme.paddingMedium
                width: parent.width - 2 * Theme.horizontalPageMargin

                Label {
                    width: parent.width
                    text: title
                    color: delegateItem.highlighted ? Theme.highlightColor : Theme.primaryColor
                    font.pixelSize: Theme.fontSizeMedium
                    truncationMode: TruncationMode.Fade
                }

                Item { width: 1; height: Theme.paddingSmall }

                Row {
                    width: parent.width
                    spacing: Theme.paddingMedium

                    Label {
                        text: date
                        color: Theme.secondaryColor
                        font.pixelSize: Theme.fontSizeExtraSmall
                    }

                    Label {
                        text: duration
                        color: Theme.secondaryColor
                        font.pixelSize: Theme.fontSizeExtraSmall
                    }
                }

                Item { width: 1; height: Theme.paddingSmall }

                Label {
                    width: parent.width
                    text: preview
                    color: Theme.secondaryColor
                    font.pixelSize: Theme.fontSizeSmall
                    maximumLineCount: 2
                    truncationMode: TruncationMode.Elide
                    wrapMode: Text.WordWrap
                }
            }

            onClicked: {
                pageStack.push(Qt.resolvedUrl("NoteViewPage.qml"), {
                    noteId: noteId,
                    noteTitle: title,
                    noteDate: date,
                    noteText: text,
                    noteDuration: duration,
                    noteAudio: audio
                })
            }

            onPressAndHold: contextMenu.open(delegateItem)

            ContextMenu {
                id: contextMenu
                MenuItem {
                    text: qsTr("Удалить")
                    onClicked: delegateItem.removeNote()
                }
            }
        }
    }

    Label {
        id: emptyLabel
        visible: false
    }

    // Floating record button
    Rectangle {
        id: recordButton
        anchors {
            right: parent.right
            bottom: parent.bottom
            rightMargin: Theme.paddingLarge
            bottomMargin: Theme.paddingLarge
        }
        width: Theme.itemSizeLarge
        height: Theme.itemSizeLarge
        radius: width / 2
        color: Theme.highlightColor

        IconButton {
            anchors.centerIn: parent
            icon.source: "image://theme/icon-m-mic"
            icon.width: Theme.iconSizeMedium
            icon.height: Theme.iconSizeMedium
            width: parent.width
            height: parent.height
            onClicked: pageStack.push(Qt.resolvedUrl("RecordingPage.qml"))
        }
    }
}