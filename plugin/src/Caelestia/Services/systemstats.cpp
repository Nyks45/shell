#include "systemstats.hpp"

#include <qdatetime.h>
#include <qdir.h>
#include <qfile.h>

namespace caelestia::shell::services {

using Qt::StringLiterals::operator""_s;

namespace {

QByteArray readFile(const QString& path) {
    QFile f(path);
    if (!f.open(QIODevice::ReadOnly))
        return {};
    return f.readAll();
}

// "Key:   1234 kB" in /proc/meminfo, in bytes
qreal meminfo(const QByteArray& data, const char* key) {
    const int at = data.indexOf(key);
    if (at < 0)
        return 0;
    const int end = data.indexOf('\n', at);
    const QByteArray value = data.mid(at + qstrlen(key), end - at - qstrlen(key)).trimmed();
    return value.split(' ').first().toDouble() * 1024.0;
}

// A whole disk (not a partition, loop or RAM device) that the kernel lists in /sys/block
bool isWholeDisk(const QString& name) {
    if (name.startsWith(u"loop"_s) || name.startsWith(u"ram"_s) || name.startsWith(u"zram"_s)
        || name.startsWith(u"dm-"_s) || name.startsWith(u"sr"_s) || name.startsWith(u"fd"_s))
        return false;
    return QFile::exists(u"/sys/block/"_s + name);
}

} // namespace

SystemStats::SystemStats(QObject* parent)
    : TickingService(parent) {}

void SystemStats::tick() {
    const qint64 nowMs = QDateTime::currentMSecsSinceEpoch();
    const qreal dSec = m_lastTickMs > 0 ? (nowMs - m_lastTickMs) / 1000.0 : 0.0;
    m_lastTickMs = nowMs;

    readCpu();
    readMemory();
    readDisks(dSec);
    readNetworks(dSec);
    m_uptime = readFile(u"/proc/uptime"_s).split(' ').first().toDouble();
    emit updated();
}

void SystemStats::readCpu() {
    const QByteArray stat = readFile(u"/proc/stat"_s);
    QList<CpuTimes> now;
    for (const QByteArray& line : stat.split('\n')) {
        if (!line.startsWith("cpu"))
            break;
        const QList<QByteArray> f = line.simplified().split(' ');
        if (f.size() < 8)
            continue;
        // user nice system idle iowait irq softirq steal: idle and iowait are not busy
        CpuTimes t;
        for (int i = 1; i < f.size() && i <= 8; i++)
            t.total += f.at(i).toULongLong();
        t.busy = t.total - f.at(4).toULongLong() - f.at(5).toULongLong();
        now.append(t);
    }
    if (m_lastCpu.size() == now.size() && !now.isEmpty()) {
        const auto usage = [](const CpuTimes& a, const CpuTimes& b) {
            const quint64 total = b.total > a.total ? b.total - a.total : 0;
            const quint64 busy = b.busy > a.busy ? b.busy - a.busy : 0;
            return total > 0 ? std::min(1.0, static_cast<qreal>(busy) / static_cast<qreal>(total)) : 0.0;
        };
        m_cpu = usage(m_lastCpu.at(0), now.at(0));
        m_cores.resize(now.size() - 1);
        for (int i = 1; i < now.size(); i++)
            m_cores[i - 1] = usage(m_lastCpu.at(i), now.at(i));
    } else {
        m_cores = QList<qreal>(std::max<qsizetype>(0, now.size() - 1), 0.0);
    }
    m_lastCpu = now;

    // The average current clock of the cores (cpufreq, else /proc/cpuinfo)
    qreal sum = 0;
    int count = 0;
    for (int i = 0; i < m_cores.size(); i++) {
        const QByteArray khz = readFile(u"/sys/devices/system/cpu/cpu%1/cpufreq/scaling_cur_freq"_s.arg(i));
        if (khz.isEmpty())
            break;
        sum += khz.trimmed().toDouble() / 1000.0;
        count++;
    }
    if (count == 0) {
        const QByteArray info = readFile(u"/proc/cpuinfo"_s);
        for (const QByteArray& line : info.split('\n')) {
            if (line.startsWith("cpu MHz")) {
                sum += line.mid(line.indexOf(':') + 1).trimmed().toDouble();
                count++;
            }
        }
    }
    m_frequency = count > 0 ? sum / count : 0;
}

void SystemStats::readMemory() {
    const QByteArray data = readFile(u"/proc/meminfo"_s);
    m_memTotal = meminfo(data, "MemTotal:");
    m_memUsed = m_memTotal - meminfo(data, "MemAvailable:");
    m_memCached = meminfo(data, "Cached:") + meminfo(data, "SReclaimable:");
    m_memBuffers = meminfo(data, "Buffers:");
    m_swapTotal = meminfo(data, "SwapTotal:");
    m_swapUsed = m_swapTotal - meminfo(data, "SwapFree:");
}

void SystemStats::readDisks(qreal dSec) {
    QVariantList disks;
    QHash<QString, DiskCounters> now;
    for (const QByteArray& line : readFile(u"/proc/diskstats"_s).split('\n')) {
        const QList<QByteArray> f = line.simplified().split(' ');
        if (f.size() < 14)
            continue;
        const QString name = QString::fromLatin1(f.at(2));
        if (!isWholeDisk(name))
            continue;
        // fields: reads completed, merged, sectors read, ms; writes ..., sectors written, ms;
        // in flight, ms doing I/O (the busy time)
        DiskCounters c { f.at(5).toULongLong(), f.at(9).toULongLong(), f.at(12).toULongLong() };
        now.insert(name, c);

        if (!m_diskModels.contains(name)) {
            QString model = QString::fromUtf8(readFile(u"/sys/block/%1/device/model"_s.arg(name))).trimmed();
            m_diskModels.insert(name, model);
        }
        QVariantMap disk { { u"name"_s, name }, { u"model"_s, m_diskModels.value(name) },
            { u"removable"_s, readFile(u"/sys/block/%1/removable"_s.arg(name)).trimmed() == "1" },
            { u"read"_s, 0.0 }, { u"write"_s, 0.0 }, { u"busy"_s, 0.0 } };
        if (const auto last = m_lastDisks.constFind(name); last != m_lastDisks.constEnd() && dSec > 0) {
            // (sectors are 512 bytes in /proc/diskstats, whatever the disk's own size)
            disk[u"read"_s] = c.read >= last->read ? (c.read - last->read) * 512.0 / dSec : 0.0;
            disk[u"write"_s] = c.write >= last->write ? (c.write - last->write) * 512.0 / dSec : 0.0;
            disk[u"busy"_s] = c.busyMs >= last->busyMs ? std::min(1.0, (c.busyMs - last->busyMs) / (dSec * 1000.0)) : 0.0;
        }
        disks.append(disk);
    }
    m_lastDisks = now;
    m_disks = disks;
}

void SystemStats::readNetworks(qreal dSec) {
    QVariantList networks;
    QHash<QString, NetCounters> now;
    const QList<QByteArray> lines = readFile(u"/proc/net/dev"_s).split('\n');
    for (int i = 2; i < lines.size(); i++) {
        const int colon = lines.at(i).indexOf(':');
        if (colon < 0)
            continue;
        const QString name = QString::fromLatin1(lines.at(i).left(colon).trimmed());
        // (loopback and virtual bridges/tunnels don't leave the machine)
        if (name == u"lo"_s || !QFile::exists(u"/sys/class/net/%1/device"_s.arg(name)))
            continue;
        const QList<QByteArray> f = lines.at(i).mid(colon + 1).simplified().split(' ');
        if (f.size() < 9)
            continue;
        NetCounters c { f.at(0).toULongLong(), f.at(8).toULongLong() };
        now.insert(name, c);
        QVariantMap net { { u"name"_s, name }, { u"rx"_s, 0.0 }, { u"tx"_s, 0.0 },
            { u"rxTotal"_s, static_cast<qreal>(c.rx) }, { u"txTotal"_s, static_cast<qreal>(c.tx) },
            { u"wireless"_s, QFile::exists(u"/sys/class/net/%1/wireless"_s.arg(name)) } };
        if (const auto last = m_lastNets.constFind(name); last != m_lastNets.constEnd() && dSec > 0) {
            net[u"rx"_s] = c.rx >= last->rx ? (c.rx - last->rx) / dSec : 0.0;
            net[u"tx"_s] = c.tx >= last->tx ? (c.tx - last->tx) / dSec : 0.0;
        }
        networks.append(net);
    }
    m_lastNets = now;
    m_networks = networks;
}

} // namespace caelestia::shell::services
