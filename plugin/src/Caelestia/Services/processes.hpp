#pragma once

#include <qabstractitemmodel.h>
#include <qhash.h>
#include <qqmlintegration.h>
#include <qvariant.h>

#include "tickingservice.hpp"

namespace caelestia::shell::services {

// One process, as read from /proc
struct ProcessInfo {
    int pid = 0;
    int ppid = 0;
    uint uid = 0;
    QString name;    // comm (or the executable's file name when comm is cut short)
    QString command; // the full command line
    QString user;
    QChar state;
    int threads = 0;
    qreal cpu = 0.0;       // share of the whole machine, 0..1
    quint64 memory = 0;    // bytes: resident, not shared (RssAnon + RssShmem)
    quint64 resident = 0;  // bytes: all resident
    qreal diskRead = 0.0;  // bytes/s
    qreal diskWrite = 0.0; // bytes/s
    quint64 started = 0;   // seconds since boot

    // (for the deltas)
    quint64 cpuTicks = 0;
    quint64 readBytes = 0;
    quint64 writeBytes = 0;
};

// The processes, sortable and filterable, updated in place each tick
class ProcessModel : public QAbstractListModel {
    Q_OBJECT
    QML_ANONYMOUS

    Q_PROPERTY(QString sortKey READ sortKey WRITE setSortKey NOTIFY sortChanged)
    Q_PROPERTY(bool sortAscending READ sortAscending WRITE setSortAscending NOTIFY sortChanged)
    Q_PROPERTY(QString filter READ filter WRITE setFilter NOTIFY filterChanged)
    Q_PROPERTY(int count READ rowCount NOTIFY countChanged)

public:
    enum Roles {
        PidRole = Qt::UserRole + 1,
        PpidRole,
        NameRole,
        CommandRole,
        UserRole,
        StateRole,
        ThreadsRole,
        CpuRole,
        MemoryRole,
        ResidentRole,
        DiskReadRole,
        DiskWriteRole,
        StartedRole,
    };

    explicit ProcessModel(QObject* parent = nullptr);

    [[nodiscard]] int rowCount(const QModelIndex& parent = {}) const override;
    [[nodiscard]] QVariant data(const QModelIndex& index, int role) const override;
    [[nodiscard]] QHash<int, QByteArray> roleNames() const override;

    [[nodiscard]] QString sortKey() const;
    void setSortKey(const QString& key);
    [[nodiscard]] bool sortAscending() const;
    void setSortAscending(bool asc);
    [[nodiscard]] QString filter() const;
    void setFilter(const QString& filter);

    // The shown rows from the latest snapshot (sorted, filtered), keeping rows in place
    void apply(const QList<const ProcessInfo*>& all);

signals:
    void sortChanged();
    void filterChanged();
    void countChanged();

private:
    void resort();
    [[nodiscard]] bool lessThan(const ProcessInfo* a, const ProcessInfo* b) const;

    QList<ProcessInfo> m_rows;
    QList<const ProcessInfo*> m_last;
    QString m_sortKey = QStringLiteral("cpu");
    bool m_sortAscending = false;
    QString m_filter;
};

// Every process on the machine, read only while something uses it (the task manager): per
// process CPU, memory, disk activity; app totals; ending, stopping and resuming processes
class Processes : public TickingService {
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    Q_PROPERTY(ProcessModel* model READ model CONSTANT)
    Q_PROPERTY(int total READ total NOTIFY updated)
    Q_PROPERTY(int threads READ threads NOTIFY updated)
    Q_PROPERTY(int cores READ cores CONSTANT)

public:
    explicit Processes(QObject* parent = nullptr);

    [[nodiscard]] ProcessModel* model() const;
    [[nodiscard]] int total() const;
    [[nodiscard]] int threads() const;
    [[nodiscard]] int cores() const;

    // Totals for the processes rooted at these pids (an app: its windows' processes and all
    // their children): {cpu, memory, diskRead, diskWrite, processes, pids}
    Q_INVOKABLE QVariantMap group(const QList<int>& rootPids) const;
    // One process's details, or {} when it's gone
    Q_INVOKABLE QVariantMap info(int pid) const;

    // signal: "term" (end), "kill" (force), "stop", "cont"; false when not allowed or gone
    Q_INVOKABLE bool signal(int pid, const QString& signal);
    // The same to a process and all its children (an app)
    Q_INVOKABLE int signalTree(int pid, const QString& signal);

signals:
    void updated();

protected:
    void tick() override;

private:
    QList<int> descendants(int pid) const;
    QString userName(uint uid);

    ProcessModel* m_model;
    QHash<int, ProcessInfo> m_procs;
    QHash<int, QList<int>> m_children;
    QHash<uint, QString> m_users;
    quint64 m_lastTotalTicks = 0;
    qint64 m_lastTickMs = 0;
    int m_threads = 0;
    int m_cores = 1;
    long m_pageSize = 4096;
};

} // namespace caelestia::shell::services
