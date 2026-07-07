#include <QtQuick>
#include <QtQml>
#include <auroraapp.h>

#include "speechrecognizer.h"

int main(int argc, char *argv[])
{
    QScopedPointer<QGuiApplication> application(Aurora::Application::application(argc, argv));
    application->setOrganizationName(QStringLiteral("ru.omstu"));
    application->setApplicationName(QStringLiteral("STT"));

    qmlRegisterType<SpeechRecognizer>("ru.omstu.STT", 1, 0, "SpeechRecognizer");

    QScopedPointer<QQuickView> view(Aurora::Application::createView());
    view->setSource(Aurora::Application::pathTo(QStringLiteral("qml/STT.qml")));
    view->show();

    return application->exec();
}
