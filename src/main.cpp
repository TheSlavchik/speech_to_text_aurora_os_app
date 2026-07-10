#include <QtQuick>
#include <QtQml>
#include <QDebug>
#include <auroraapp.h>

#include "speechrecognizer.h"

static QObject *recognizerSingleton(QQmlEngine *, QJSEngine *)
{
    SpeechRecognizer *r = new SpeechRecognizer();
    r->setModelPath("/usr/share/ru.omstu.voicenotes/models/vosk-model-small-ru-0.22");
    r->init();
    return r;
}

int main(int argc, char *argv[])
{
    QScopedPointer<QGuiApplication> application(Aurora::Application::application(argc, argv));
    application->setOrganizationName(QStringLiteral("ru.omstu"));
    application->setApplicationName(QStringLiteral("voicenotes"));

    qmlRegisterSingletonType<SpeechRecognizer>("ru.omstu.voicenotes", 1, 0, "SpeechRecognizer", recognizerSingleton);

    QScopedPointer<QQuickView> view(Aurora::Application::createView());
    view->setSource(Aurora::Application::pathTo(QStringLiteral("qml/voicenotes.qml")));
    view->show();

    return application->exec();
}
