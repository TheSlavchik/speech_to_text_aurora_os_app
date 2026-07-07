#ifndef SPEECHRECOGNIZER_H
#define SPEECHRECOGNIZER_H

#include <QObject>
#include <QString>
#include <QByteArray>
#include <QThread>
#include <QScopedPointer>
#include <QElapsedTimer>
#include <QTimer>

QT_BEGIN_NAMESPACE
class QAudioInput;
class QIODevice;
QT_END_NAMESPACE

class VoskWorker;

// SpeechRecognizer wires live microphone capture (QtMultimedia) to an offline
// Vosk recognizer that runs in its own worker thread, so the UI stays
// responsive. The recorded audio is written to a WAV file in the application
// data directory and the recognised text is emitted when recording stops.
class SpeechRecognizer : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QString modelPath READ modelPath WRITE setModelPath NOTIFY modelPathChanged)
    Q_PROPERTY(bool modelReady READ modelReady NOTIFY modelReadyChanged)
    Q_PROPERTY(bool loading READ loading NOTIFY loadingChanged)
    Q_PROPERTY(bool recording READ recording NOTIFY recordingChanged)
    Q_PROPERTY(bool finalizing READ finalizing NOTIFY finalizingChanged)
        Q_PROPERTY(bool paused READ paused NOTIFY pausedChanged)
        Q_PROPERTY(qreal level READ level NOTIFY levelChanged)
    Q_PROPERTY(QString partialText READ partialText NOTIFY partialTextChanged)
    Q_PROPERTY(QString fullText READ fullText NOTIFY fullTextChanged)
    Q_PROPERTY(int durationSec READ durationSec NOTIFY durationSecChanged)

public:
    explicit SpeechRecognizer(QObject *parent = nullptr);
    ~SpeechRecognizer() override;

    QString modelPath() const { return m_modelPath; }
    void setModelPath(const QString &path);
    bool modelReady() const { return m_modelReady; }
    bool loading() const { return m_loading; }
    bool recording() const { return m_recording; }
    bool finalizing() const { return m_finalizing; }
        bool paused() const { return m_paused; }
        qreal level() const { return m_level; }
    QString partialText() const { return m_partialText; }
    QString fullText() const { return m_fullText; }
    int durationSec() const { return m_durationSec; }

public slots:
    // Loads the Vosk model in the background. Safe to call more than once.
    void init();
    // Starts microphone capture and streaming recognition.
    void start();
    // Stops capture, flushes the recognizer and emits finished().
    void stop();
    // Aborts capture and discards the current recording/recognition.
        void cancel();
        // Pauses audio capture without discarding the accumulated PCM buffer.
        void pause();
        // Resumes audio capture after a pause.
        void resume();

    // Saves arbitrary text to a file (UTF-8). Handles file:// URLs and local paths.
    Q_INVOKABLE bool saveTextToFile(const QString &filePath, const QString &text);

signals:
    void modelPathChanged();
    void modelReadyChanged();
    void loadingChanged();
    void recordingChanged();
    void finalizingChanged();
        void pausedChanged();
        void levelChanged();
    void partialTextChanged();
    void fullTextChanged();
    void durationSecChanged();
    // Emitted after stop() once the final text is available.
    // audioPath is a file:// URL to the recorded WAV (empty when nothing recorded).
    void finished(const QString &text, const QString &audioPath, int durationSec);
    void errorOccurred(const QString &message);

    // Internal cross-thread requests to the worker.
    void requestLoad(const QString &path, int sampleRate);
    void requestFeed(const QByteArray &pcm);
    void requestFinalize();
    void requestReset();

private slots:
    void onAudioDataReady();
    void onNoAudioTimeout();
    void onModelLoaded(bool ok, const QString &message);
    void onPartial(const QString &text);
    void onUtterance(const QString &text);
    void onFinalUtterance(const QString &text);

private:
    void setLoading(bool v);
    void setModelReady(bool v);
    void setRecording(bool v);
    void setFinalizing(bool v);
        void setPaused(bool v);
        void setLevel(qreal v);
    void setPartialText(const QString &v);
    void appendText(const QString &v);
    void teardownAudio();
    QString writeWav(const QByteArray &pcm) const;

    QString m_modelPath;
    int m_sampleRate;
    bool m_modelReady;
    bool m_loading;
    bool m_recording;
    bool m_finalizing;
        bool m_paused;
        qreal m_level;
    QString m_partialText;
    QString m_fullText;
    int m_durationSec;
    bool m_cancelled;

    QAudioInput *m_audioInput;
    QIODevice *m_audioIo;
    QByteArray m_pcm;
    bool m_gotAudio;
    QTimer m_noAudioTimer;

    QThread m_thread;
    VoskWorker *m_worker;
};

#endif // SPEECHRECOGNIZER_H
