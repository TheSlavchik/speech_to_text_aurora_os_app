import QtQuick 2.0
import Sailfish.Silica 1.0
import ru.omstu.voicenotes 1.0
import "../Database.js" as Db

Dialog {
    id: tagEditorPage
    objectName: "tagEditorPage"
    allowedOrientations: Orientation.All

    property var noteIds: []
    property string initialTags: ""

    Component.onCompleted: {
        tagField.text = initialTags
    }

    Column {
        width: parent.width

        Item {
            width: parent.width
            height: Theme.itemSizeMedium

            IconButton {
                id: cancelTagButton
                anchors { left: parent.left; leftMargin: Theme.paddingMedium; verticalCenter: parent.verticalCenter }
                icon.source: "image://theme/icon-m-close"
                onClicked: tagEditorPage.reject()
            }

            Label {
                anchors { horizontalCenter: parent.horizontalCenter; verticalCenter: parent.verticalCenter }
                text: qsTr("Выбрано: %1").arg(noteIds.length)
                color: Theme.primaryColor
                font.pixelSize: Theme.fontSizeSmall
            }

            IconButton {
                id: saveTagButton
                anchors { right: parent.right; rightMargin: Theme.paddingMedium; verticalCenter: parent.verticalCenter }
                icon.source: "image://theme/icon-m-acknowledge"
                enabled: tagField.text.trim().length > 0
                onClicked: tagEditorPage.accept()
            }
        }

        TextField {
            id: tagField
            width: parent.width
            placeholderText: qsTr("Введите теги через запятую")
        }
    }

    onAccepted: {
        var parts = tagField.text.split(",")
        var tags = []
        for (var k = 0; k < parts.length; k++) {
            var t = parts[k].trim()
            if (t.length > 0) {
                tags.push(t)
            }
        }
        if (tags.length > 0) {
            for (var i = 0; i < noteIds.length; i++) {
                Db.updateNoteTags(noteIds[i], tags)
            }
        }
    }
}
