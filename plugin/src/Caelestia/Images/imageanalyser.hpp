#pragma once

#include <qfuture.h>
#include <qfuturewatcher.h>
#include <qobject.h>
#include <qpointer.h>
#include <qqmlintegration.h>
#include <qhash.h>
#include <qquickitem.h>
#include <qquickitemgrabresult.h>

namespace caelestia::shell::images {

class ImageAnalyser : public QObject {
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(QString source READ source WRITE setSource NOTIFY sourceChanged)
    Q_PROPERTY(QQuickItem* sourceItem READ sourceItem WRITE setSourceItem NOTIFY sourceItemChanged)
    Q_PROPERTY(int rescaleSize READ rescaleSize WRITE setRescaleSize NOTIFY rescaleSizeChanged)
    // Optional: results are shared between all analysers with the same key (an
    // icon's source), so each icon is analysed once, not once per place it shows
    Q_PROPERTY(QString cacheKey READ cacheKey WRITE setCacheKey NOTIFY cacheKeyChanged)
    Q_PROPERTY(QColor dominantColour READ dominantColour NOTIFY dominantColourChanged)
    Q_PROPERTY(qreal luminance READ luminance NOTIFY luminanceChanged)
    Q_PROPERTY(bool analysed READ analysed NOTIFY analysedChanged)
    Q_PROPERTY(bool monochromeDark READ monochromeDark NOTIFY monochromeDarkChanged)
    Q_PROPERTY(bool monochromeLight READ monochromeLight NOTIFY monochromeLightChanged)

public:
    explicit ImageAnalyser(QObject* parent = nullptr);

    [[nodiscard]] QString source() const;
    void setSource(const QString& source);

    [[nodiscard]] QQuickItem* sourceItem() const;
    void setSourceItem(QQuickItem* sourceItem);

    [[nodiscard]] int rescaleSize() const;
    void setRescaleSize(int rescaleSize);

    [[nodiscard]] QString cacheKey() const;
    void setCacheKey(const QString& cacheKey);

    [[nodiscard]] QColor dominantColour() const;
    [[nodiscard]] qreal luminance() const;
    [[nodiscard]] bool analysed() const;
    [[nodiscard]] bool monochromeDark() const;
    [[nodiscard]] bool monochromeLight() const;

    Q_INVOKABLE void requestUpdate();

signals:
    void sourceChanged();
    void sourceItemChanged();
    void rescaleSizeChanged();
    void cacheKeyChanged();
    void dominantColourChanged();
    void luminanceChanged();
    void analysedChanged();
    void monochromeDarkChanged();
    void monochromeLightChanged();

private:
    struct AnalyseResult {
        QColor dominantColour;
        qreal luminance = 0.0;
        bool monochromeDark = false;
        bool monochromeLight = false;
    };

    QFutureWatcher<AnalyseResult>* const m_futureWatcher;

    QString m_source;
    QPointer<QQuickItem> m_sourceItem;
    int m_rescaleSize;
    QString m_cacheKey;
    // The key of the running analysis (its result goes to the cache)
    QString m_jobKey;
    // The last grab (kept until the next one: not freed inside its own signal)
    QSharedPointer<const QQuickItemGrabResult> m_grab;
    QString m_grabKey;
    bool m_grabDone = true;
    bool m_updateQueued = false;
    int m_blankRetries = 0;

    QColor m_dominantColour;
    qreal m_luminance;
    bool m_analysed;
    bool m_monochromeDark;
    bool m_monochromeLight;

    void update();
    void requestUpdateNow();
    [[nodiscard]] QString fullKey() const;
    void applyResult(const AnalyseResult& result);
    static QHash<QString, AnalyseResult>& cache();
    static void analyse(QPromise<AnalyseResult>& promise, const QImage& image, int rescaleSize);
};

} // namespace caelestia::shell::images
