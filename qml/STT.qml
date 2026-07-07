import QtQuick 2.0
import Sailfish.Silica 1.0
import ru.omstu.STT 1.0

ApplicationWindow {
    id: appWindow
    objectName: "applicationWindow"
    initialPage: Qt.resolvedUrl("pages/MainPage.qml")
    cover: Qt.resolvedUrl("cover/DefaultCoverPage.qml")
    allowedOrientations: defaultAllowedOrientations

    // Single global recognizer shared by RecordingPage and the cover
    SpeechRecognizer {
        id: globalRecognizer
        modelPath: "/usr/share/ru.omstu.STT/models/vosk-model-small-ru-0.22"
        Component.onCompleted: init()
    }
}
