#pragma once

#include <qhash.h>
#include <qjsonobject.h>
#include <qnetworkaccessmanager.h>
#include <qnetworkreply.h>
#include <qtimer.h>
#include <qtcpserver.h>

#include "lyriccandidate.hpp"

namespace caelestia::shell::services {

struct LyricLine {
    qreal time = 0.0;
    QString text;
};

class Lyrics : public QObject {
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    Q_PROPERTY(QStringList lyrics READ lyrics NOTIFY lyricsChanged)
    Q_PROPERTY(caelestia::shell::config::LyricsBackend::Enum backend READ backend NOTIFY backendChanged)
    Q_PROPERTY(caelestia::shell::config::LyricsBackend::Enum preferredBackend READ preferredBackend WRITE
            setPreferredBackend NOTIFY preferredBackendChanged)
    Q_PROPERTY(QList<caelestia::shell::services::LyricCandidate> lyricCandidates READ lyricCandidates NOTIFY
            lyricCandidatesChanged)
    Q_PROPERTY(caelestia::shell::services::LyricCandidate selectedCandidate READ selectedCandidate WRITE
            setSelectedCandidate NOTIFY selectedCandidateChanged)
    Q_PROPERTY(bool loading READ loading NOTIFY loadingChanged)
    Q_PROPERTY(bool hasLyrics READ hasLyrics NOTIFY hasLyricsChanged)
    Q_PROPERTY(qreal offset READ offset WRITE setOffset NOTIFY offsetChanged)
    Q_PROPERTY(QString trackArtist READ trackArtist NOTIFY trackChanged)
    Q_PROPERTY(QString trackTitle READ trackTitle NOTIFY trackChanged)

public:
    explicit Lyrics(QObject* parent = nullptr);

    [[nodiscard]] QStringList lyrics() const;
    [[nodiscard]] LyricsBackend backend() const;
    [[nodiscard]] LyricsBackend preferredBackend() const;
    void setPreferredBackend(LyricsBackend value);
    [[nodiscard]] QList<LyricCandidate> lyricCandidates() const;
    [[nodiscard]] LyricCandidate selectedCandidate() const;
    void setSelectedCandidate(const LyricCandidate& value);
    [[nodiscard]] bool loading() const;
    [[nodiscard]] bool hasLyrics() const;
    [[nodiscard]] qreal offset() const;
    void setOffset(qreal value);
    [[nodiscard]] QString trackArtist() const;
    [[nodiscard]] QString trackTitle() const;

    [[nodiscard]] Q_INVOKABLE int indexForTime(qreal time) const;
    [[nodiscard]] Q_INVOKABLE qreal timeForIndex(int index) const;
    Q_INVOKABLE void setTrack(
        const QString& artist, const QString& title, const QString& album = {}, qreal duration = 0.0);
    Q_INVOKABLE void clearTrack();
    Q_INVOKABLE void refresh();

signals:
    void lyricsChanged();
    void backendChanged();
    void preferredBackendChanged();
    void lyricCandidatesChanged();
    void selectedCandidateChanged();
    void loadingChanged();
    void hasLyricsChanged();
    void offsetChanged();
    void trackChanged();

private:
    void setBackend(LyricsBackend value);
    void setLoading(bool value);
    void setLines(QVector<LyricLine> lines, LyricsBackend source);
    void clearLines();
    void appendCandidates(const QList<LyricCandidate>& add);
    void clearCandidates();

    void scheduleLoad();
    void doLoad();
    void cancelInFlight();
    int newRequestId();

    // Spotify's own lyrics, handed over by the Spicetify extension (caelestia-lyrics.js) on
    // 127.0.0.1:47812: used first for the song they're for
    void startBridge();
    void onBridgePayload(const QJsonObject& obj);
    bool applyBridge();
    [[nodiscard]] static QString bridgeKey(const QString& artist, const QString& title);

    void tryLocal(int reqId);
    void tryLrclib(int reqId);
    // LRCLIB's search (cleaned title/artist, any album, nearest length) when its exact /get misses
    void tryLrclibSearch(int reqId);
    // Plain (untimed) lyrics as lines spread over the song: the last resort
    [[nodiscard]] QVector<LyricLine> plainToLines(const QString& text) const;
    void tryNetEase(int reqId);
    // Untimed lyrics from lyrics.ovh (a free public API): the last resort, spread over the song
    void tryLyricsOvh(int reqId);
    void chainNext(LyricsBackend justFailed, int reqId);

    void searchLrclibCandidates(int reqId);
    void searchNetEaseCandidates(int reqId);

    void fetchLrclibById(const QString& id, int reqId);
    void fetchNetEaseLyricsById(const QString& id, int reqId);

    QNetworkReply* getJson(const QUrl& url, const QHash<QByteArray, QByteArray>& headers = {});
    void trackReply(int reqId, QNetworkReply* reply);

    void onPreferredBackendConfigChanged();
    void onLyricsDirChanged();

    void loadLyricsMap();
    void persistTrackPrefs();

    [[nodiscard]] static QString lyricsDir();
    [[nodiscard]] static QString lyricsMapPath();
    [[nodiscard]] QString trackKey() const;
    [[nodiscard]] static QString backendKey(LyricsBackend value);
    [[nodiscard]] static LyricsBackend backendFromKey(const QString& key);

    [[nodiscard]] static const QString& stateDir();
    [[nodiscard]] static const QString& cacheDir();
    [[nodiscard]] static QString cachePathFor(LyricsBackend backend, const QString& id);
    [[nodiscard]] static QString readCachedLrc(LyricsBackend backend, const QString& id);
    static void writeCachedLrc(LyricsBackend backend, const QString& id, const QString& text);

    [[nodiscard]] static QVector<LyricLine> parseLrc(const QString& text);
    [[nodiscard]] static QString tryReadLocalLrc(const QString& dir, const QString& artist, const QString& title);
    [[nodiscard]] static QString findLocalLrcRecursive(const QString& dir, const QString& artist, const QString& title);

    QNetworkAccessManager* m_nam;
    QTimer* m_loadDebounce;

    QVector<LyricLine> m_lines;
    QStringList m_lyrics;
    LyricsBackend m_backend = LyricsBackend::Auto;
    LyricsBackend m_preferredBackend = LyricsBackend::Auto;
    QList<LyricCandidate> m_candidates;
    LyricCandidate m_selected;
    bool m_loading = false;
    bool m_hasLyrics = false;
    qreal m_offset = 0.0;

    QString m_artist;
    QString m_title;
    QString m_album;
    qreal m_duration = 0.0;
    // Plain lyrics found on the way (no synced ones yet): shown if nothing synced turns up
    QString m_plainFallback;
    bool m_triedOvh = false;

    int m_currentRequestId = 0;
    QHash<int, QList<QPointer<QNetworkReply>>> m_pendingReplies;

    QTcpServer* m_bridge = nullptr;
    struct BridgeLyrics {
        bool synced = false;
        QString text;
    };
    QHash<QString, BridgeLyrics> m_bridgeLyrics;
    // The lines shown came from the bridge (Spotify's): nothing else replaces them
    bool m_fromBridge = false;

    QJsonObject m_lyricsMap;
    bool m_lyricsMapLoaded = false;
    bool m_settingFromPrefs = false;
};

} // namespace caelestia::shell::services
