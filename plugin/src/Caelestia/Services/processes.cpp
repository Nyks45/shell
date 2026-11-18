#include "processes.hpp"

#include <qdatetime.h>
#include <qdir.h>
#include <qfile.h>
#include <qprocess.h>

#include <algorithm>
#include <optional>
#include <csignal>
#include <pwd.h>
#include <sys/resource.h>
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

void Processes::readGpu() {
    if (m_gpuReading || m_gpuMissing)
        return;
    m_gpuReading = true;
    auto* proc = new QProcess(this);
    proc->setStandardErrorFile(QProcess::nullDevice());
    connect(proc, &QProcess::finished, this, [this, proc](int code) {
        m_gpuReading = false;
        proc->deleteLater();
        if (code != 0)
            return;
        // "# gpu pid type sm mem enc dec jpg ofa fb ccpm command": sm %, fb MB ("-" when none)
        QHash<int, QPair<qreal, qreal>> gpu;
        for (const QByteArray& line : proc->readAllStandardOutput().split('\n')) {
            if (line.startsWith('#'))
                continue;
            const QList<QByteArray> f = line.simplified().split(' ');
            if (f.size() < 10)
                continue;
            const int pid = f.at(1).toInt();
            const qreal sm = f.at(3) == "-" ? 0 : f.at(3).toDouble() / 100.0;
            const qreal fb = f.at(9) == "-" ? 0 : f.at(9).toDouble() * 1048576.0;
            auto& slot = gpu[pid];
            slot.first += sm;
            slot.second += fb;
        }
        m_gpu = gpu;
    });
    connect(proc, &QProcess::errorOccurred, this, [this, proc](QProcess::ProcessError err) {
        if (err == QProcess::FailedToStart) {
            m_gpuMissing = true; // (no NVIDIA tools: no per process GPU)
            m_gpuReading = false;
            proc->deleteLater();
        }
    });
    proc->start(u"nvidia-smi"_s, { u"pmon"_s, u"-c"_s, u"1"_s, u"-s"_s, u"um"_s });
}

void Processes::tick() {
    readGpu();
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
        p.nice = f.at(16).toInt();
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
            p.name = prev->name; // (the full name worked out the first time)
            p.unit = prev->unit;
        } else {
            // Its systemd unit: the last .service/.scope in its cgroup path
            const QByteArray cgroup = readFile(base + u"/cgroup"_s);
            for (const QByteArray& part : cgroup.trimmed().split('/'))
                if (part.endsWith(".service") || part.endsWith(".scope"))
                    p.unit = QString::fromUtf8(part);
            QByteArray cmd = readFile(base + u"/cmdline"_s);
            cmd.replace('\0', ' ');
            p.command = QString::fromUtf8(cmd.trimmed());
            // comm is cut at 15 characters: the executable's name is the full one
            // (for scripts the program is an argument: python3 /usr/lib/x/caelestia-devices)
            if (p.name.size() >= 15 && !p.command.isEmpty()) {
                const QStringList args = p.command.split(u' ', Qt::SkipEmptyParts);
                for (int i = 0; i < args.size() && i < 4; i++) {
                    const QString exe = args.at(i).section(u'/', -1);
                    if (exe.startsWith(p.name)) {
                        p.name = exe;
                        break;
                    }
                }
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
        { u"nice"_s, it->nice },
        { u"unit"_s, it->unit },
        { u"exe"_s, QFile::symLinkTarget(u"/proc/%1/exe"_s.arg(pid)) },
        { u"cwd"_s, QFile::symLinkTarget(u"/proc/%1/cwd"_s.arg(pid)) },
        { u"uptime"_s, readFile(u"/proc/uptime"_s).split(' ').first().toDouble() },
        { u"cpu"_s, it->cpu },
        { u"memory"_s, static_cast<qreal>(it->memory) },
        { u"resident"_s, static_cast<qreal>(it->resident) },
        { u"diskRead"_s, it->diskRead },
        { u"diskWrite"_s, it->diskWrite },
        { u"started"_s, static_cast<qreal>(it->started) },
    };
}

QVariantList Processes::tree(const QVariantList& apps, const QStringList& expanded, const QString& filter,
    const QString& sortKey, bool ascending) const {
    struct Group {
        QString kind, key, name, icon;
        int pid = -1;
        QString user, state, unit, command;
        QList<int> pids;
        qreal cpu = 0, memory = 0, disk = 0, resident = 0, threads = 0, nice = 0, started = 0, gpu = 0, gpuMemory = 0;
    };
    const auto value = [&](qreal cpu, qreal memory, qreal disk, const QString& name, int pid, const QString& user) {
        Q_UNUSED(name);
        Q_UNUSED(user);
        if (sortKey == u"memory"_s)
            return memory;
        if (sortKey == u"disk"_s)
            return disk;
        if (sortKey == u"pid"_s)
            return static_cast<qreal>(pid);
        return cpu;
    };
    // (the other numeric columns)
    const auto extra = [&](const auto& g) -> std::optional<qreal> {
        if (sortKey == u"threads"_s)
            return g.threads;
        if (sortKey == u"gpu"_s)
            return g.gpu;
        if (sortKey == u"gpumem"_s)
            return g.gpuMemory;
        if (sortKey == u"resident"_s)
            return g.resident;
        if (sortKey == u"nice"_s)
            return g.nice;
        if (sortKey == u"started"_s)
            return -g.started; // (longest running first when descending)
        return std::nullopt;
    };
    const auto before = [&](const Group& a, const Group& b) {
        int c = 0;
        if (sortKey == u"name"_s)
            c = QString::compare(a.name, b.name, Qt::CaseInsensitive);
        else if (sortKey == u"user"_s)
            c = QString::compare(a.user, b.user, Qt::CaseInsensitive);
        else if (sortKey == u"unit"_s)
            c = QString::compare(a.unit, b.unit, Qt::CaseInsensitive);
        else if (sortKey == u"command"_s)
            c = QString::compare(a.command, b.command, Qt::CaseInsensitive);
        else if (const auto ea = extra(a), eb = extra(b); ea && eb)
            c = *ea < *eb ? -1 : *ea > *eb ? 1 : 0;
        else {
            const qreal x = value(a.cpu, a.memory, a.disk, a.name, a.pid, a.user);
            const qreal y = value(b.cpu, b.memory, b.disk, b.name, b.pid, b.user);
            c = x < y ? -1 : x > y ? 1 : 0;
        }
        if (c == 0)
            return a.pid < b.pid;
        return ascending ? c < 0 : c > 0;
    };
    const auto procGroup = [&](const ProcessInfo& p) {
        Group g;
        g.kind = u"proc"_s;
        g.key = QString::number(p.pid);
        g.name = p.name;
        g.pid = p.pid;
        g.user = p.user;
        g.unit = p.unit;
        g.command = p.command;
        g.state = QString(p.state);
        g.pids = { p.pid };
        g.cpu = p.cpu;
        g.memory = static_cast<qreal>(p.memory);
        g.disk = p.diskRead + p.diskWrite;
        g.resident = static_cast<qreal>(p.resident);
        g.threads = p.threads;
        g.nice = p.nice;
        g.started = static_cast<qreal>(p.started);
        const auto gpu = m_gpu.value(p.pid);
        g.gpu = gpu.first;
        g.gpuMemory = gpu.second;
        return g;
    };
    const auto row = [](const Group& g, int depth, bool isExpanded) {
        return QVariantMap { { u"kind"_s, g.kind }, { u"key"_s, g.key }, { u"name"_s, g.name },
            { u"icon"_s, g.icon }, { u"depth"_s, depth }, { u"pid"_s, g.pid }, { u"user"_s, g.user },
            { u"unit"_s, g.unit }, { u"command"_s, g.command },
            { u"state"_s, g.state }, { u"cpu"_s, g.cpu }, { u"memory"_s, g.memory }, { u"disk"_s, g.disk },
            { u"count"_s, g.pids.size() }, { u"expanded"_s, isExpanded }, { u"resident"_s, g.resident },
            { u"threads"_s, g.threads }, { u"nice"_s, g.nice }, { u"started"_s, g.started },
            { u"gpu"_s, g.gpu }, { u"gpuMemory"_s, g.gpuMemory } };
    };
    const auto section = [](const QString& key, const QString& name, int count) {
        return QVariantMap { { u"kind"_s, u"section"_s }, { u"key"_s, key }, { u"name"_s, name }, { u"icon"_s, QString() },
            { u"depth"_s, 0 }, { u"pid"_s, -1 }, { u"user"_s, QString() }, { u"unit"_s, QString() },
            { u"command"_s, QString() }, { u"state"_s, QString() },
            { u"cpu"_s, 0.0 }, { u"memory"_s, 0.0 }, { u"disk"_s, 0.0 }, { u"count"_s, count },
            { u"expanded"_s, true }, { u"resident"_s, 0.0 }, { u"threads"_s, 0.0 }, { u"nice"_s, 0.0 },
            { u"started"_s, 0.0 }, { u"gpu"_s, 0.0 }, { u"gpuMemory"_s, 0.0 } };
    };

    QVariantList rows;

    // Searching: the matching processes, flat
    if (!filter.isEmpty()) {
        QList<Group> matches;
        for (const auto& p : m_procs)
            if (p.name.contains(filter, Qt::CaseInsensitive) || p.command.contains(filter, Qt::CaseInsensitive)
                || QString::number(p.pid) == filter)
                matches.append(procGroup(p));
        std::sort(matches.begin(), matches.end(), before);
        rows.append(section(u"results"_s, u"Results"_s, matches.size()));
        for (const auto& g : std::as_const(matches))
            rows.append(row(g, 0, false));
        return rows;
    }

    // A group's processes (expanded), sorted like the groups
    const auto children = [&](const Group& g, int skipPid) {
        QList<Group> list;
        for (const int pid : g.pids) {
            if (pid == skipPid)
                continue;
            if (const auto it = m_procs.constFind(pid); it != m_procs.constEnd())
                list.append(procGroup(*it));
        }
        std::sort(list.begin(), list.end(), before);
        return list;
    };
    // Apps: each app's windows' processes and everything under them
    QSet<int> claimed;
    QList<Group> appGroups;
    for (const QVariant& v : apps) {
        const QVariantMap a = v.toMap();
        Group g;
        g.kind = u"app"_s;
        g.key = u"app:"_s + a.value(u"key"_s).toString();
        g.name = a.value(u"name"_s).toString();
        g.icon = a.value(u"icon"_s).toString();
        g.command = a.value(u"title"_s).toString(); // (shown under the name: the window's title)
        for (const QVariant& rootPid : a.value(u"pids"_s).toList()) {
            const int root = rootPid.toInt();
            if (g.pid < 0)
                g.pid = root;
            for (const int pid : descendants(root)) {
                const auto it = m_procs.constFind(pid);
                if (it == m_procs.constEnd() || claimed.contains(pid))
                    continue;
                claimed.insert(pid);
                g.pids.append(pid);
                g.cpu += it->cpu;
                g.memory += static_cast<qreal>(it->memory);
                g.disk += it->diskRead + it->diskWrite;
                g.resident += static_cast<qreal>(it->resident);
                g.threads += it->threads;
                g.gpu += m_gpu.value(pid).first;
                g.gpuMemory += m_gpu.value(pid).second;
                g.user = it->user;
                if (pid == root) {
                    g.nice = it->nice;
                    g.started = static_cast<qreal>(it->started);
                }
            }
        }
        if (!g.pids.isEmpty())
            appGroups.append(g);
    }
    std::sort(appGroups.begin(), appGroups.end(), before);
    rows.append(section(u"apps"_s, u"Apps"_s, appGroups.size()));
    for (const auto& g : std::as_const(appGroups)) {
        const bool open = expanded.contains(g.key);
        rows.append(row(g, 0, open));
        if (open)
            for (const auto& c : children(g, -1))
                rows.append(row(c, 1, false));
    }

    // The rest: each process with its children, unless its parent is in the same part
    // (this user's or the others') and isn't a service manager (systemd)
    const uint me = getuid();
    const auto groupsOf = [&](bool mine) {
        QList<Group> groups;
        const auto inPart = [&](const ProcessInfo& p) {
            return !claimed.contains(p.pid) && (p.uid == me) == mine;
        };
        for (const auto& p : m_procs) {
            if (!inPart(p))
                continue;
            const auto parent = m_procs.constFind(p.ppid);
            const bool underParent = parent != m_procs.constEnd() && inPart(*parent) && parent->name != u"systemd"_s;
            if (underParent)
                continue;
            Group g = procGroup(p);
            // (its children in the same part, recursively)
            QList<int> queue = m_children.value(p.pid);
            while (!queue.isEmpty()) {
                const int pid = queue.takeFirst();
                const auto it = m_procs.constFind(pid);
                if (it == m_procs.constEnd() || !inPart(*it) || p.name == u"systemd"_s)
                    continue;
                g.pids.append(pid);
                g.cpu += it->cpu;
                g.memory += static_cast<qreal>(it->memory);
                g.disk += it->diskRead + it->diskWrite;
                g.resident += static_cast<qreal>(it->resident);
                g.threads += it->threads;
                g.gpu += m_gpu.value(pid).first;
                g.gpuMemory += m_gpu.value(pid).second;
                queue.append(m_children.value(pid));
            }
            if (g.pids.size() > 1) {
                g.kind = u"group"_s;
                if (p.pid == 2)
                    g.name = u"Kernel threads"_s;
            }
            groups.append(g);
        }
        std::sort(groups.begin(), groups.end(), before);
        return groups;
    };
    for (const bool mine : { true, false }) {
        const QList<Group> groups = groupsOf(mine);
        rows.append(section(mine ? u"background"_s : u"system"_s,
            mine ? u"Background processes"_s : u"System processes"_s, groups.size()));
        for (const auto& g : groups) {
            const bool open = g.kind == u"group"_s && expanded.contains(g.key);
            rows.append(row(g, 0, open));
            if (open)
                for (const auto& c : children(g, g.pid))
                    rows.append(row(c, 1, false));
        }
    }
    return rows;
}

bool Processes::setPriority(int pid, int nice) {
    return setpriority(PRIO_PROCESS, static_cast<id_t>(pid), std::clamp(nice, -20, 19)) == 0;
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
