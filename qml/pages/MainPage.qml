import QtQuick 2.0
import Sailfish.Silica 1.0
import Nemo.Notifications 1.0
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
    property var activeFilterTags: []
    property var filterTagList: []
    property bool searchVisible: false

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
        for (var j = 0; j < notesModel.count; j++) {
            var note = notesModel.get(j)
            // Tag filter
            if (activeFilterTags.length > 0) {
                var noteTags = (note.tags || "").split("|")
                var found = false
                for (var i = 0; i < activeFilterTags.length; i++) {
                    if (noteTags.indexOf(activeFilterTags[i]) >= 0) {
                        found = true
                        break
                    }
                }
                if (!found) continue
            }
            // Text search
            if (query !== "") {
                var lowerQuery = query.toLowerCase()
                if (note.title.toLowerCase().indexOf(lowerQuery) === -1 &&
                    note.text.toLowerCase().indexOf(lowerQuery) === -1) {
                    continue
                }
            }
            filteredModel.append(note)
        }
    }

    function reloadNotes() {
        Db.loadNotes(notesModel, sortField, sortDir)
        filterTagList = Db.getAllTags()
        // Remove filter tags that no longer exist
        for (var i = activeFilterTags.length - 1; i >= 0; i--) {
            if (filterTagList.indexOf(activeFilterTags[i]) < 0) {
                activeFilterTags.splice(i, 1)
            }
        }
        filterNotes(searchField.text)
    }

    function openFilterMenu() {
        var btn = selectionMode ? filterTagButton2 : filterTagButton
        var pos = btn.mapToItem(mainPage, 0, 0)
        filterTagMenu.y = selectionMode ? mainPage.height - bottomBar.height - filterTagMenu.height : normalHeader.height
        filterTagMenu.x = Math.max(0, pos.x + btn.width - filterTagMenu.width)
        filterTagMenu.visible = true
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
        sortMenu.y = selectionMode ? mainPage.height - bottomBar.height - (4 * Theme.itemSizeSmall + Theme.paddingMedium * 2) : normalHeader.height
        sortMenu.x = Math.max(0, pos.x + btn.width - sortMenu.width)
        sortMenu.visible = true
    }

    function repositionMenus() {
        if (sortMenu.visible) openSortMenu()
        if (filterTagMenu.visible) openFilterMenu()
        if (moreMenu.visible) {
            var btn = selectionMode ? moreHeaderButton2 : moreHeaderButton
            var pos = btn.mapToItem(mainPage, 0, 0)
            moreMenu.y = selectionMode ? mainPage.height - bottomBar.height - (2 * Theme.itemSizeSmall + Theme.paddingMedium * 2) : normalHeader.height
            moreMenu.x = Math.max(0, pos.x + btn.width - moreMenu.width)
        }
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

    onWidthChanged: repositionMenus()
    onHeightChanged: repositionMenus()

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
                
                // Custom header with icon buttons
                Item {
                    width: parent.width
                    height: Theme.itemSizeMedium
                    
                    IconButton {
                        id: cancelRenameButton
                        anchors { left: parent.left; leftMargin: Theme.paddingMedium; verticalCenter: parent.verticalCenter }
                        icon.source: "image://theme/icon-m-close"
                        onClicked: {
                            renameDialogComponent.reject()
                        }
                    }
                    
                    Label {
                        anchors { horizontalCenter: parent.horizontalCenter; verticalCenter: parent.verticalCenter }
                        text: qsTr("Переименовать заметку")
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
                                exitSelectionMode()
                                reloadNotes()
                                renameDialogComponent.accept()
                            }
                        }
                    }
                }
                
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

    // --- Filter tag dropdown menu ---
    Rectangle {
        id: filterTagMenu
        visible: false
        z: 101
        width: Theme.itemSizeLarge * 3
        height: Math.min(5 * Theme.itemSizeSmall + Theme.paddingMedium * 2, filterTagColumn.implicitHeight + Theme.paddingMedium * 2)
        color: Theme.overlayBackgroundColor
        radius: 12
        border.color: Theme.rgba(Theme.secondaryColor, 0.3)
        border.width: 1
        clip: true

        SilicaFlickable {
            anchors.fill: parent
            contentHeight: filterTagColumn.height + Theme.paddingMedium * 2

            Column {
                id: filterTagColumn
                width: parent.width
                anchors.centerIn: parent

                BackgroundItem {
                    width: parent.width
                    height: Theme.itemSizeSmall
                    onClicked: {
                        activeFilterTags = []
                        filterNotes(searchField.text)
                        filterTagMenu.visible = false
                    }
                    Label {
                        anchors { left: parent.left; leftMargin: Theme.paddingLarge; verticalCenter: parent.verticalCenter }
                        text: qsTr("Все заметки")
                        color: activeFilterTags.length === 0 ? Theme.highlightColor : Theme.primaryColor
                        font.pixelSize: Theme.fontSizeSmall
                    }
                }

                Repeater {
                    model: filterTagList
                    BackgroundItem {
                        width: parent.width
                        height: Theme.itemSizeSmall
                        onClicked: {
                            var idx = mainPage.activeFilterTags.indexOf(modelData)
                            if (idx >= 0) {
                                mainPage.activeFilterTags.splice(idx, 1)
                            } else {
                                mainPage.activeFilterTags.push(modelData)
                            }
                            mainPage.activeFilterTagsChanged()
                            filterNotes(searchField.text)
                        }
                        Label {
                            width: parent.width - 2 * Theme.paddingLarge
                            anchors.verticalCenter: parent.verticalCenter
                            x: Theme.paddingLarge
                            text: modelData
                            color: mainPage.activeFilterTags.indexOf(modelData) >= 0 ? Theme.highlightColor : Theme.primaryColor
                            font.pixelSize: Theme.fontSizeSmall
                            elide: Text.ElideRight
                        }
                    }
                }
            }
        }
    }

    // Background MouseArea to dismiss filter tag menu
    MouseArea {
        id: filterTagMenuDismiss
        anchors.fill: parent
        visible: filterTagMenu.visible
        z: 100
        onClicked: filterTagMenu.visible = false
    }

    // --- More dropdown menu ---
    Rectangle {
        id: moreMenu
        visible: false
        z: 101
        width: Theme.itemSizeLarge * 3
        height: moreColumn.height + Theme.paddingMedium * 2
        color: Theme.overlayBackgroundColor
        radius: 12
        border.color: Theme.rgba(Theme.secondaryColor, 0.3)
        border.width: 1

        Column {
            id: moreColumn
            width: parent.width
            anchors.centerIn: parent

            BackgroundItem {
                width: parent.width
                height: Theme.itemSizeSmall
                onClicked: {
                    moreMenu.visible = false
                    pageStack.push(Qt.resolvedUrl("AboutPage.qml"))
                }
                Label {
                    anchors { left: parent.left; leftMargin: Theme.paddingLarge; verticalCenter: parent.verticalCenter }
                    text: qsTr("О программе")
                    color: parent.down ? Theme.highlightColor : Theme.primaryColor
                    font.pixelSize: Theme.fontSizeSmall
                }
            }

            BackgroundItem {
                width: parent.width
                height: Theme.itemSizeSmall
                visible: selectionMode
                onClicked: {
                    moreMenu.visible = false
                    if (mainPage.selectedIds.length === 0) return
                    var seen = {}
                    var unique = []
                    for (var s = 0; s < mainPage.selectedIds.length; s++) {
                        var sid = mainPage.selectedIds[s]
                        for (var n = 0; n < notesModel.count; n++) {
                            var note = notesModel.get(n)
                            if (note.noteId === sid) {
                                var rawTags = (note.tags || "").split("|")
                                for (var t = 0; t < rawTags.length; t++) {
                                    var tag = rawTags[t].trim()
                                    if (tag.length > 0 && !seen[tag]) {
                                        seen[tag] = true
                                        unique.push(tag)
                                    }
                                }
                                break
                            }
                        }
                    }
                    pageStack.push(Qt.resolvedUrl("TagEditorPage.qml"), { "noteIds": mainPage.selectedIds.slice(), "initialTags": unique.join(", ") })
                }
                Label {
                    anchors { left: parent.left; leftMargin: Theme.paddingLarge; verticalCenter: parent.verticalCenter }
                    text: qsTr("Изменение тегов")
                    color: mainPage.selectedIds.length > 0 ? (parent.down ? Theme.highlightColor : Theme.primaryColor) : Theme.secondaryColor
                    font.pixelSize: Theme.fontSizeSmall
                }
            }
        }
    }

    // Background MouseArea to dismiss more menu
    MouseArea {
        id: moreMenuDismiss
        anchors.fill: parent
        visible: moreMenu.visible
        z: 100
        onClicked: moreMenu.visible = false
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
            opacity: 0.5
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
            id: filterTagButton
            anchors { right: sortButton.left; rightMargin: Theme.paddingSmall; verticalCenter: parent.verticalCenter }
            width: Theme.iconSizeMedium
            height: Theme.iconSizeMedium
            icon.source: "image://theme/icon-m-filter"
            icon.color: activeFilterTags.length > 0 ? Theme.highlightColor : Theme.secondaryColor
            onClicked: mainPage.openFilterMenu()
        }



        IconButton {
            id: searchHeaderButton
            anchors { right: moreHeaderButton.left; rightMargin: Theme.paddingSmall; verticalCenter: parent.verticalCenter }
            icon.source: "image://theme/icon-m-search"
            icon.color: searchField.text.length > 0 ? Theme.highlightColor : Theme.secondaryColor
            onClicked: {
                searchVisible = !searchVisible
                if (!searchVisible) searchField.focus = false
            }
        }

        IconButton {
            id: moreHeaderButton
            anchors { right: parent.right; rightMargin: Theme.paddingMedium; verticalCenter: parent.verticalCenter }
            width: Theme.iconSizeMedium
            height: Theme.iconSizeMedium
            icon.source: "image://theme/icon-m-more"
            onClicked: {
                var pos = moreHeaderButton.mapToItem(mainPage, 0, 0)
                moreMenu.y = normalHeader.height
                moreMenu.x = Math.max(0, pos.x + moreHeaderButton.width - moreMenu.width)
                moreMenu.visible = !moreMenu.visible
            }
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
            opacity: 0.5
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
        height: searchVisible ? Theme.itemSizeMedium : 0
        color: "transparent"
        visible: true
        z: 10
        clip: true

        Rectangle {
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
            height: 1
            color: Theme.secondaryColor
            opacity: 0.5
        }

        IconButton {
            id: clearSearchButton
            anchors { left: parent.left; leftMargin: Theme.paddingSmall; verticalCenter: parent.verticalCenter }
            visible: searchVisible
            icon.source: "image://theme/icon-m-clear"
            enabled: searchField.text.length > 0
            opacity: enabled ? 1.0 : 0.4
            onClicked: searchField.text = ""
        }

        Item {
            anchors { left: clearSearchButton.right; leftMargin: Theme.paddingSmall; right: parent.right; rightMargin: Theme.paddingMedium; top: parent.top; bottom: parent.bottom }
            visible: searchVisible
            clip: true

            TextField {
                id: searchField
                anchors { left: parent.left; right: parent.right; top: parent.top; bottom: parent.bottom; bottomMargin: -2 * Theme.paddingLarge; topMargin: Theme.paddingLarge }
                placeholderText: qsTr("Поиск по заметкам...")
                onTextChanged: filterNotes(text)
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
                    text: searchField.text.length > 0 ? qsTr("Нет совпадений") : qsTr("Нет заметок")
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
            opacity: 0.5
        }

        // Order right to left: More, Delete, Rename, Search, Sort
        IconButton {
            id: moreHeaderButton2
            anchors { right: parent.right; rightMargin: Theme.paddingMedium; verticalCenter: parent.verticalCenter }
            width: Theme.iconSizeMedium
            height: Theme.iconSizeMedium
            icon.source: "image://theme/icon-m-more"
            onClicked: {
                var pos = moreHeaderButton2.mapToItem(mainPage, 0, 0)
                moreMenu.y = mainPage.height - bottomBar.height - (2 * Theme.itemSizeSmall + Theme.paddingMedium * 2)
                moreMenu.x = Math.max(0, pos.x + moreHeaderButton2.width - moreMenu.width)
                moreMenu.visible = !moreMenu.visible
            }
        }

        BackgroundItem {
            id: deleteButton
            anchors { right: moreHeaderButton2.left; rightMargin: Theme.paddingMedium; verticalCenter: parent.verticalCenter }
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

        IconButton {
            id: searchHeaderButton2
            anchors { right: renameButton.left; rightMargin: Theme.paddingMedium; verticalCenter: parent.verticalCenter }
            width: Theme.iconSizeMedium
            height: Theme.iconSizeMedium
            icon.source: "image://theme/icon-m-search"
            icon.color: searchField.text.length > 0 ? Theme.highlightColor : Theme.secondaryColor
            onClicked: {
                searchVisible = !searchVisible
                if (!searchVisible) searchField.focus = false
            }
        }

        IconButton {
            id: sortButton2
            anchors { right: searchHeaderButton2.left; rightMargin: Theme.paddingSmall; verticalCenter: parent.verticalCenter }
            width: Theme.iconSizeMedium
            height: Theme.iconSizeMedium
            icon.source: "image://theme/icon-m-down"
            onClicked: mainPage.openSortMenu()
        }

        IconButton {
            id: filterTagButton2
            anchors { right: sortButton2.left; rightMargin: Theme.paddingSmall; verticalCenter: parent.verticalCenter }
            width: Theme.iconSizeMedium
            height: Theme.iconSizeMedium
            icon.source: "image://theme/icon-m-filter"
            icon.color: activeFilterTags.length > 0 ? Theme.highlightColor : Theme.secondaryColor
            onClicked: mainPage.openFilterMenu()
        }
    }

    RemorseItem { id: remorseDelete; width: parent.width; height: Theme.itemSizeMedium }

    Component {
        id: headerComponent
        Item { width: parent.width; height: filteredModel.count > 0 ? -1 : 0 }
    }

    Component {
        id: noteDelegate
        BackgroundItem {
            id: delegateItem
            width: parent.width
            height: noteColumn.height + 2 * Theme.paddingMedium
            RemorseItem { id: remorse }

            // Top separator line (only for first note)
            Rectangle {
                anchors { left: parent.left; right: parent.right; top: parent.top }
                height: 1
                color: Theme.secondaryColor
                opacity: 0.3
                visible: index === 0
            }

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

                // Tags
                Flow {
                    width: parent.width
                    spacing: Theme.paddingSmall
                    visible: tags && tags.length > 0
                    Repeater {
                        model: tags.split("|")
                        Rectangle {
                            width: Math.min(tagLabel.implicitWidth + Theme.paddingMedium, parent.width - Theme.paddingSmall)
                            height: tagLabel.implicitHeight + Theme.paddingSmall
                            radius: Theme.paddingSmall
                            color: Theme.rgba(Theme.highlightColor, 0.15)
                            border.color: Theme.highlightColor
                            border.width: 1
                            Label {
                                id: tagLabel
                                anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; margins: Theme.paddingSmall }
                                text: modelData
                                color: Theme.highlightColor
                                font.pixelSize: Theme.fontSizeExtraSmall
                                elide: Text.ElideRight
                                maximumLineCount: 1
                            }
                        }
                    }
                }

                Item { width: 1; height: Theme.paddingSmall }

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
                    visible: preview.length > 0
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

            // Separator line
            Rectangle {
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                height: 1
                color: Theme.secondaryColor
                opacity: 0.3
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

    // --- Tag editor dialog ---
    Dialog {
        id: tagEditorDialog
        property var noteIds: []
        allowedOrientations: Orientation.All
        z: 100
        Column {
            width: parent.width
            spacing: Theme.paddingMedium
            DialogHeader { title: qsTr("Теги") }
            TextField {
                id: tagField
                width: parent.width
                placeholderText: qsTr("Введите теги через запятую")
            }
        }
        onAccepted: {
            var tags = tagField.text.split(",").map(function(s) { return s.trim() }).filter(function(s) { return s.length > 0 })
            for (var i = 0; i < noteIds.length; i++) {
                Db.updateNoteTags(noteIds[i], tags)
            }
            reloadNotes()
            exitSelectionMode()
        }
    }

    Notification {
        id: notificationPanel
    }
}
