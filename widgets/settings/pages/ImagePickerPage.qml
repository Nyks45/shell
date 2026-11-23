import QtQuick
import QtQuick.Layouts
import qs.widgets.components
import qs.widgets.services
import qs.widgets.theme

ColumnLayout {
    id: page

    signal navigate(string target)

    function choose(path) {
        if (Widgets.replacing !== "") {
            const id = Widgets.replacing;
            Widgets.replacing = "";
            Widgets.update(id, { source: path });
            navigate("widget:" + id);
            return;
        }
        navigate("widget:" + Widgets.add("image", { source: path }));
    }

    spacing: Theme.spacing.lg

    ImageBrowser {
        Layout.fillWidth: true
        onChosen: path => page.choose(path)
    }
}
