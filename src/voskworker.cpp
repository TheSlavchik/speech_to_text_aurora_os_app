#include "voskworker.h"

#include <QDir>
#include <QJsonDocument>
#include <QJsonObject>

#include "vosk_api.h"

VoskWorker::VoskWorker(QObject *parent)
    : QObject(parent)
    , m_model(nullptr)
    , m_rec(nullptr)
{
}

VoskWorker::~VoskWorker()
{
    if (m_rec) {
        vosk_recognizer_free(m_rec);
        m_rec = nullptr;
    }
    if (m_model) {
        vosk_model_free(m_model);
        m_model = nullptr;
    }
}

QString VoskWorker::parseField(const char *json, const QString &field)
{
    if (!json) {
        return QString();
    }
    const QJsonDocument doc = QJsonDocument::fromJson(QByteArray(json));
    if (!doc.isObject()) {
        return QString();
    }
    return doc.object().value(field).toString();
}

void VoskWorker::load(const QString &modelPath, int sampleRate)
{
    // Quieten Kaldi's own logging.
    vosk_set_log_level(-1);

    if (!QDir(modelPath).exists()) {
        emit loaded(false, tr("Модель не найдена по пути: %1").arg(modelPath));
        return;
    }

    if (m_rec) {
        vosk_recognizer_free(m_rec);
        m_rec = nullptr;
    }
    if (m_model) {
        vosk_model_free(m_model);
        m_model = nullptr;
    }

    m_model = vosk_model_new(modelPath.toUtf8().constData());
    if (!m_model) {
        emit loaded(false, tr("Не удалось загрузить модель распознавания"));
        return;
    }

    m_rec = vosk_recognizer_new(m_model, static_cast<float>(sampleRate));
    if (!m_rec) {
        vosk_model_free(m_model);
        m_model = nullptr;
        emit loaded(false, tr("Не удалось создать распознаватель"));
        return;
    }

    emit loaded(true, QString());
}

void VoskWorker::feed(const QByteArray &pcm)
{
    if (!m_rec || pcm.isEmpty()) {
        return;
    }

    const int res = vosk_recognizer_accept_waveform(m_rec, pcm.constData(), pcm.size());
    if (res < 0) {
        return;
    }
    if (res == 1) {
        const QString text = parseField(vosk_recognizer_result(m_rec), QStringLiteral("text"));
        if (!text.trimmed().isEmpty()) {
            emit utterance(text);
        }
    } else {
        emit partial(parseField(vosk_recognizer_partial_result(m_rec), QStringLiteral("partial")));
    }
}

void VoskWorker::finalize()
{
    if (!m_rec) {
        emit finalUtterance(QString());
        return;
    }
    const QString text = parseField(vosk_recognizer_final_result(m_rec), QStringLiteral("text"));
    vosk_recognizer_reset(m_rec);
    emit finalUtterance(text);
}

void VoskWorker::reset()
{
    if (m_rec) {
        vosk_recognizer_reset(m_rec);
    }
}
