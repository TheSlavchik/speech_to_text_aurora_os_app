import QtQuick 2.0
import Sailfish.Silica 1.0
import ru.omstu.voicenotes 1.0
import "../Database.js" as Db

Page {
    id: mainPage
    objectName: "mainPage"
    allowedOrientations: Orientation.All

    property bool modelLoaded: false
    property bool isRecording: false
    property string sortField: "date"
    property string sortDir: "desc"

    // --- Multi-selection state ---
    property bool selectionMode: false
    property var selectedIds: []
    property bool allSelected: false

    function isSelected(noteId) {
        return selectedIds.indexOf(noteId) >= 0
    }

    function toggleSelection(noteId) {
        if (isSelected(noteId)) {
            selectedIds = selectedIds.filter(function(id) { return id !== noteId })
        } else {
            selectedIds.push(noteId)
        }
        selectedIdsChanged()
        allSelected = selectedIds.length === filteredModel.count
    }

    function enterSelectionMode(noteId) {
        selectionMode = true
        selectedIds = [noteId]
        allSelected = false
        selectedIdsChanged()
    }

    function exitSelectionMode() {
        selectionMode = false
        selectedIds = []
        allSelected = false
        selectedIdsChanged()
    }

    function selectAll() {
        if (allSelected) {
            selectedIds = []
            allSelected = false
        } else {
            selectedIds = []
            for (var i = 0; i < filteredModel.count; i++) {
                selectedIds.push(filteredModel.get(i).noteId)
            }
            allSelected = true
        }
        selectedIdsChanged()
    }

    function deleteSelected() {
        if (selectedIds.length === 0) return
        remorseDelete.execute(notesListView, qsTr("Удаление заметок"), function() {
            Db.deleteNotes(selectedIds)
            exitSelectionMode()
            reloadNotes()
        })
    }

    function renameSelected() {
        if (selectedIds.length !== 1) return
        var noteId = selectedIds[0]
        for (var j = 0; j < notesModel.count; j++) {
            var note = notesModel.get(j)
            if (note.noteId === noteId) {
                var dlg = renameDialogComponent.createObject(mainPage, { "noteId": noteId })
                dlg.nameField.text = note.title
                dlg.open()
                return
            }
        }
    }

    ListModel { id: notesModel }
    ListModel { id: filteredModel }

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
        Db.loadNotes(notesModel, sortField, sortDir)
        filterNotes(searchField.text)
    }

    function applySort(field) {
        if (sortField === field) {
            sortDir = sortDir === "asc" ? "desc" : "asc"
        } else {
            sortField = field
            sortDir = "desc"
        }
        reloadNotes()
    }

    function openSortMenu() {
        var btn = selectionMode ? sortButton2 : sortButton
        var pos = btn.mapToItem(mainPage, 0, 0)
        sortMenu.y = normalHeader.visible ? normalHeader.height : selectionHeader.height
        sortMenu.x = Math.max(0, pos.x + btn.width - sortMenu.width)
        sortMenu.visible = true
    }

    Timer {
        id: searchScrollTimer
        interval: 0
        onTriggered: {
            searchFlickable.contentX = Math.max(0, searchFlickable.contentWidth - searchFlickable.width)
        }
    }

    Component.onCompleted: {
        modelLoaded = true
        reloadNotes()
        appWindow.mainPage = mainPage
    }

    onStatusChanged: {
        if (status === PageStatus.Active) reloadNotes()
    }

    Connections {
        target: SpeechRecognizer
        onFinished: reloadNotes()
    }

    // --- Rename dialog component ---
    Component {
        id: renameDialogComponent
        Dialog {
            property int noteId: -1
            property alias nameField: nameField
            allowedOrientations: Orientation.All
            Column {
                width: parent.width
                spacing: Theme.paddingMedium
                DialogHeader { title: qsTr("Переименовать заметку") }
                TextField {
                    id: nameField
                    width: parent.width
                    placeholderText: qsTr("Название заметки")
                }
            }
            onAccepted: {
                if (nameField.text.trim().length > 0 && noteId >= 0) {
                    Db.updateNoteTitle(noteId, nameField.text.trim())
                    exitSelectionMode()
                    reloadNotes()
                }
            }
        }
    }

    // --- Sort dropdown menu ---
    Rectangle {
        id: sortMenu
        visible: false
        z: 101
        width: Theme.itemSizeLarge * 3
        height: sortColumn.height + Theme.paddingMedium * 2
        color: Theme.overlayBackgroundColor
        radius: 12
        border.color: Theme.rgba(Theme.secondaryColor, 0.3)
        border.width: 1

        Column {
            id: sortColumn
            width: parent.width
            anchors.centerIn: parent

            BackgroundItem {
                width: parent.width
                height: Theme.itemSizeSmall
                onClicked: applySort("date")
                Row {
                    anchors { fill: parent; leftMargin: Theme.paddingLarge; rightMargin: Theme.paddingLarge }
                    spacing: Theme.paddingSmall
                    Label {
                        width: parent.width - arrowLabel.width - Theme.paddingSmall
                        text: qsTr("По дате")
                        color: sortField === "date" ? Theme.highlightColor : Theme.primaryColor
                        font.pixelSize: Theme.fontSizeSmall
                        truncationMode: TruncationMode.Fade
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Label {
                        id: arrowLabel
                        text: sortField === "date" ? (sortDir === "asc" ? "▲" : "▼") : ""
                        color: Theme.secondaryColor
                        font.pixelSize: Theme.fontSizeSmall
                        anchors.verticalCenter: parent.verticalCenter
                        visible: sortField === "date"
                    }
                }
            }

            BackgroundItem {
                width: parent.width
                height: Theme.itemSizeSmall
                onClicked: applySort("title")
                Row {
                    anchors { fill: parent; leftMargin: Theme.paddingLarge; rightMargin: Theme.paddingLarge }
                    spacing: Theme.paddingSmall
                    Label {
                        width: parent.width - arrowLabel2.width - Theme.paddingSmall
                        text: qsTr("По названию")
                        color: sortField === "title" ? Theme.highlightColor : Theme.primaryColor
                        font.pixelSize: Theme.fontSizeSmall
                        truncationMode: TruncationMode.Fade
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Label {
                        id: arrowLabel2
                        text: sortField === "title" ? (sortDir === "asc" ? "▲" : "▼") : ""
                        color: Theme.secondaryColor
                        font.pixelSize: Theme.fontSizeSmall
                        anchors.verticalCenter: parent.verticalCenter
                        visible: sortField === "title"
                    }
                }
            }

            BackgroundItem {
                width: parent.width
                height: Theme.itemSizeSmall
                onClicked: applySort("duration")
                Row {
                    anchors { fill: parent; leftMargin: Theme.paddingLarge; rightMargin: Theme.paddingLarge }
                    spacing: Theme.paddingSmall
                    Label {
                        width: parent.width - arrowLabel3.width - Theme.paddingSmall
                        text: qsTr("По длительности")
                        color: sortField === "duration" ? Theme.highlightColor : Theme.primaryColor
                        font.pixelSize: Theme.fontSizeSmall
                        truncationMode: TruncationMode.Fade
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Label {
                        id: arrowLabel3
                        text: sortField === "duration" ? (sortDir === "asc" ? "▲" : "▼") : ""
                        color: Theme.secondaryColor
                        font.pixelSize: Theme.fontSizeSmall
                        anchors.verticalCenter: parent.verticalCenter
                        visible: sortField === "duration"
                    }
                }
            }

            BackgroundItem {
                width: parent.width
                height: Theme.itemSizeSmall
                onClicked: applySort("size")
                Row {
                    anchors { fill: parent; leftMargin: Theme.paddingLarge; rightMargin: Theme.paddingLarge }
                    spacing: Theme.paddingSmall
                    Label {
                        width: parent.width - arrowLabel4.width - Theme.paddingSmall
                        text: qsTr("По весу")
                        color: sortField === "size" ? Theme.highlightColor : Theme.primaryColor
                        font.pixelSize: Theme.fontSizeSmall
                        truncationMode: TruncationMode.Fade
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Label {
                        id: arrowLabel4
                        text: sortField === "size" ? (sortDir === "asc" ? "▲" : "▼") : ""
                        color: Theme.secondaryColor
                        font.pixelSize: Theme.fontSizeSmall
                        anchors.verticalCenter: parent.verticalCenter
                        visible: sortField === "size"
                    }
                }
            }
        }
    }

    // Background MouseArea to dismiss sort menu
    MouseArea {
        id: sortMenuDismiss
        anchors.fill: parent
        visible: sortMenu.visible
        z: 100
        onClicked: sortMenu.visible = false
    }

    // Normal header — fixed overlay (visible in normal mode)
    Rectangle {
        id: normalHeader
        anchors { top: parent.top; left: parent.left; right: parent.right }
        height: Theme.itemSizeMedium
        color: "transparent"
        visible: !selectionMode
        z: 10

        Rectangle {
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
            height: 1
            color: Theme.secondaryColor
            opacity: 0.3
        }

        IconButton {
            id: sortButton
            anchors { right: searchHeaderButton.left; rightMargin: Theme.paddingSmall; verticalCenter: parent.verticalCenter }
            width: Theme.iconSizeMedium
            height: Theme.iconSizeMedium
            icon.source: "image://theme/icon-m-down"
            onClicked: mainPage.openSortMenu()
        }

        IconButton {
            id: searchHeaderButton
            anchors { right: aboutHeaderButton.left; rightMargin: Theme.paddingSmall; verticalCenter: parent.verticalCenter }
            icon.source: "image://theme/icon-m-search"
            icon.color: searchField.text.length > 0 ? Theme.highlightColor : Theme.secondaryColor
            onClicked: {
                searchRow.visible = !searchRow.visible
                if (!searchRow.visible) searchField.focus = false
            }
        }

        IconButton {
            id: aboutHeaderButton
            objectName: "aboutButton"
            anchors { right: parent.right; rightMargin: Theme.paddingMedium; verticalCenter: parent.verticalCenter }
            icon.source: "image://theme/icon-m-about"
            onClicked: pageStack.push(Qt.resolvedUrl("AboutPage.qml"))
        }
    }

    // Selection mode header — fixed overlay
    Rectangle {
        id: selectionHeader
        anchors { top: parent.top; left: parent.left; right: parent.right }
        height: Theme.itemSizeMedium
        color: "transparent"
        visible: selectionMode
        z: 10

        Rectangle {
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
            height: 1
            color: Theme.secondaryColor
            opacity: 0.3
        }

        IconButton {
            id: exitSelectionButton
            anchors { left: parent.left; leftMargin: Theme.paddingMedium; verticalCenter: parent.verticalCenter }
            icon.source: "image://theme/icon-m-close"
            onClicked: exitSelectionMode()
        }

        Label {
            id: selectionLabel
            anchors { horizontalCenter: parent.horizontalCenter; verticalCenter: parent.verticalCenter }
            text: qsTr("Выбрано: %1").arg(selectedIds.length)
            color: Theme.primaryColor
            font.pixelSize: Theme.fontSizeSmall
        }

        // Search and about buttons (same as normal mode, left of select-all)
        IconButton {
            id: sortButton2
            anchors { right: searchHeaderButton2.left; rightMargin: Theme.paddingSmall; verticalCenter: parent.verticalCenter }
            width: Theme.iconSizeMedium
            height: Theme.iconSizeMedium
            icon.source: "image://theme/icon-m-down"
            onClicked: mainPage.openSortMenu()
        }

        IconButton {
            id: searchHeaderButton2
            anchors { right: aboutHeaderButton2.left; rightMargin: Theme.paddingSmall; verticalCenter: parent.verticalCenter }
            width: Theme.iconSizeMedium
            height: Theme.iconSizeMedium
            icon.source: "image://theme/icon-m-search"
            icon.color: searchField.text.length > 0 ? Theme.highlightColor : Theme.secondaryColor
            onClicked: {
                searchRow.visible = !searchRow.visible
                if (!searchRow.visible) searchField.focus = false
            }
        }

        IconButton {
            id: aboutHeaderButton2
            anchors { right: selectAllButton.left; rightMargin: Theme.paddingSmall; verticalCenter: parent.verticalCenter }
            width: Theme.iconSizeMedium
            height: Theme.iconSizeMedium
            icon.source: "image://theme/icon-m-about"
            onClicked: pageStack.push(Qt.resolvedUrl("AboutPage.qml"))
        }

        Item {
            id: selectAllButton
            anchors { right: parent.right; rightMargin: Theme.paddingMedium; verticalCenter: parent.verticalCenter }
            width: Theme.iconSizeMedium
            height: Theme.iconSizeMedium

            Rectangle {
                anchors.fill: parent
                anchors.margins: 12
                radius: width / 2
                color: "transparent"
                border.color: Theme.primaryColor
                border.width: 3
                visible: !allSelected
            }

            Image {
                anchors.fill: parent
                source: "image://theme/icon-m-acknowledge"
                visible: allSelected
            }

            MouseArea {
                anchors.fill: parent
                onClicked: selectAll()
            }
        }
    }

    // Search header — fixed overlay
    Rectangle {
        id: searchHeader
        anchors { top: normalHeader.visible ? normalHeader.bottom : selectionHeader.bottom; left: parent.left; right: parent.right }
        height: searchRow.visible ? Theme.itemSizeMedium : 0
        color: "transparent"
        visible: true
        z: 10
        clip: true

        Rectangle {
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
            height: 1
            color: Theme.secondaryColor
            opacity: 0.3
        }

        Row {
            id: searchRow
            width: parent.width
            visible: false
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.paddingSmall

            IconButton {
                id: clearSearchButton
                anchors.verticalCenter: parent.verticalCenter
                icon.source: "image://theme/icon-m-clear"
                enabled: searchField.text.length > 0
                opacity: enabled ? 1.0 : 0.4
                onClicked: searchField.text = ""
            }

            Rectangle {
                width: parent.width - clearSearchButton.width - Theme.paddingSmall
                height: Theme.itemSizeSmall
                color: "transparent"
                border.color: "transparent"
                anchors.verticalCenter: parent.verticalCenter
                clip: true

                Flickable {
                    id: searchFlickable
                    anchors.fill: parent
                    contentWidth: searchField.x + searchField.width
                    contentHeight: parent.height
                    interactive: contentWidth > width
                    boundsBehavior: Flickable.StopAtBounds

                    TextInput {
                        id: searchField
                        x: 4 * Theme.paddingSmall
                        width: Math.max(searchFlickable.width - 4 * Theme.paddingSmall, searchField.contentWidth + 3 * Theme.paddingLarge)
                        height: parent.height
                        verticalAlignment: TextInput.AlignVCenter
                        color: Theme.primaryColor
                        font.pixelSize: Theme.fontSizeMedium
                        onTextChanged: {
                            filterNotes(text)
                            if (cursorPosition === text.length) {
                                searchScrollTimer.start()
                            }
                        }
                    }
                }

                Label {
                    anchors {
                        fill: parent
                        leftMargin: 4 * Theme.paddingSmall
                    }
                    verticalAlignment: Text.AlignVCenter
                    text: qsTr("Поиск по заметкам...")
                    color: Theme.secondaryColor
                    font.pixelSize: Theme.fontSizeMedium
                    visible: searchField.text.length === 0

                    MouseArea {
                        anchors.fill: parent
                        onClicked: searchField.forceActiveFocus()
                    }
                }
            }
        }
    }

    SilicaFlickable {
        id: flickable
        anchors {
            top: searchHeader.bottom
            left: parent.left
            right: parent.right
            bottom: bottomBar.visible ? bottomBar.top : parent.bottom
        }
        boundsBehavior: Flickable.DragOverBounds
        clip: true
        contentHeight: column.height

        Column {
            id: column
            width: parent.width

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
                        color: Theme.secondaryColor
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

            // Recording indicator bar
            Item {
                width: parent.width
                height: isRecording ? recordingBar.height + Theme.paddingSmall : 0
                visible: isRecording
                clip: true
                Behavior on height { NumberAnimation { duration: 200 } }
                Rectangle {
                    id: recordingBar
                    width: parent.width; height: Theme.itemSizeSmall
                    color: Theme.errorColor
                    Row {
                        anchors.centerIn: parent; spacing: Theme.paddingMedium
                        Rectangle {
                            id: recordingDot
                            width: Theme.paddingSmall; height: Theme.paddingSmall
                            radius: width / 2; color: "white"
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

            SilicaListView {
                id: notesListView
                width: parent.width
                height: Math.max(mainPage.height - column.y - Theme.paddingLarge, emptyLabel.height + Theme.paddingLarge)
                model: filteredModel
                delegate: noteDelegate
                spacing: 0
                header: headerComponent
                footer: Item {
                    width: parent.width
                    height: recordButton.height + Theme.paddingLarge * 2
                }

                ViewPlaceholder {
                    enabled: filteredModel.count === 0
                    text: searchField.text.length > 0 ? qsTr("Ничего не найдено") : qsTr("Нет заметок")
                    hintText: searchField.text.length > 0 ? "" : qsTr("Нажмите на микрофон, чтобы начать запись")
                }
            }
        }
        VerticalScrollDecorator {}
    }

    // Bottom action bar (visible only in selection mode)
    Rectangle {
        id: bottomBar
        anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
        height: Theme.itemSizeMedium
        color: "transparent"
        visible: selectionMode
        z: 10

        Rectangle {
            anchors { left: parent.left; right: parent.right; top: parent.top }
            height: 1
            color: Theme.secondaryColor
            opacity: 0.3
        }

        BackgroundItem {
            id: deleteButton
            anchors { right: parent.right; rightMargin: Theme.paddingMedium; verticalCenter: parent.verticalCenter }
            width: Theme.iconSizeMedium
            height: Theme.iconSizeMedium
            enabled: selectedIds.length > 0
            opacity: enabled ? 1.0 : 0.4

            Image {
                anchors.centerIn: parent
                source: "image://theme/icon-m-delete"
            }

            onClicked: deleteSelected()
        }

        BackgroundItem {
            id: renameButton
            anchors { right: deleteButton.left; rightMargin: Theme.paddingMedium; verticalCenter: parent.verticalCenter }
            width: Theme.iconSizeMedium
            height: Theme.iconSizeMedium
            enabled: selectedIds.length === 1
            opacity: enabled ? 1.0 : 0.4

            Image {
                anchors.centerIn: parent
                source: "image://theme/icon-m-edit"
            }

            onClicked: renameSelected()
        }
    }

    RemorseItem { id: remorseDelete; width: parent.width; height: Theme.itemSizeMedium }

    Component {
        id: headerComponent
        Item { width: parent.width; height: Theme.paddingSmall }
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

            // Selection check-box (right)
            Item {
                id: checkBox
                anchors {
                    right: parent.right
                    rightMargin: Theme.horizontalPageMargin
                    verticalCenter: parent.verticalCenter
                }
                width: Theme.iconSizeMedium
                height: Theme.iconSizeMedium

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 12
                    radius: width / 2
                    color: "transparent"
                    border.color: Theme.secondaryColor
                    border.width: 3
                    visible: mainPage.selectionMode && !isSelected(noteId)
                }

                Image {
                    anchors.fill: parent
                    source: "image://theme/icon-m-acknowledge"
                    visible: mainPage.selectionMode && isSelected(noteId)
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        if (mainPage.selectionMode) {
                            mainPage.toggleSelection(noteId)
                        }
                    }
                }
            }

            Column {
                id: noteColumn
                x: Theme.horizontalPageMargin
                y: Theme.paddingMedium
                width: parent.width - 2 * Theme.horizontalPageMargin - Theme.iconSizeMedium - Theme.paddingMedium

                Label {
                    width: parent.width
                    text: title
                    color: delegateItem.highlighted ? Theme.highlightColor : Theme.primaryColor
                    font.pixelSize: Theme.fontSizeMedium
                    truncationMode: TruncationMode.Fade
                }
                Item { width: 1; height: Theme.paddingSmall }
                Row {
                    width: parent.width; spacing: Theme.paddingMedium
                    Label { text: date; color: Theme.secondaryColor; font.pixelSize: Theme.fontSizeExtraSmall }
                    Label { text: duration; color: Theme.secondaryColor; font.pixelSize: Theme.fontSizeExtraSmall }
                    Label { text: fileSize; color: Theme.secondaryColor; font.pixelSize: Theme.fontSizeExtraSmall }
                }
                Item { width: 1; height: Theme.paddingSmall }
                Label {
                    width: parent.width; text: preview
                    color: Theme.secondaryColor; font.pixelSize: Theme.fontSizeSmall
                    maximumLineCount: 2; truncationMode: TruncationMode.Elide; wrapMode: Text.WordWrap
                }
            }

            onClicked: {
                if (mainPage.selectionMode) {
                    mainPage.toggleSelection(noteId)
                } else {
                    pageStack.push(Qt.resolvedUrl("NoteViewPage.qml"), {
                        noteId: noteId, noteTitle: title, noteDate: date,
                        noteText: text, noteDuration: duration, noteAudio: audio
                    })
                }
            }

            onPressAndHold: {
                if (!mainPage.selectionMode) mainPage.enterSelectionMode(noteId)
            }
        }
    }

    Label { id: emptyLabel; visible: false }

    // Floating record button
    Rectangle {
        id: recordButton
        anchors {
            right: parent.right; bottom: parent.bottom
            rightMargin: Theme.paddingLarge
            bottomMargin: Theme.paddingLarge + (bottomBar.visible ? bottomBar.height : 0)
        }
        width: Theme.itemSizeLarge; height: Theme.itemSizeLarge
        radius: width / 2; color: Theme.highlightColor

        IconButton {
            anchors.centerIn: parent
            icon.source: "image://theme/icon-m-mic"
            icon.width: Theme.iconSizeMedium
            icon.height: Theme.iconSizeMedium
            width: parent.width; height: parent.height
            onClicked: pageStack.push(Qt.resolvedUrl("RecordingPage.qml"))
        }
    }
}
