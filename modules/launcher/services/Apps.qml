pragma Singleton

import Quickshell
import Caelestia.Config
import Caelestia.Models
import qs.utils
import qs.modules.nexus

Searcher {
    id: root

    function launch(entry: DesktopEntry): void {
        appDb.incrementFrequency(entry.id);

        if (entry.id === "caelestia-settings" || entry.id === "caelestia-settings.desktop") {
            WindowFactory.create();
            return;
        }

        if (entry.runInTerminal)
            Quickshell.execDetached({
                command: [...GlobalConfig.general.apps.terminal, `${Quickshell.shellDir}/assets/wrap_term_launch.sh`, ...entry.command],
                workingDirectory: entry.workingDirectory
            });
        else
            entry.execute();
    }

    function setSearchKeys(nextKeys: list<string>, nextWeights: list<real>): void {
        let sameKeys = keys.length === nextKeys.length;
        for (let i = 0; sameKeys && i < nextKeys.length; i++)
            sameKeys = keys[i] === nextKeys[i];
        if (!sameKeys)
            keys = nextKeys;

        let sameWeights = weights.length === nextWeights.length;
        for (let i = 0; sameWeights && i < nextWeights.length; i++)
            sameWeights = weights[i] === nextWeights[i];
        if (!sameWeights)
            weights = nextWeights;
    }

    function search(search: string): var {
        const prefix = GlobalConfig.launcher.specialPrefix;
        const lower = search.toLowerCase();
        const lowerPrefix = prefix.toLowerCase();
        const fieldMap = ({
            i: "id",
            c: "categories",
            d: "comment",
            e: "execString",
            w: "startupClass",
            g: "genericName",
            k: "keywords"
        });

        for (const [flag, field] of Object.entries(fieldMap)) {
            if (lower.startsWith(`${lowerPrefix}${flag} `)) {
                setSearchKeys([field, "name"], [0.9, 0.1]);
                return query(search.slice(prefix.length + 2)).map(e => e.entry);
            }
        }

        setSearchKeys(["name"], [1]);
        if (lower.startsWith(`${lowerPrefix}t `))
            return query(search.slice(prefix.length + 2)).map(e => e.entry).filter(a => a.runInTerminal);
        return query(search).map(e => e.entry);
    }

    function selector(item: var): string {
        return keys.map(k => item[k]).join(" ");
    }

    list: appDb.apps
    useFuzzy: GlobalConfig.launcher.useFuzzy.apps

    AppDb {
        id: appDb

        path: `${Paths.state}/apps.sqlite`
        favouriteApps: GlobalConfig.launcher.favouriteApps
        entries: DesktopEntries.applications.values.filter(a => !Strings.testRegexList(GlobalConfig.launcher.hiddenApps, a.id))
    }
}
