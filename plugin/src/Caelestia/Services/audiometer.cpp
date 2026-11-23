#include "audiometer.hpp"

#include <qdatetime.h>
#include <qloggingcategory.h>

#include <pipewire/pipewire.h>
#include <spa/param/audio/format-utils.h>

#include <algorithm>
#include <cmath>
#include <cstdint>
#include <stop_token>
#include <unordered_map>
#include <vector>

namespace {

Q_LOGGING_CATEGORY(lcAudioMeter, "caelestia.services.audiometer", QtInfoMsg)

constexpr uint32_t k_peakRateHz = 25;
constexpr qint64 k_stalePeakMs = 120;

qint64 currentSteadyMs() {
    return QDateTime::currentMSecsSinceEpoch();
}

struct StreamEntry {
    std::string serial;
    bool captureSink = false;
    pw_stream* stream = nullptr;
    std::shared_ptr<caelestia::shell::services::AudioPeakMonitor::PeakSlot> slot;
};

void destroyStreamEntry(std::unique_ptr<StreamEntry> entry) {
    if (!entry) {
        return;
    }
    if (entry->stream) {
        pw_stream_destroy(entry->stream);
        entry->stream = nullptr;
    }
}

class MeterWorker {
public:
    MeterWorker(std::stop_token token, std::mutex& targetsMutex,
        const std::vector<caelestia::shell::services::AudioPeakMonitor::TargetSpec>& desiredTargets,
        const std::atomic<quint64>& generation, std::mutex& slotsMutex,
        std::vector<std::pair<QString, std::shared_ptr<caelestia::shell::services::AudioPeakMonitor::PeakSlot>>>&
            activeSlots)
        : m_token(std::move(token))
        , m_targetsMutex(targetsMutex)
        , m_desiredTargets(desiredTargets)
        , m_generation(generation)
        , m_slotsMutex(slotsMutex)
        , m_activeSlots(activeSlots) {}

    void run() {
        pw_init(nullptr, nullptr);

        m_loop = pw_main_loop_new(nullptr);
        if (!m_loop) {
            qCWarning(lcAudioMeter) << "failed to create PipeWire main loop";
            pw_deinit();
            return;
        }

        pw_loop* loop = pw_main_loop_get_loop(m_loop);
        m_timer = pw_loop_add_timer(loop, handleTimer, this);
        if (!m_timer) {
            qCWarning(lcAudioMeter) << "failed to create PipeWire timer";
            pw_main_loop_destroy(m_loop);
            m_loop = nullptr;
            pw_deinit();
            return;
        }

        timespec interval = { .tv_sec = 0, .tv_nsec = 25 * SPA_NSEC_PER_MSEC };
        timespec initial = { .tv_sec = 0, .tv_nsec = 1 * SPA_NSEC_PER_MSEC };
        pw_loop_update_timer(loop, m_timer, &initial, &interval, false);

        pw_main_loop_run(m_loop);

        for (auto& [key, entry] : m_streams) {
            destroyStreamEntry(std::move(entry));
        }
        m_streams.clear();
        {
            const std::scoped_lock lock(m_slotsMutex);
            m_activeSlots.clear();
        }

        pw_loop_destroy_source(loop, m_timer);
        m_timer = nullptr;
        pw_main_loop_destroy(m_loop);
        m_loop = nullptr;
        pw_deinit();
    }

private:
    static void handleTimer(void* data, uint64_t) {
        auto* self = static_cast<MeterWorker*>(data);
        if (self->m_token.stop_requested()) {
            pw_main_loop_quit(self->m_loop);
            return;
        }
        const quint64 gen = self->m_generation.load(std::memory_order_acquire);
        if (gen != self->m_appliedGeneration) {
            self->reconcile(gen);
        }
    }

    static void onStreamProcess(void* data) {
        auto* entry = static_cast<StreamEntry*>(data);
        if (!entry || !entry->stream || !entry->slot) {
            return;
        }
        pw_buffer* const buffer = pw_stream_dequeue_buffer(entry->stream);
        if (!buffer) {
            return;
        }
        const spa_buffer* spaBuf = buffer->buffer;
        if (spaBuf && spaBuf->n_datas > 0 && spaBuf->datas[0].data && spaBuf->datas[0].chunk) {
            const uint32_t maxSize = spaBuf->datas[0].maxsize;
            const uint32_t offset = std::min(spaBuf->datas[0].chunk->offset, maxSize);
            const uint32_t avail = std::min(spaBuf->datas[0].chunk->size, maxSize - offset);
            const uint32_t count = avail / sizeof(float);
            const auto* base = static_cast<const uint8_t*>(spaBuf->datas[0].data);
            const auto* samples = reinterpret_cast<const float*>(base + offset);

            float peak = 0.0f;
            for (uint32_t i = 0; i < count; ++i) {
                const float v = std::fabs(samples[i]);
                if (std::isfinite(v) && v > peak) {
                    peak = v;
                }
            }
            entry->slot->peak.store(std::min(1.0f, peak), std::memory_order_relaxed);
            entry->slot->lastSampleMs.store(currentSteadyMs(), std::memory_order_relaxed);
        }
        pw_stream_queue_buffer(entry->stream, buffer);
    }

    void reconcile(quint64 gen) {
        std::vector<caelestia::shell::services::AudioPeakMonitor::TargetSpec> desired;
        {
            const std::scoped_lock lock(m_targetsMutex);
            desired = m_desiredTargets;
        }
        m_appliedGeneration = gen;

        std::unordered_map<std::string, bool> desiredMap;
        desiredMap.reserve(desired.size());
        for (const auto& t : desired) {
            if (!t.serial.empty()) {
                desiredMap[t.serial] = t.captureSink;
            }
        }

        // Drop streams no longer needed or whose captureSink flag changed.
        for (auto it = m_streams.begin(); it != m_streams.end();) {
            auto found = desiredMap.find(it->first);
            if (found == desiredMap.end() || found->second != it->second->captureSink) {
                destroyStreamEntry(std::move(it->second));
                it = m_streams.erase(it);
            } else {
                ++it;
            }
        }

        // Create missing monitor streams.
        for (const auto& [serial, captureSink] : desiredMap) {
            if (m_streams.contains(serial)) {
                continue;
            }
            auto entry = createStream(serial, captureSink);
            if (entry) {
                m_streams.emplace(serial, std::move(entry));
            }
        }

        std::vector<std::pair<QString, std::shared_ptr<caelestia::shell::services::AudioPeakMonitor::PeakSlot>>> slotList;
        slotList.reserve(m_streams.size());
        for (const auto& [serial, entry] : m_streams) {
            slotList.emplace_back(QString::fromStdString(serial), entry->slot);
        }
        {
            const std::scoped_lock lock(m_slotsMutex);
            m_activeSlots = std::move(slotList);
        }
    }

    std::unique_ptr<StreamEntry> createStream(const std::string& serial, bool captureSink) {
        auto entry = std::make_unique<StreamEntry>();
        entry->serial = serial;
        entry->captureSink = captureSink;
        entry->slot = std::make_shared<caelestia::shell::services::AudioPeakMonitor::PeakSlot>();

        auto* props = pw_properties_new(
            PW_KEY_MEDIA_TYPE, "Audio",
            PW_KEY_MEDIA_CATEGORY, "Capture",
            PW_KEY_MEDIA_ROLE, "DSP",
            PW_KEY_MEDIA_NAME, "Peak detect",
            PW_KEY_APP_NAME, "caelestia-meter",
            PW_KEY_STREAM_MONITOR, "true",
            PW_KEY_NODE_PASSIVE, "true",
            PW_KEY_NODE_DONT_RECONNECT, "true",
            PW_KEY_NODE_RATE, "1/25",
            PW_KEY_NODE_LATENCY, "1/25",
            "resample.peaks", "true",
            PW_KEY_TARGET_OBJECT, serial.c_str(),
            nullptr);
        if (captureSink) {
            pw_properties_set(props, PW_KEY_STREAM_CAPTURE_SINK, "true");
        }

        static const pw_stream_events k_events = [] {
            pw_stream_events e{};
            e.version = PW_VERSION_STREAM_EVENTS;
            e.process = onStreamProcess;
            return e;
        }();

        entry->stream = pw_stream_new_simple(
            pw_main_loop_get_loop(m_loop), "caelestia-meter", props, &k_events, entry.get());
        if (!entry->stream) {
            return nullptr;
        }

        uint8_t buffer[256];
        spa_pod_builder b;
        spa_pod_builder_init(&b, buffer, sizeof(buffer));

        spa_audio_info_raw info{};
        info.format = SPA_AUDIO_FORMAT_F32;
        info.rate = k_peakRateHz;
        info.channels = 1;

        const spa_pod* params[1];
        params[0] = spa_format_audio_raw_build(&b, SPA_PARAM_EnumFormat, &info);

        const auto flags = static_cast<pw_stream_flags>(
            static_cast<quint32>(PW_STREAM_FLAG_AUTOCONNECT) |
            static_cast<quint32>(PW_STREAM_FLAG_MAP_BUFFERS) |
            static_cast<quint32>(PW_STREAM_FLAG_RT_PROCESS) |
            static_cast<quint32>(PW_STREAM_FLAG_DONT_RECONNECT));

        if (pw_stream_connect(entry->stream, PW_DIRECTION_INPUT, PW_ID_ANY, flags, params, 1) < 0) {
            destroyStreamEntry(std::move(entry));
            return nullptr;
        }

        return entry;
    }

    std::stop_token m_token;
    std::mutex& m_targetsMutex;
    const std::vector<caelestia::shell::services::AudioPeakMonitor::TargetSpec>& m_desiredTargets;
    const std::atomic<quint64>& m_generation;
    std::mutex& m_slotsMutex;
    std::vector<std::pair<QString, std::shared_ptr<caelestia::shell::services::AudioPeakMonitor::PeakSlot>>>&
        m_activeSlots;

    pw_main_loop* m_loop = nullptr;
    spa_source* m_timer = nullptr;
    quint64 m_appliedGeneration = 0;
    std::unordered_map<std::string, std::unique_ptr<StreamEntry>> m_streams;
};

} // namespace

namespace caelestia::shell::services {

AudioPeakMonitor::AudioPeakMonitor(QObject* parent)
    : QObject(parent) {
    m_pollTimer.setInterval(40);
    connect(&m_pollTimer, &QTimer::timeout, this, &AudioPeakMonitor::pollPeaks);
}

AudioPeakMonitor::~AudioPeakMonitor() {
    stopWorker();
}

bool AudioPeakMonitor::active() const {
    return m_active;
}

void AudioPeakMonitor::setActive(bool active) {
    if (m_active == active) {
        return;
    }
    m_active = active;
    emit activeChanged();

    if (m_active) {
        startWorker();
    } else {
        stopWorker();
    }
}

QVariantList AudioPeakMonitor::targets() const {
    return m_targets;
}

void AudioPeakMonitor::setTargets(const QVariantList& targets) {
    m_targets = targets;

    std::vector<TargetSpec> parsed;
    parsed.reserve(static_cast<size_t>(targets.size()));
    for (const QVariant& item : targets) {
        const QVariantMap map = item.toMap();
        const QString serial = map.value(QStringLiteral("serial")).toString().trimmed();
        if (serial.isEmpty()) {
            continue;
        }
        parsed.push_back(TargetSpec{
            .serial = serial.toStdString(),
            .captureSink = map.value(QStringLiteral("captureSink")).toBool(),
        });
    }

    {
        const std::scoped_lock lock(m_targetsMutex);
        m_desiredTargets = std::move(parsed);
    }
    m_targetsGeneration.fetch_add(1, std::memory_order_release);
    emit targetsChanged();
}

QVariantMap AudioPeakMonitor::peaks() const {
    return m_peaks;
}

void AudioPeakMonitor::startWorker() {
    if (m_thread.joinable()) {
        return;
    }
    // Force reconcile immediately even if targets were set before activation.
    m_targetsGeneration.fetch_add(1, std::memory_order_release);
    m_thread = std::jthread([this](std::stop_token token) {
        MeterWorker worker(std::move(token), m_targetsMutex, m_desiredTargets, m_targetsGeneration, m_slotsMutex,
            m_activeSlots);
        worker.run();
    });
    m_pollTimer.start();
}

void AudioPeakMonitor::stopWorker() {
    m_pollTimer.stop();
    if (m_thread.joinable()) {
        m_thread.request_stop();
        m_thread.join();
    }
    m_smoothed.clear();
    if (!m_peaks.isEmpty()) {
        m_peaks.clear();
        emit peaksChanged();
    }
}

void AudioPeakMonitor::pollPeaks() {
    std::vector<std::pair<QString, std::shared_ptr<PeakSlot>>> slotList;
    {
        const std::scoped_lock lock(m_slotsMutex);
        slotList = m_activeSlots;
    }

    const qint64 now = currentSteadyMs();
    QVariantMap next;
    bool changed = slotList.size() != static_cast<size_t>(m_peaks.size());

    QHash<QString, float> nextSmoothed;
    nextSmoothed.reserve(static_cast<int>(slotList.size()));

    for (const auto& [serial, slot] : slotList) {
        const qint64 age = now - slot->lastSampleMs.load(std::memory_order_relaxed);
        const float raw = (slot->lastSampleMs.load(std::memory_order_relaxed) > 0 && age <= k_stalePeakMs)
                              ? slot->peak.load(std::memory_order_relaxed)
                              : 0.0f;
        const float prev = m_smoothed.value(serial, 0.0f);
        float level = raw >= prev ? raw : prev * 0.72f;
        if (level < 0.005f) {
            level = 0.0f;
        }

        nextSmoothed.insert(serial, level);
        next.insert(serial, static_cast<double>(level));

        if (!changed) {
            const double prevOut = m_peaks.value(serial, -1.0).toDouble();
            if (prevOut < 0.0 || std::abs(prevOut - static_cast<double>(level)) > 0.004) {
                changed = true;
            }
        }
    }

    m_smoothed = std::move(nextSmoothed);
    if (changed) {
        m_peaks = std::move(next);
        emit peaksChanged();
    }
}

} // namespace caelestia::shell::services
