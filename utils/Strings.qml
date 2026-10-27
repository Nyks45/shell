pragma Singleton

import Quickshell
import Caelestia.I18n

Singleton {
    property var _regexCache: ({})

    function percent(value: int): string {
        // TRANSLATORS: %1 = a number
        return Tr.tr("%1%").arg(value);
    }

    function percentOne(value: real): string {
        return percent(Math.round(value * 100));
    }

    function testRegexList(filterList: list<string>, target: string): bool {
        const regexChecker = /^\^.*\$$/;
        for (const filter of filterList) {
            if (regexChecker.test(filter)) {
                let re = _regexCache[filter];
                if (!re) {
                    re = new RegExp(filter);
                    _regexCache[filter] = re;
                }
                if (re.test(target))
                    return true;
            } else {
                if (filter === target)
                    return true;
            }
        }
        return false;
    }

    // Every match of a global regex (String.matchAll, which Qt's JS lacks)
    function allMatches(text: string, re: var): var {
        const out = [];
        const g = new RegExp(re.source, re.flags.includes("g") ? re.flags : re.flags + "g");
        let m;
        while ((m = g.exec(text)) !== null) {
            out.push(m);
            if (m[0] === "")
                g.lastIndex++;
        }
        return out;
    }
}
