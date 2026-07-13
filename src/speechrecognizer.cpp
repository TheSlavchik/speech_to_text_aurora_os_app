#include "speechrecognizer.h"
#include "voskworker.h"

#include <QAudioDeviceInfo>
#include <QAudioFormat>
#include <QAudioInput>
#include <QDataStream>
#include <QDateTime>
#include <QDebug>
#include <QDir>
#include <QFile>
#include <QIODevice>
#include <QStandardPaths>
#include <QTextStream>
#include <QUrl>
#include <QtEndian>
#include <QtMath>

namespace {
const int kSampleRate = 16000;
const int kSampleSize = 16; // bits
const int kChannels = 1;
}

SpeechRecognizer::SpeechRecognizer(QObject *parent)
    : QObject(parent)
    , m_modelPath(QStringLiteral("/usr/share/ru.omstu.voicenotes/models/vosk-model-small-ru-0.22"))
    , m_sampleRate(kSampleRate)
    , m_modelReady(false)
    , m_loading(false)
    , m_recording(false)
        , m_finalizing(false)
        , m_paused(false)
        , m_level(0.0)
    , m_durationSec(0)
    , m_cancelled(false)
    , m_audioInput(nullptr)
    , m_audioIo(nullptr)
    , m_gotAudio(false)
    , m_worker(new VoskWorker)
{
    // If capture starts but no samples ever arrive (typical on the Aurora
    // emulator, which has no real microphone), surface an error instead of
    // leaving the UI stuck at 00:00 forever.
    m_noAudioTimer.setSingleShot(true);
    m_noAudioTimer.setInterval(4000);
    connect(&m_noAudioTimer, &QTimer::timeout, this, &SpeechRecognizer::onNoAudioTimeout);

    m_worker->moveToThread(&m_thread);
    connect(&m_thread, &QThread::finished, m_worker, &QObject::deleteLater);

    connect(this, &SpeechRecognizer::requestLoad, m_worker, &VoskWorker::load);
    connect(this, &SpeechRecognizer::requestFeed, m_worker, &VoskWorker::feed);
    connect(this, &SpeechRecognizer::requestFinalize, m_worker, &VoskWorker::finalize);
    connect(this, &SpeechRecognizer::requestReset, m_worker, &VoskWorker::reset);

    connect(m_worker, &VoskWorker::loaded, this, &SpeechRecognizer::onModelLoaded);
    connect(m_worker, &VoskWorker::partial, this, &SpeechRecognizer::onPartial);
    connect(m_worker, &VoskWorker::utterance, this, &SpeechRecognizer::onUtterance);
    connect(m_worker, &VoskWorker::finalUtterance, this, &SpeechRecognizer::onFinalUtterance);

    m_thread.start();
}

SpeechRecognizer::~SpeechRecognizer()
{
    teardownAudio();
    m_thread.quit();
    m_thread.wait();
}

void SpeechRecognizer::setModelPath(const QString &path)
{
    if (m_modelPath == path) {
        return;
    }
    m_modelPath = path;
    emit modelPathChanged();
}

void SpeechRecognizer::setLoading(bool v)
{
    if (m_loading != v) { m_loading = v; emit loadingChanged(); }
}

void SpeechRecognizer::setModelReady(bool v)
{
    if (m_modelReady != v) { m_modelReady = v; emit modelReadyChanged(); }
}

void SpeechRecognizer::setRecording(bool v)
{
    if (m_recording != v) { m_recording = v; emit recordingChanged(); }
}

void SpeechRecognizer::setFinalizing(bool v)
{
    if (m_finalizing != v) { m_finalizing = v; emit finalizingChanged(); }
}

void SpeechRecognizer::setLevel(qreal v)
{
    if (!qFuzzyCompare(m_level, v)) { m_level = v; emit levelChanged(); }
}

void SpeechRecognizer::setPartialText(const QString &v)
{
    if (m_partialText != v) { m_partialText = v; emit partialTextChanged(); }
}

void SpeechRecognizer::appendText(const QString &v)
{
    const QString piece = v.trimmed();
    if (piece.isEmpty()) {
        return;
    }
    if (!m_fullText.isEmpty()) {
        m_fullText += QLatin1Char(' ');
    }
    m_fullText += piece;
    emit fullTextChanged();
}

void SpeechRecognizer::init()
{
    if (m_modelReady || m_loading) {
        return;
    }
    setLoading(true);
    emit requestLoad(m_modelPath, m_sampleRate);
}

void SpeechRecognizer::onModelLoaded(bool ok, const QString &message)
{
    setLoading(false);
    setModelReady(ok);
    if (!ok) {
        emit errorOccurred(message);
    }
}

void SpeechRecognizer::onPartial(const QString &text)
{
    if (m_recording) {
        setPartialText(text);
    }
}

void SpeechRecognizer::onUtterance(const QString &text)
{
    appendText(text);
    setPartialText(QString());
}

void SpeechRecognizer::onFinalUtterance(const QString &text)
{
    appendText(text);
    setPartialText(QString());
    setFinalizing(false);

    if (m_cancelled) {
        m_cancelled = false;
        m_pcm.clear();
        return;
    }

    QString audioUrl;
    if (!m_pcm.isEmpty()) {
        const QString path = writeWav(m_pcm);
        if (!path.isEmpty()) {
            audioUrl = QUrl::fromLocalFile(path).toString();
        }
    }
    const int dur = m_durationSec;
    m_pcm.clear();
    emit finished(m_fullText, audioUrl, dur);
}

void SpeechRecognizer::start()
{
    if (m_recording || !m_modelReady) {
        return;
    }

    m_cancelled = false;
    m_pcm.clear();
    m_fullText.clear();
    emit fullTextChanged();
    setPartialText(QString());
    m_durationSec = 0;
    emit durationSecChanged();
    emit requestReset();

    QAudioFormat format;
    format.setSampleRate(m_sampleRate);
    format.setChannelCount(kChannels);
    format.setSampleSize(kSampleSize);
    format.setCodec(QStringLiteral("audio/pcm"));
    format.setByteOrder(QAudioFormat::LittleEndian);
    format.setSampleType(QAudioFormat::SignedInt);

    QAudioDeviceInfo info = QAudioDeviceInfo::defaultInputDevice();
    if (info.isNull()) {
        emit errorOccurred(tr("Микрофон недоступен"));
        return;
    }
    if (!info.isFormatSupported(format)) {
        format = info.nearestFormat(format);
    }

    m_audioInput = new QAudioInput(info, format, this);
    m_audioIo = m_audioInput->start();
    if (!m_audioIo) {
        teardownAudio();
        emit errorOccurred(tr("Не удалось начать запись с микрофона"));
        return;
    }
    connect(m_audioIo, &QIODevice::readyRead, this, &SpeechRecognizer::onAudioDataReady);
    setLevel(0.0);
    setRecording(true);
    m_gotAudio = false;
    m_noAudioTimer.start();
}

void SpeechRecognizer::onAudioDataReady()
{
    if (!m_audioIo) {
        return;
    }
    const QByteArray data = m_audioIo->readAll();
    if (data.isEmpty()) {
        return;
    }
    m_gotAudio = true;
    m_noAudioTimer.stop();
    m_pcm.append(data);

    // Compute an RMS level for the meter and update duration.
    const int sampleCount = data.size() / 2;
    if (sampleCount > 0) {
        const qint16 *samples = reinterpret_cast<const qint16 *>(data.constData());
        qreal sumSquares = 0.0;
        for (int i = 0; i < sampleCount; ++i) {
            const qreal s = static_cast<qreal>(samples[i]) / 32768.0;
            sumSquares += s * s;
        }
        const qreal rms = qSqrt(sumSquares / sampleCount);
        // Scale up a little so normal speech fills the meter.
        setLevel(qBound<qreal>(0.0, rms * 3.0, 1.0));
    }

    const int totalSamples = m_pcm.size() / 2;
    const int dur = totalSamples / m_sampleRate;
    if (dur != m_durationSec) {
        m_durationSec = dur;
        emit durationSecChanged();
    }

    emit requestFeed(data);
}

void SpeechRecognizer::onNoAudioTimeout()
{
    if (!m_recording || m_gotAudio) {
        return;
    }
    // No PCM ever arrived from the input device.
    m_cancelled = true;
    teardownAudio();
    setRecording(false);
    setLevel(0.0);
    setPartialText(QString());
    m_pcm.clear();
    m_fullText.clear();
    emit fullTextChanged();
    emit requestReset();
    emit errorOccurred(tr("Микрофон не передаёт звук. В эмуляторе запись микрофона "
                          "обычно недоступна — проверьте на устройстве или включите "
                          "аудиовход эмулятора."));
}

void SpeechRecognizer::stop()
{
    if (!m_recording) {
        return;
    }
    m_noAudioTimer.stop();
        setPaused(false);
        // Grab any bytes still buffered before tearing the input down.
    if (m_audioIo) {
        const QByteArray tail = m_audioIo->readAll();
        if (!tail.isEmpty()) {
            m_pcm.append(tail);
            emit requestFeed(tail);
        }
    }
    teardownAudio();
    setRecording(false);
    setLevel(0.0);
    setFinalizing(true);
    // Runs after all queued feed() calls on the worker thread.
    emit requestFinalize();
}

void SpeechRecognizer::cancel()
{
    if (!m_recording && !m_finalizing) {
        return;
    }
    m_cancelled = true;
    m_noAudioTimer.stop();
    setPaused(false);
    teardownAudio();
    setRecording(false);
    setLevel(0.0);
    setPartialText(QString());
    m_pcm.clear();
    m_fullText.clear();
    emit fullTextChanged();
    if (m_finalizing) {
        // A finalize is already in flight; onFinalUtterance will honour the flag.
        return;
    }
    setFinalizing(true);
    emit requestFinalize();
}

void SpeechRecognizer::pause()
{
    if (!m_recording || m_paused)
        return;

    teardownAudio();
    setPaused(true);
}

void SpeechRecognizer::resume()
{
    if (!m_recording || !m_paused)
        return;

    QAudioFormat fmt;
    fmt.setSampleRate(m_sampleRate);
    fmt.setChannelCount(1);
    fmt.setSampleSize(16);
    fmt.setCodec("audio/pcm");
    fmt.setByteOrder(QAudioFormat::LittleEndian);
    fmt.setSampleType(QAudioFormat::SignedInt);

    QAudioDeviceInfo info = QAudioDeviceInfo::defaultInputDevice();
    if (!info.isFormatSupported(fmt)) {
        emit errorOccurred(tr("Микрофон недоступен"));
        return;
    }

    m_audioInput = new QAudioInput(info, fmt);
    m_audioIo = m_audioInput->start();
    if (!m_audioIo) {
        emit errorOccurred(tr("Не удалось начать запись с микрофона"));
        return;
    }

    connect(m_audioIo, &QIODevice::readyRead, this, &SpeechRecognizer::onAudioDataReady);
    setPaused(false);
}

void SpeechRecognizer::setPaused(bool v)
{
    if (m_paused != v) {
        m_paused = v;
        emit pausedChanged();
    }
}

void SpeechRecognizer::teardownAudio()
{
    if (m_audioIo) {
        disconnect(m_audioIo, &QIODevice::readyRead, this, &SpeechRecognizer::onAudioDataReady);
        m_audioIo = nullptr;
    }
    if (m_audioInput) {
        m_audioInput->stop();
        m_audioInput->deleteLater();
        m_audioInput = nullptr;
    }
}

QString SpeechRecognizer::writeWav(const QByteArray &pcm) const
{
    QString dirPath = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
    if (dirPath.isEmpty()) {
        dirPath = QDir::homePath() + QStringLiteral("/.local/share/ru.omstu.voicenotes");
    }
    dirPath += QStringLiteral("/audio");
    QDir dir;
    if (!dir.mkpath(dirPath)) {
        return QString();
    }

    const QString fileName = QStringLiteral("note_%1.wav")
            .arg(QDateTime::currentDateTime().toString(QStringLiteral("yyyyMMdd_hhmmss")));
    const QString fullPath = dirPath + QLatin1Char('/') + fileName;

    QFile file(fullPath);
    if (!file.open(QIODevice::WriteOnly)) {
        return QString();
    }

    const quint32 dataSize = static_cast<quint32>(pcm.size());
    const quint16 channels = kChannels;
    const quint32 sampleRate = static_cast<quint32>(m_sampleRate);
    const quint16 bitsPerSample = kSampleSize;
    const quint32 byteRate = sampleRate * channels * (bitsPerSample / 8);
    const quint16 blockAlign = channels * (bitsPerSample / 8);
    const quint32 riffSize = 36 + dataSize;

    QDataStream out(&file);
    out.setByteOrder(QDataStream::LittleEndian);

    file.write("RIFF", 4);
    out << riffSize;
    file.write("WAVE", 4);
    file.write("fmt ", 4);
    out << quint32(16);            // PCM fmt chunk size
    out << quint16(1);             // audio format = PCM
    out << channels;
    out << sampleRate;
    out << byteRate;
    out << blockAlign;
    out << bitsPerSample;
    file.write("data", 4);
    out << dataSize;
    file.write(pcm);
    file.close();

    return fullPath;
}

bool SpeechRecognizer::saveTextToFile(const QString &filePath, const QString &text)
{
    QString localPath = filePath;
    // Handle file:// URLs
    if (localPath.startsWith(QLatin1String("file://"))) {
        QUrl url(localPath);
        localPath = url.toLocalFile();
    }

    QFile file(localPath);
    if (!file.open(QIODevice::WriteOnly | QIODevice::Text)) {
        return false;
    }

    QTextStream stream(&file);
    stream.setCodec("UTF-8");
    stream << text;
    file.close();
    return true;
}

int SpeechRecognizer::fileSize(const QString &path) const
{
    QString localPath = path;
    if (localPath.startsWith(QLatin1String("file://"))) {
        QUrl url(localPath);
        localPath = url.toLocalFile();
    }
    QFile f(localPath);
    if (!f.exists()) {
        return 0;
    }
    return static_cast<int>(f.size());
}
