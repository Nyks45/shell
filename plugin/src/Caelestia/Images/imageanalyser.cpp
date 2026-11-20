#include "imageanalyser.hpp"

#include <algorithm>
#include <cmath>
#include <qfuturewatcher.h>
#include <qimage.h>
#include <qloggingcategory.h>
#include <qquickitemgrabresult.h>
#include <qquickwindow.h>
#include <qtconcurrentrun.h>
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
        if (!m_futureWatcher->future().isResultReadyAt(0)) {
            return;
        }

        const auto result = m_futureWatcher->result();
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
    });
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
    if (m_source.isEmpty() && !m_sourceItem) {
        return;
    }

    if (!m_sourceItem || (m_sourceItem->window() && m_sourceItem->window()->isVisible() && m_sourceItem->width() > 0 &&
                             m_sourceItem->height() > 0)) {
        update();
    } else if (m_sourceItem) {
        if (!m_sourceItem->window()) {
            QObject::connect(m_sourceItem, &QQuickItem::windowChanged, this, &ImageAnalyser::requestUpdate,
                Qt::SingleShotConnection);
        } else if (!m_sourceItem->window()->isVisible()) {
            QObject::connect(m_sourceItem->window(), &QQuickWindow::visibleChanged, this, &ImageAnalyser::requestUpdate,
                Qt::SingleShotConnection);
        }
        if (m_sourceItem->width() <= 0) {
            QObject::connect(
                m_sourceItem, &QQuickItem::widthChanged, this, &ImageAnalyser::requestUpdate, Qt::SingleShotConnection);
        }
        if (m_sourceItem->height() <= 0) {
            QObject::connect(m_sourceItem, &QQuickItem::heightChanged, this, &ImageAnalyser::requestUpdate,
                Qt::SingleShotConnection);
        }
    }
}

void ImageAnalyser::update() {
    if (m_source.isEmpty() && !m_sourceItem) {
        return;
    }

    if (m_futureWatcher->isRunning()) {
        m_futureWatcher->cancel();
    }

    if (m_sourceItem) {
        const QSharedPointer<const QQuickItemGrabResult> grabResult = m_sourceItem->grabToImage();
        if (!grabResult) {
            QObject::connect(m_sourceItem, &QQuickItem::windowChanged, this, &ImageAnalyser::requestUpdate,
                Qt::SingleShotConnection);
            return;
        }
        QObject::connect(grabResult.data(), &QQuickItemGrabResult::ready, this, [grabResult, this] {
            m_futureWatcher->setFuture(QtConcurrent::run(&ImageAnalyser::analyse, grabResult->image(), m_rescaleSize));
        });
    } else {
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
