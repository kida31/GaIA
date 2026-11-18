; Game Input Assistance — the ini file layer.
;
; Everything that knows the config file's name, location and syntax lives here,
; and nothing about what the sections mean: a file goes in, ordered sections come
; out, and back. Bindings, camera steps, defaults and clamps are the settings
; record's business (settings.ahk), which is this file's only caller.
;
;   sections := ReadSections([path])            ; Array of {name, pairs}, file order
;   WriteSections(sections, [path, header])
;
; A pair is {name, value}, or {comment: text} which the writer emits as "; text"
; so the file can document itself for whoever edits it by hand. Swapping the
; format (JSON, XML, ...) means rewriting this file; nothing else moves. The main
; script never calls IniRead and never learns the file's name.

/**
 * The config file's path, next to the script.
 * @returns {String} absolute path to config.ini
 */
ConfigPath() => A_ScriptDir . "\config.ini"

/**
 * True when the file holds at least one [section] — a pre-v2 file does not.
 * @param {String} path - ini file to inspect (default: ConfigPath())
 * @returns {Integer} 1 when any section exists, else 0
 */
HasSections(path := ConfigPath()) => IniRead(path, , , "") != ""

/**
 * One section's "name = value" pairs, in file order. IniRead drops comments and
 * blank lines; quotes around a value are stripped here so it does not matter
 * which IniRead form keeps them.
 * @param {String} path - ini file to read
 * @param {String} section - section name, without the brackets
 * @returns {Array<Object>} {name, value} pairs, in file order
 */
SectionPairs(path, section) {
    pairs := []
    for line in StrSplit(IniRead(path, section, , ""), "`n", "`r") {
        pos := InStr(line, "=")
        if !pos
            continue
        value := Trim(SubStr(line, pos + 1))
        if (StrLen(value) > 1 && (value ~= '^".*"$' || value ~= "^'.*'$"))
            value := SubStr(value, 2, -1)
        pairs.Push({ name: Trim(SubStr(line, 1, pos - 1)), value: value })
    }
    return pairs
}

/**
 * Every section in the file, without the brackets.
 * @param {String} path - ini file to read
 * @returns {Array<String>} section names, in file order
 */
SectionNames(path) {
    names := []
    for name in StrSplit(IniRead(path, , , ""), "`n", "`r")
        if (Trim(name) != "")
            names.Push(Trim(name))
    return names
}

/**
 * The whole file. An Array, not a Map: AHK's Map order is unspecified and a save
 * must not reorder the sections the user wrote.
 * @param {String} path - ini file to read (default: ConfigPath())
 * @returns {Array<Object>} {name, pairs} sections, in file order
 */
ReadSections(path := ConfigPath()) {
    sections := []
    for name in SectionNames(path)
        sections.Push({ name: name, pairs: SectionPairs(path, name) })
    return sections
}

/**
 * A value that is empty, starts with ";" or has edges is quoted; IniRead strips
 * the outer quotes on read, so ";" survives as a key.
 * @param {String} v - value about to be written
 * @returns {String} the value, quoted when it needs to be
 */
QuoteIniValue(v) {
    return (v = "" || SubStr(v, 1, 1) = ";" || Trim(v) != v) ? '"' . v . '"' : v
}

/**
 * Replace the file with these sections, in this order: the optional header line,
 * one blank line between sections, no trailing blank.
 * @param {Array<Object>} sections - {name, pairs} sections to write, in order
 * @param {String} path - ini file to write (default: ConfigPath())
 * @param {String} header - comment line at the top, "" for none
 * @returns {String} ""
 */
WriteSections(sections, path := ConfigPath(), header := "") {
    lines := []
    if (header != "")
        lines.Push(header, "")
    for section in sections {
        if (lines.Length && lines[lines.Length] != "")
            lines.Push("")
        lines.Push("[" . section.name . "]")
        for p in section.pairs
            if p.Has("comment")
                lines.Push("; " . p.comment)
            else
                lines.Push(p.name . " = " . QuoteIniValue(p.value))
    }
    while (lines.Length && Trim(lines[lines.Length]) = "")
        lines.Pop()
    WriteLines(path, lines)
}

/**
 * Write through a temp file so a crash cannot eat the user's settings. UTF-16
 * because IniRead only reads Unicode from a UTF-16 file.
 * @param {String} path - file to write
 * @param {Array<String>} lines - lines, written CRLF, no trailing blank added
 * @returns {String} ""
 */
WriteLines(path, lines) {
    text := ""
    for line in lines
        text .= line . "`r`n"
    tmp := path . ".tmp"
    if FileExist(tmp)
        FileDelete(tmp)
    FileAppend(text, tmp, "UTF-16")
    FileMove(tmp, path, 1)
}
