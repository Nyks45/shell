#include "processes.hpp"

#include <qdatetime.h>
#include <qdir.h>
#include <qfile.h>

#include <algorithm>
#include <csignal>
#include <pwd.h>
#include <sys/types.h>
#include <unistd.h>

namespace caelestia::shell::services {

using Qt::StringLiterals::operator""_s;

namespace {

QByteArray readFile(const QString& path) {
    QFile f(path);
    if (!f.open(QIODevice::ReadOnly))
        return {};
    return f.readAll();
}

// The total of all CPU time (the "cpu" line of /proc/stat), in clock ticks
quint64 totalTicks() {
    const QByteArray data = readFile(u"/proc/stat"_s);
    const int end = data.indexOf('\n');
    const QList<QByteArray> parts = data.left(end).simplified().split(' ');
    quint64 sum = 0;
    for (int i = 1; i < parts.size(); i++)
        sum += parts.at(i).toULongLong();
    return sum;
}

quint64 statusKib(const QByteArray& status, const char* key) {
    const int at = status.indexOf(key);
    if (at < 0)
        return 0;
    const int end = status.indexOf('\n', at);
    const QByteArray line = status.mid(at + qstrlen(key), end - at - qstrlen(key)).trimmed();
    return line.split(' ').first().toULongLong();
}

} // namespace

// ---- ProcessModel -------------------------------------------------------------------------

ProcessModel::ProcessModel(QObject* parent)
    : QAbstractListModel(parent) {}

int ProcessModel::rowCount(const QModelIndex& parent) const {
    return parent.isValid() ? 0 : static_cast<int>(m_rows.size());
}

QVariant ProcessModel::data(const QModelIndex& index, int role) const {
    if (!index.isValid() || index.row() >= m_rows.size())
        return {};
    const ProcessInfo& p = m_rows.at(index.row());
    switch (role) {
    case PidRole:
        return p.pid;
    case PpidRole:
        return p.ppid;
    case NameRole:
        return p.name;
    case CommandRole:
        return p.command;
    case UserRole:
        return p.user;
    case StateRole:
        return QString(p.state);
    case ThreadsRole:
        return p.threads;
    case CpuRole:
        return p.cpu;
    case MemoryRole:
        return static_cast<qreal>(p.memory);
    case ResidentRole:
        return static_cast<qreal>(p.resident);
    case DiskReadRole:
        return p.diskRead;
    case DiskWriteRole:
        return p.diskWrite;
    case StartedRole:
        return static_cast<qreal>(p.started);
    default:
        return {};
    }
}

QHash<int, QByteArray> ProcessModel::roleNames() const {
    return {
        { PidRole, "pid" },
        { PpidRole, "ppid" },
        { NameRole, "name" },
        { CommandRole, "command" },
        { UserRole, "user" },
        { StateRole, "state" },
        { ThreadsRole, "threads" },
        { CpuRole, "cpu" },
        { MemoryRole, "memory" },
        { ResidentRole, "resident" },
        { DiskReadRole, "diskRead" },
        { DiskWriteRole, "diskWrite" },
        { StartedRole, "started" },
    };
}

QString ProcessModel::sortKey() const {
    return m_sortKey;
}

void ProcessModel::setSortKey(const QString& key) {
    if (key == m_sortKey)
        return;
    m_sortKey = key;
    emit sortChanged();
    resort();
}

bool ProcessModel::sortAscending() const {
    return m_sortAscending;
}

void ProcessModel::setSortAscending(bool asc) {
    if (asc == m_sortAscending)
        return;
    m_sortAscending = asc;
    emit sortChanged();
    resort();
}

QString ProcessModel::filter() const {
    return m_filter;
}

void ProcessModel::setFilter(const QString& filter) {
    if (filter == m_filter)
        return;
    m_filter = filter;
    emit filterChanged();
    resort();
}

bool ProcessModel::lessThan(const ProcessInfo* a, const ProcessInfo* b) const {
    auto cmp = [&]() -> int {
        if (m_sortKey == u"name"_s)
            return QString::compare(a->name, b->name, Qt::CaseInsensitive);
        if (m_sortKey == u"pid"_s)
            return a->pid - b->pid;
        if (m_sortKey == u"user"_s)
            return QString::compare(a->user, b->user, Qt::CaseInsensitive);
        if (m_sortKey == u"memory"_s)
            return a->memory < b->memory ? -1 : a->memory > b->memory ? 1 : 0;
        if (m_sortKey == u"disk"_s) {
            const qreal x = a->diskRead + a->diskWrite, y = b->diskRead + b->diskWrite;
            return x < y ? -1 : x > y ? 1 : 0;
        }
        if (m_sortKey == u"threads"_s)
            return a->threads - b->threads;
        return a->cpu < b->cpu ? -1 : a->cpu > b->cpu ? 1 : 0;
    }();
    if (cmp == 0)
        return a->pid < b->pid;
    return m_sortAscending ? cmp < 0 : cmp > 0;
}

void ProcessModel::resort() {
    apply(m_last);
}

void ProcessModel::apply(const QList<const ProcessInfo*>& all) {
    m_last = all;
    QList<const ProcessInfo*> shown;
    shown.reserve(all.size());
    for (const auto* p : all) {
        if (!m_filter.isEmpty() && !p->name.contains(m_filter, Qt::CaseInsensitive) &&
            !p->command.contains(m_filter, Qt::CaseInsensitive) && QString::number(p->pid) != m_filter)
            continue;
        shown.append(p);
    }
    std::ranges::sort(shown, [this](const ProcessInfo* a, const ProcessInfo* b) {
        return lessThan(a, b);
    });

    const int oldCount = static_cast<int>(m_rows.size());
    const int newCount = static_cast<int>(shown.size());
    // In place: the rows that stay change their data; extra ones are added or removed at the end
    // (a view keeps its scroll position and delegates)
    if (newCount < oldCount) {
        beginRemoveRows({}, newCount, oldCount - 1);
        m_rows.resize(newCount);
        endRemoveRows();
    }
    for (int i = 0; i < std::min(oldCount, newCount); i++)
        m_rows[i] = *shown.at(i);
    if (std::min(oldCount, newCount) > 0)
        emit dataChanged(index(0), index(std::min(oldCount, newCount) - 1));
    if (newCount > oldCount) {
        beginInsertRows({}, oldCount, newCount - 1);
        for (int i = oldCount; i < newCount; i++)
            m_rows.append(*shown.at(i));
        endInsertRows();
    }
    if (newCount != oldCount)
        emit countChanged();
}

// ---- Processes ----------------------------------------------------------------------------

Processes::Processes(QObject* parent)
    : TickingService(parent)
    , m_model(new ProcessModel(this))
    , m_cores(std::max(1, static_cast<int>(sysconf(_SC_NPROCESSORS_ONLN))))
    , m_pageSize(sysconf(_SC_PAGESIZE)) {}

ProcessModel* Processes::model() const {
    return m_model;
}

int Processes::total() const {
    return static_cast<int>(m_procs.size());
}

int Processes::threads() const {
    return m_threads;
}

int Processes::cores() const {
    return m_cores;
}

QString Processes::userName(uint uid) {
    if (const auto it = m_users.constFind(uid); it != m_users.constEnd())
        return *it;
    const passwd* pw = getpwuid(uid);
    const QString name = pw ? QString::fromLocal8Bit(pw->pw_name) : QString::number(uid);
    m_users.insert(uid, name);
    return name;
}

void Processes::tick() {
    const quint64 total = totalTicks();
    const qint64 nowMs = QDateTime::currentMSecsSinceEpoch();
    const quint64 dTotal = m_lastTotalTicks > 0 && total > m_lastTotalTicks ? total - m_lastTotalTicks : 0;
    const qreal dSec = m_lastTickMs > 0 ? (nowMs - m_lastTickMs) / 1000.0 : 0.0;

    QHash<int, ProcessInfo> next;
    next.reserve(m_procs.size() + 16);
    m_children.clear();
    int threads = 0;

    const QStringList entries = QDir(u"/proc"_s).entryList(QDir::Dirs | QDir::NoDotAndDotDot);
    for (const QString& entry : entries) {
        bool ok = false;
        const int pid = entry.toInt(&ok);
        if (!ok)
            continue;
        const QString base = u"/proc/"_s + entry;

        const QByteArray stat = readFile(base + u"/stat"_s);
        if (stat.isEmpty())
            continue;
        // comm is in parentheses and may contain spaces: fields come after the last ')'
        const int open = stat.indexOf('('), close = stat.lastIndexOf(')');
        if (open < 0 || close < 0)
            continue;
        const QList<QByteArray> f = stat.mid(close + 2).split(' ');
        if (f.size() < 20)
            continue;

        ProcessInfo p;
        p.pid = pid;
        p.name = QString::fromUtf8(stat.mid(open + 1, close - open - 1));
        p.state = QLatin1Char(f.at(0).isEmpty() ? '?' : f.at(0).at(0));
        p.ppid = f.at(1).toInt();
        p.cpuTicks = f.at(11).toULongLong() + f.at(12).toULongLong();
        p.threads = f.at(17).toInt();
        p.started = f.at(19).toULongLong() / static_cast<quint64>(sysconf(_SC_CLK_TCK));
        threads += p.threads;

        const QByteArray status = readFile(base + u"/status"_s);
        p.resident = statusKib(status, "VmRSS:") * 1024;
        p.memory = (statusKib(status, "RssAnon:") + statusKib(status, "RssShmem:")) * 1024;
        if (const int u = status.indexOf("Uid:"); u >= 0)
            p.uid = status.mid(u + 4, status.indexOf('\n', u) - u - 4).simplified().split(' ').first().toUInt();
        p.user = userName(p.uid);

        const auto prev = m_procs.constFind(pid);
        const bool known = prev != m_procs.constEnd() && prev->started == p.started;
        // The command line doesn't change: read once
        if (known) {
            p.command = prev->command;
        } else {
            QByteArray cmd = readFile(base + u"/cmdline"_s);
            cmd.replace('\0', ' ');
            p.command = QString::fromUtf8(cmd.trimmed());
            // comm is cut at 15 characters: the executable's name is the full one
            if (p.name.size() >= 15 && !p.command.isEmpty()) {
                const QString exe = p.command.section(u' ', 0, 0).section(u'/', -1);
                if (exe.startsWith(p.name))
                    p.name = exe;
            }
        }

        const QByteArray io = readFile(base + u"/io"_s);
        if (!io.isEmpty()) {
            p.readBytes = statusKib(io, "read_bytes:");
            p.writeBytes = statusKib(io, "write_bytes:");
        }

        if (known) {
            if (dTotal > 0 && p.cpuTicks >= prev->cpuTicks)
                p.cpu = std::min(1.0, static_cast<qreal>(p.cpuTicks - prev->cpuTicks) / static_cast<qreal>(dTotal));
            if (dSec > 0) {
                p.diskRead = p.readBytes >= prev->readBytes ? (p.readBytes - prev->readBytes) / dSec : 0;
                p.diskWrite = p.writeBytes >= prev->writeBytes ? (p.writeBytes - prev->writeBytes) / dSec : 0;
            }
        }

        m_children[p.ppid].append(pid);
        next.insert(pid, p);
    }

    m_procs = std::move(next);
    m_threads = threads;
    m_lastTotalTicks = total;
    m_lastTickMs = nowMs;

    QList<const ProcessInfo*> all;
    all.reserve(m_procs.size());
    for (const auto& p : std::as_const(m_procs))
        all.append(&p);
    m_model->apply(all);
    emit updated();
}

QList<int> Processes::descendants(int pid) const {
    QList<int> out{ pid };
    for (int i = 0; i < out.size(); i++) {
        if (const auto it = m_children.constFind(out.at(i)); it != m_children.constEnd())
            out.append(*it);
    }
    return out;
}

QVariantMap Processes::group(const QList<int>& rootPids) const {
    qreal cpu = 0, read = 0, write = 0;
    quint64 mem = 0;
    QSet<int> seen;
    QVariantList pids;
    for (const int root : rootPids) {
        for (const int pid : descendants(root)) {
            if (seen.contains(pid))
                continue;
            const auto it = m_procs.constFind(pid);
            if (it == m_procs.constEnd())
                continue;
            seen.insert(pid);
            pids.append(pid);
            cpu += it->cpu;
            mem += it->memory;
            read += it->diskRead;
            write += it->diskWrite;
        }
    }
    return {
        { u"cpu"_s, cpu },
        { u"memory"_s, static_cast<qreal>(mem) },
        { u"diskRead"_s, read },
        { u"diskWrite"_s, write },
        { u"processes"_s, pids.size() },
        { u"pids"_s, pids },
    };
}

QVariantMap Processes::info(int pid) const {
    const auto it = m_procs.constFind(pid);
    if (it == m_procs.constEnd())
        return {};
    return {
        { u"pid"_s, it->pid },
        { u"ppid"_s, it->ppid },
        { u"name"_s, it->name },
        { u"command"_s, it->command },
        { u"user"_s, it->user },
        { u"state"_s, QString(it->state) },
        { u"threads"_s, it->threads },
        { u"cpu"_s, it->cpu },
        { u"memory"_s, static_cast<qreal>(it->memory) },
        { u"resident"_s, static_cast<qreal>(it->resident) },
        { u"diskRead"_s, it->diskRead },
        { u"diskWrite"_s, it->diskWrite },
        { u"started"_s, static_cast<qreal>(it->started) },
    };
}

bool Processes::signal(int pid, const QString& signal) {
    int sig = SIGTERM;
    if (signal == u"kill"_s)
        sig = SIGKILL;
    else if (signal == u"stop"_s)
        sig = SIGSTOP;
    else if (signal == u"cont"_s)
        sig = SIGCONT;
    else if (signal != u"term"_s)
        return false;
    return pid > 1 && ::kill(pid, sig) == 0;
}

int Processes::signalTree(int pid, const QString& signal) {
    // Children first, so a parent doesn't respawn them
    QList<int> tree = descendants(pid);
    std::ranges::reverse(tree);
    int done = 0;
    for (const int p : tree)
        done += this->signal(p, signal) ? 1 : 0;
    return done;
}

} // namespace caelestia::shell::services
