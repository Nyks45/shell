#pragma once

#include <qhash.h>
#include <qobject.h>
#include <qqmlintegration.h>
#include <qstring.h>
#include <qtimer.h>
#include <qvariant.h>

#include <atomic>
#include <memory>
#include <mutex>
#include <string>
#include <thread>
#include <utility>
#include <vector>

namespace caelestia::shell::services {

class AudioPeakMonitor : public QObject {
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(bool active READ active WRITE setActive NOTIFY activeChanged)
    Q_PROPERTY(QVariantList targets READ targets WRITE setTargets NOTIFY targetsChanged)
    Q_PROPERTY(QVariantMap peaks READ peaks NOTIFY peaksChanged)

public:
    struct TargetSpec {
        std::string serial;
        bool captureSink = false;
    };

    struct PeakSlot {
        std::atomic<float> peak{ 0.0f };
        std::atomic<qint64> lastSampleMs{ 0 };
    };

    explicit AudioPeakMonitor(QObject* parent = nullptr);
    ~AudioPeakMonitor() override;

    [[nodiscard]] bool active() const;
    void setActive(bool active);

    [[nodiscard]] QVariantList targets() const;
    void setTargets(const QVariantList& targets);

    [[nodiscard]] QVariantMap peaks() const;

signals:
    void activeChanged();
    void targetsChanged();
    void peaksChanged();

private:
    void startWorker();
    void stopWorker();
    void pollPeaks();

    bool m_active = false;
    QVariantList m_targets;
    QVariantMap m_peaks;

    QTimer m_pollTimer;
    QHash<QString, float> m_smoothed;

    std::mutex m_targetsMutex;
    std::vector<TargetSpec> m_desiredTargets;
    std::atomic<quint64> m_targetsGeneration{ 0 };

    std::mutex m_slotsMutex;
    std::vector<std::pair<QString, std::shared_ptr<PeakSlot>>> m_activeSlots;

    std::jthread m_thread;
};

} // namespace caelestia::shell::services
