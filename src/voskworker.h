#ifndef VOSKWORKER_H
#define VOSKWORKER_H

#include <QObject>
#include <QString>
#include <QByteArray>

struct VoskModel;
struct VoskRecognizer;

// VoskWorker owns the Vosk model/recognizer and is meant to live in a
// dedicated QThread. All heavy work (model loading, decoding) happens here so
// the GUI thread is never blocked.
class VoskWorker : public QObject
{
    Q_OBJECT
public:
    explicit VoskWorker(QObject *parent = nullptr);
    ~VoskWorker() override;

public slots:
    void load(const QString &modelPath, int sampleRate);
    void feed(const QByteArray &pcm);
    void finalize();
    void reset();

signals:
    void loaded(bool ok, const QString &message);
    // A completed utterance (silence detected).
    void utterance(const QString &text);
    // The trailing utterance produced by finalize().
    void finalUtterance(const QString &text);
    // Interim, not-yet-final hypothesis.
    void partial(const QString &text);

private:
    static QString parseField(const char *json, const QString &field);

    VoskModel *m_model;
    VoskRecognizer *m_rec;
};

#endif // VOSKWORKER_H
