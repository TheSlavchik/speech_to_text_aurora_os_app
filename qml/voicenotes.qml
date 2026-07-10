import QtQuick 2.0
import Sailfish.Silica 1.0
import ru.omstu.voicenotes 1.0
import "Database.js" as Db

ApplicationWindow {
    id: appWindow
    objectName: "applicationWindow"
    initialPage: Qt.resolvedUrl("pages/MainPage.qml")
    cover: Qt.resolvedUrl("cover/DefaultCoverPage.qml")
    allowedOrientations: defaultAllowedOrientations

    property int lastNoteId: 0
    property var mainPage: null
    property var coverPage: null

    function formatTime(seconds) {
        var s = Math.floor(seconds)
        var min = Math.floor(s / 60)
        var sec = s % 60
        return (min < 10 ? "0" : "") + min + ":" + (sec < 10 ? "0" : "") + sec
    }

    Component.onCompleted: {
        SpeechRecognizer.init()
        // Centralised save — works regardless of which page is open.
        SpeechRecognizer.finished.connect(function(text, audioUrl, durationSec) {
            var now = new Date()
            var dateStr = Qt.formatDateTime(now, "dd.MM.yyyy hh:mm")
            var title = qsTr("Запись от %1").arg(dateStr)
            var durStr = formatTime(durationSec)
            lastNoteId = Db.addNote(title, dateStr, text, durStr, audioUrl)
            if (mainPage) mainPage.reloadNotes()
            if (coverPage) coverPage.refreshCount()
        })
    }
}
