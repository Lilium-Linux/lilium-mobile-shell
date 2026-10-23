.pragma library
.import "../icons/WhiteSur/names.js" as WhiteSur

// An application's icon, by its icon name or desktop id, `size` logical
// pixels wide: WhiteSur's own drawing (icons/WhiteSur, from
// tools/update-whitesur.sh) where it has one, else Solium's lookup in the
// system's icon theme. Which of the two is known before anything loads, so an
// icon never pops in late or changes after its first frame.
var whiteSur = Qt.resolvedUrl("../icons/WhiteSur/apps/scalable/")

function source(name, size) {
    if (!name) return ""
    if (WhiteSur.names.hasOwnProperty(name)) return whiteSur + encodeURIComponent(name) + ".svg"
    return "image://solium/icon/" + name + "?size=" + size
}
