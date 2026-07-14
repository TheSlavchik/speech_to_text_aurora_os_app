import QtQuick 2.0
import Sailfish.Silica 1.0
import ru.omstu.voicenotes 1.0
import "../Database.js" as Db

Page {
    id: tagEditorPage
    objectName: "tagEditorPage"
    allowedOrientations: Orientation.All

    property var noteIds: []
    property string initialTags: ""

    Component.onCompleted: {
        tagField.text = initialTags
    }

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: column.height

        Column {
            id: column
            width: parent.width

            Item {
                width: parent.width
                height: Theme.itemSizeMedium

                Label {
                    anchors.centerIn: parent
                    text: qsTr("Выбрано: %1").arg(noteIds.length)
                    color: Theme.primaryColor
                    font.pixelSize: Theme.fontSizeSmall
                }
            }

            TextField {
                id: tagField
                width: parent.width
                placeholderText: qsTr("Введите теги через запятую")
            }

            Item { width: 1; height: Theme.paddingMedium }

            Button {
                anchors.horizontalCenter: parent.horizontalCenter
                text: qsTr("Сохранить")
                onClicked: {
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
                    pageStack.pop()
                }
            }
        }
    }
}
