#include "imageanalyser.hpp"

#include <algorithm>
#include <cmath>
#include <qfuturewatcher.h>
#include <qimage.h>
#include <qloggingcategory.h>
#include <qquickitemgrabresult.h>
#include <qquickwindow.h>
#include <qtconcurrentrun.h>
#include <qtimer.h>
#include <unordered_map>

namespace {

Q_LOGGING_CATEGORY(lcImageAnalyser, "caelestia.imageanalyser", QtInfoMsg)

} // namespace

namespace caelestia::shell::images {

ImageAnalyser::ImageAnalyser(QObject* parent)
    : QObject(parent)
    , m_futureWatcher(new QFutureWatcher<AnalyseResult>(this))
    , m_sourceItem(nullptr)
    , m_rescaleSize(128)
    , m_dominantColour(0, 0, 0)
    , m_luminance(0)
    , m_analysed(false)
    , m_monochromeDark(false)
    , m_monochromeLight(false) {
    QObject::connect(m_futureWatcher, &QFutureWatcher<AnalyseResult>::finished, this, [this] {
        if (m_futureWatcher->isCanceled()) {
            return;
        }
        if (!m_futureWatcher->future().isResultReadyAt(0)) {
            // A blank grab (drawn before its image was): tried again shortly
            if (m_sourceItem && m_blankRetries < 2) {
                ++m_blankRetries;
                m_grabKey.clear();
                QTimer::singleShot(250, this, &ImageAnalyser::requestUpdate);
            }
            return;
        }

        m_blankRetries = 0;
        const auto result = m_futureWatcher->result();
        if (!m_jobKey.isEmpty()) {
            auto& c = cache();
            if (c.size() > 1024) {
                c.clear();
            }
            c.insert(m_jobKey, result);
        }
        applyResult(result);
    });
}

QHash<QString, ImageAnalyser::AnalyseResult>& ImageAnalyser::cache() {
    // GUI thread only (filled in the watcher's finished handler)
    static QHash<QString, AnalyseResult> results;
    return results;
}

QString ImageAnalyser::fullKey() const {
    // Only an explicit key: a file read by path (the wallpaper) may change under the same name
    return m_cacheKey.isEmpty() ? QString() : m_cacheKey + QStringLiteral("@") + QString::number(m_rescaleSize);
}

void ImageAnalyser::applyResult(const AnalyseResult& result) {
    if (m_dominantColour != result.dominantColour) {
        m_dominantColour = result.dominantColour;
        emit dominantColourChanged();
    }
    if (!qFuzzyCompare(m_luminance + 1.0, result.luminance + 1.0)) {
        m_luminance = result.luminance;
        emit luminanceChanged();
    }
    if (m_monochromeDark != result.monochromeDark) {
        m_monochromeDark = result.monochromeDark;
        emit monochromeDarkChanged();
    }
    if (m_monochromeLight != result.monochromeLight) {
        m_monochromeLight = result.monochromeLight;
        emit monochromeLightChanged();
    }
    if (!m_analysed) {
        m_analysed = true;
        emit analysedChanged();
    }
}

QString ImageAnalyser::cacheKey() const {
    return m_cacheKey;
}

void ImageAnalyser::setCacheKey(const QString& cacheKey) {
    if (m_cacheKey == cacheKey) {
        return;
    }

    m_cacheKey = cacheKey;
    emit cacheKeyChanged();
    m_blankRetries = 0;

    // A reused delegate: the old image's result no longer applies
    if (m_analysed) {
        m_analysed = false;
        emit analysedChanged();
    }

    requestUpdate();
}

QString ImageAnalyser::source() const {
    return m_source;
}

void ImageAnalyser::setSource(const QString& source) {
    if (m_source == source) {
        return;
    }

    m_source = source;
    emit sourceChanged();

    if (m_analysed) {
        m_analysed = false;
        emit analysedChanged();
    }

    if (m_sourceItem) {
        m_sourceItem = nullptr;
        emit sourceItemChanged();
    }

    requestUpdate();
}

QQuickItem* ImageAnalyser::sourceItem() const {
    return m_sourceItem;
}

void ImageAnalyser::setSourceItem(QQuickItem* sourceItem) {
    if (m_sourceItem == sourceItem) {
        return;
    }

    m_sourceItem = sourceItem;
    emit sourceItemChanged();

    if (!m_source.isEmpty()) {
        m_source.clear();
        emit sourceChanged();
    }

    requestUpdate();
}

int ImageAnalyser::rescaleSize() const {
    return m_rescaleSize;
}

void ImageAnalyser::setRescaleSize(int rescaleSize) {
    if (m_rescaleSize == rescaleSize) {
        return;
    }

    m_rescaleSize = rescaleSize;
    emit rescaleSizeChanged();

    requestUpdate();
}

QColor ImageAnalyser::dominantColour() const {
    return m_dominantColour;
}

qreal ImageAnalyser::luminance() const {
    return m_luminance;
}

bool ImageAnalyser::analysed() const {
    return m_analysed;
}

bool ImageAnalyser::monochromeDark() const {
    return m_monochromeDark;
}

bool ImageAnalyser::monochromeLight() const {
    return m_monochromeLight;
}

void ImageAnalyser::requestUpdate() {
    // Several property changes at once (item, key, size) make one update
    if (m_updateQueued) {
        return;
    }
    m_updateQueued = true;
    QMetaObject::invokeMethod(
        this,
        [this] {
            m_updateQueued = false;
            requestUpdateNow();
        },
        Qt::QueuedConnection);
}

void ImageAnalyser::requestUpdateNow() {
    if (m_source.isEmpty() && !m_sourceItem) {
        return;
    }

    if (!m_sourceItem || (m_sourceItem->window() && m_sourceItem->window()->isVisible() && m_sourceItem->width() > 0 &&
                             m_sourceItem->height() > 0)) {
        update();
    } else if (m_sourceItem) {
        if (!m_sourceItem->window()) {
            QObject::connect(m_sourceItem, &QQuickItem::windowChanged, this, &ImageAnalyser::requestUpdate,
                static_cast<Qt::ConnectionType>(Qt::SingleShotConnection | Qt::UniqueConnection));
        } else if (!m_sourceItem->window()->isVisible()) {
            QObject::connect(m_sourceItem->window(), &QQuickWindow::visibleChanged, this, &ImageAnalyser::requestUpdate,
                static_cast<Qt::ConnectionType>(Qt::SingleShotConnection | Qt::UniqueConnection));
        }
        if (m_sourceItem->width() <= 0) {
            QObject::connect(
                m_sourceItem, &QQuickItem::widthChanged, this, &ImageAnalyser::requestUpdate, static_cast<Qt::ConnectionType>(Qt::SingleShotConnection | Qt::UniqueConnection));
        }
        if (m_sourceItem->height() <= 0) {
            QObject::connect(m_sourceItem, &QQuickItem::heightChanged, this, &ImageAnalyser::requestUpdate,
                static_cast<Qt::ConnectionType>(Qt::SingleShotConnection | Qt::UniqueConnection));
        }
    }
}

void ImageAnalyser::update() {
    if (m_source.isEmpty() && !m_sourceItem) {
        return;
    }

    const QString key = fullKey();
    if (!key.isEmpty()) {
        const auto it = cache().constFind(key);
        if (it != cache().constEnd()) {
            if (m_futureWatcher->isRunning()) {
                m_futureWatcher->cancel();
            }
            applyResult(*it);
            return;
        }
    }

    if (m_sourceItem) {
        // The same image is already being grabbed
        if (m_grab && !m_grabDone && !key.isEmpty() && key == m_grabKey) {
            return;
        }
        if (m_futureWatcher->isRunning()) {
            m_futureWatcher->cancel();
        }
        m_grab = m_sourceItem->grabToImage();
        if (!m_grab) {
            QObject::connect(m_sourceItem, &QQuickItem::windowChanged, this, &ImageAnalyser::requestUpdate,
                static_cast<Qt::ConnectionType>(Qt::SingleShotConnection | Qt::UniqueConnection));
            return;
        }
        m_grabKey = key;
        m_grabDone = false;
        // A raw pointer: capturing the shared pointer kept every grab alive
        const QQuickItemGrabResult* grab = m_grab.data();
        QObject::connect(grab, &QQuickItemGrabResult::ready, this, [this, grab] {
            if (m_grab.data() != grab) {
                return;
            }
            m_grabDone = true;
            m_jobKey = m_grabKey;
            m_futureWatcher->setFuture(QtConcurrent::run(&ImageAnalyser::analyse, grab->image(), m_rescaleSize));
        });
    } else {
        if (m_futureWatcher->isRunning()) {
            m_futureWatcher->cancel();
        }
        m_jobKey = key;
        m_futureWatcher->setFuture(QtConcurrent::run([=, this](QPromise<AnalyseResult>& promise) {
            const QImage image(m_source);
            analyse(promise, image, m_rescaleSize);
        }));
    }
}

void ImageAnalyser::analyse(QPromise<AnalyseResult>& promise, const QImage& image, int rescaleSize) {
    if (image.isNull()) {
        qCWarning(lcImageAnalyser) << "analyse: image is null";
        return;
    }

    QImage img = image;

    if (rescaleSize > 0 && (img.width() > rescaleSize || img.height() > rescaleSize)) {
        img = img.scaled(rescaleSize, rescaleSize, Qt::KeepAspectRatio, Qt::FastTransformation);
    }

    if (promise.isCanceled()) {
        return;
    }

    if (img.format() != QImage::Format_ARGB32) {
        img = img.convertToFormat(QImage::Format_ARGB32);
    }

    if (promise.isCanceled()) {
        return;
    }

    const uchar* data = img.bits();
    const int width = img.width();
    const int height = img.height();
    const qsizetype bytesPerLine = img.bytesPerLine();

    std::unordered_map<quint32, int> colours;
    qreal totalLuminance = 0.0;
    int count = 0;

    int solidLumHist[256] = {};
    int solidChromaHist[256] = {};
    qreal solidChromaSum = 0.0;
    int solidCount = 0;

    int faintLumHist[256] = {};
    int faintChromaHist[256] = {};
    qreal faintChromaSum = 0.0;
    int faintCount = 0;

    for (int y = 0; y < height; ++y) {
        const uchar* line = data + y * bytesPerLine;
        for (int x = 0; x < width; ++x) {
            if (promise.isCanceled()) {
                return;
            }

            const uchar* pixel = line + (static_cast<qsizetype>(x) * 4);

            if (pixel[3] == 0) {
                continue;
            }

            const auto mr = static_cast<quint32>(pixel[2] & 0xF8u);
            const auto mg = static_cast<quint32>(pixel[1] & 0xF8u);
            const auto mb = static_cast<quint32>(pixel[0] & 0xF8u);
            ++colours[(mr << 16u) | (mg << 8u) | mb];

            const qreal r = pixel[2] / 255.0;
            const qreal g = pixel[1] / 255.0;
            const qreal b = pixel[0] / 255.0;
            const qreal lum = std::sqrt(0.299 * r * r + 0.587 * g * g + 0.114 * b * b);
            const qreal chroma = std::max({ r, g, b }) - std::min({ r, g, b });
            const int lumBin = std::clamp(static_cast<int>(lum * 255.0 + 0.5), 0, 255);
            const int chromaBin = std::clamp(static_cast<int>(chroma * 255.0 + 0.5), 0, 255);

            totalLuminance += lum;
            ++count;

            if (pixel[3] >= 64) {
                ++solidLumHist[lumBin];
                ++solidChromaHist[chromaBin];
                solidChromaSum += chroma;
                ++solidCount;
            } else {
                ++faintLumHist[lumBin];
                ++faintChromaHist[chromaBin];
                faintChromaSum += chroma;
                ++faintCount;
            }
        }
    }

    quint32 dominantColour = 0;
    int maxCount = 0;
    for (const auto& [colour, colourCount] : colours) {
        if (promise.isCanceled()) {
            return;
        }

        if (colourCount > maxCount) {
            dominantColour = colour;
            maxCount = colourCount;
        }
    }

    const bool useSolid = solidCount > 0;
    const int statCount = useSolid ? solidCount : faintCount;
    const int* lumHist = useSolid ? solidLumHist : faintLumHist;
    const int* chromaHist = useSolid ? solidChromaHist : faintChromaHist;
    const qreal avgChroma = statCount > 0 ? (useSolid ? solidChromaSum : faintChromaSum) / statCount : 0.0;

    auto percentile = [statCount](const int hist[256], qreal frac) -> qreal {
        if (statCount <= 0) {
            return 0.0;
        }
        const int target = std::clamp(static_cast<int>(std::ceil(frac * statCount)), 1, statCount);
        int acc = 0;
        for (int i = 0; i < 256; ++i) {
            acc += hist[i];
            if (acc >= target) {
                return static_cast<qreal>(i) / 255.0;
            }
        }
        return 1.0;
    };

    // Nothing drawn yet (an icon grabbed before it loaded): no result, so a
    // blank grab is never taken (or cached) as the icon's colours
    if (count == 0) {
        return;
    }

    const qreal p05Lum = percentile(lumHist, 0.05);
    const qreal p95Lum = percentile(lumHist, 0.95);
    const qreal p95Chroma = percentile(chromaHist, 0.95);
    const bool isMonochrome = statCount > 0 && avgChroma < 0.12 && p95Chroma < 0.18;

    AnalyseResult result;
    result.dominantColour = QColor((0xFFu << 24u) | dominantColour);
    result.luminance = count == 0 ? 0.0 : totalLuminance / count;
    result.monochromeDark = isMonochrome && p95Lum < 0.42;
    result.monochromeLight = isMonochrome && p05Lum > 0.70;
    promise.addResult(result);
}

} // namespace caelestia::shell::images
