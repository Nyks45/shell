#pragma once

#include <qhash.h>
#include <qqmlintegration.h>
#include <qvariant.h>

#include "tickingservice.hpp"

namespace caelestia::shell::services {

// The machine's performance, read from /proc only while something uses it (the task manager's
// Performance page): each CPU core, memory and swap, each disk's and network interface's
// activity, uptime. One reading a second.
class SystemStats : public TickingService {
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    // CPU: the whole (0..1), each logical core (0..1), the average clock (MHz)
    Q_PROPERTY(qreal cpu READ cpu NOTIFY updated)
    Q_PROPERTY(QList<qreal> cores READ cores NOTIFY updated)
    Q_PROPERTY(qreal frequency READ frequency NOTIFY updated)
    // Memory in bytes: used = total - available (like the kernel's own "MemAvailable")
    Q_PROPERTY(qreal memTotal READ memTotal NOTIFY updated)
    Q_PROPERTY(qreal memUsed READ memUsed NOTIFY updated)
    Q_PROPERTY(qreal memCached READ memCached NOTIFY updated)
    Q_PROPERTY(qreal memBuffers READ memBuffers NOTIFY updated)
    Q_PROPERTY(qreal swapTotal READ swapTotal NOTIFY updated)
    Q_PROPERTY(qreal swapUsed READ swapUsed NOTIFY updated)
    // [{name, model, read, write (bytes/s), busy (0..1), removable}] for whole disks
    Q_PROPERTY(QVariantList disks READ disks NOTIFY updated)
    // [{name, rx, tx (bytes/s), rxTotal, txTotal, wireless}] for interfaces other than loopback
    Q_PROPERTY(QVariantList networks READ networks NOTIFY updated)
    Q_PROPERTY(qreal uptime READ uptime NOTIFY updated)

public:
    explicit SystemStats(QObject* parent = nullptr);

    [[nodiscard]] qreal cpu() const { return m_cpu; }
    [[nodiscard]] QList<qreal> cores() const { return m_cores; }
    [[nodiscard]] qreal frequency() const { return m_frequency; }
    [[nodiscard]] qreal memTotal() const { return m_memTotal; }
    [[nodiscard]] qreal memUsed() const { return m_memUsed; }
    [[nodiscard]] qreal memCached() const { return m_memCached; }
    [[nodiscard]] qreal memBuffers() const { return m_memBuffers; }
    [[nodiscard]] qreal swapTotal() const { return m_swapTotal; }
    [[nodiscard]] qreal swapUsed() const { return m_swapUsed; }
    [[nodiscard]] QVariantList disks() const { return m_disks; }
    [[nodiscard]] QVariantList networks() const { return m_networks; }
    [[nodiscard]] qreal uptime() const { return m_uptime; }

signals:
    void updated();

protected:
    void tick() override;

private:
    void readCpu();
    void readMemory();
    void readDisks(qreal dSec);
    void readNetworks(qreal dSec);

    struct CpuTimes {
        quint64 busy = 0;
        quint64 total = 0;
    };
    struct DiskCounters {
        quint64 read = 0;  // sectors
        quint64 write = 0; // sectors
        quint64 busyMs = 0;
    };
    struct NetCounters {
        quint64 rx = 0;
        quint64 tx = 0;
    };

    QList<CpuTimes> m_lastCpu; // [0] = all, then each core
    QHash<QString, DiskCounters> m_lastDisks;
    QHash<QString, NetCounters> m_lastNets;
    QHash<QString, QString> m_diskModels;
    qint64 m_lastTickMs = 0;

    qreal m_cpu = 0;
    QList<qreal> m_cores;
    qreal m_frequency = 0;
    qreal m_memTotal = 0;
    qreal m_memUsed = 0;
    qreal m_memCached = 0;
    qreal m_memBuffers = 0;
    qreal m_swapTotal = 0;
    qreal m_swapUsed = 0;
    QVariantList m_disks;
    QVariantList m_networks;
    qreal m_uptime = 0;
};

} // namespace caelestia::shell::services
