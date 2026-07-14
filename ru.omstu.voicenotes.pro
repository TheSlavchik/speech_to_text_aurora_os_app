TARGET = ru.omstu.voicenotes

CONFIG += \
    auroraapp \
    c++11

QT += multimedia qml quick

PKGCONFIG += \

SOURCES += \
    src/main.cpp \
    src/speechrecognizer.cpp

!CONFIG(emulator) {
    SOURCES += src/voskworker.cpp
}

HEADERS += \
    src/speechrecognizer.h

!CONFIG(emulator) {
    HEADERS += src/voskworker.h
}

!CONFIG(emulator) {
    # Vosk offline speech recognition (native library based on Kaldi).
    # Place the Aurora aarch64 build of libvosk.so into vosk/lib/ before building.
    INCLUDEPATH += $$PWD/vosk
    LIBS += -L$$PWD/vosk/lib -lvosk
    QMAKE_RPATHDIR += /usr/share/$${TARGET}/lib

    # Ship libvosk.so with the package.
    vosklib.files = vosk/lib/libvosk.so
    vosklib.path = /usr/share/$${TARGET}/lib
    INSTALLS += vosklib

    # libatomic.so.1 is a runtime dependency of libvosk that is not present on the
    # Aurora device/emulator. If you drop it into vosk/lib/, it gets bundled and the
    # executable is forced to load it from our lib dir (via rpath), which also
    # satisfies libvosk's own dependency on it.
    exists($$PWD/vosk/lib/libatomic.so.1) {
        voskatomic.files = vosk/lib/libatomic.so.1
        voskatomic.path = /usr/share/$${TARGET}/lib
        INSTALLS += voskatomic
        QMAKE_LFLAGS += -L$$PWD/vosk/lib -Wl,--no-as-needed,-l:libatomic.so.1 -Wl,--as-needed
    }

    # Ship the Vosk model directory (unpack the model into models/ first).
    voskmodel.files = models/vosk-model-small-ru-0.22
    voskmodel.path = /usr/share/$${TARGET}/models
    INSTALLS += voskmodel

    # Ship sailjail config
    sailjail.files = vosk/sailjail/$${TARGET}.conf
    sailjail.path = /usr/share/sailjail/config
    INSTALLS += sailjail
}

# QML files are always installed
qmlfiles.files = qml
qmlfiles.path = /usr/share/$${TARGET}
INSTALLS += qmlfiles

CONFIG(emulator) {
    DEFINES += EMULATOR
}

DISTFILES += \
    rpm/ru.omstu.voicenotes.spec \
    qml/voicenotes.qml \
    qml/Database.js \
    qml/cover/DefaultCoverPage.qml \
    qml/pages/MainPage.qml \
    qml/pages/AboutPage.qml \
    qml/pages/RecordingPage.qml \
    qml/pages/NoteViewPage.qml \

AURORAAPP_ICONS = 86x86 108x108 128x128 172x172

CONFIG += auroraapp_i18n

TRANSLATIONS += \
    translations/ru.omstu.voicenotes.ts \
    translations/ru.omstu.voicenotes-ru.ts \
