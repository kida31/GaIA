; The settings record and everything that gives it meaning: the defaults, the
; clamps, the field names, the duplicate-key check, and the shape the record
; takes in the file (LoadSettings / SaveSettings and the row and camera
; formatting). It reaches the disk only through config.ahk, which knows the
; syntax, and only when those two are called — so the self-check can include it
; without reading your real config.ini.
;
; Included by game-assistant.ahk and game-assistant.test.ahk. Nothing here runs
; on include, so both can load it.

/**
 * @typedef {Object} Binding
 * @property {String} trigger    one or more comma-separated keys
 * @property {"repeat-key"|"repeat-click"|"hold-click"} action
 * @property {String} target     key or mouse button; "" when the action needs none
 * @property {Integer} timing    ms between repeats, 20..2000
 * @property {Integer} linger    ms held after the last repeat, 0..5000
 * @property {String} group      common identifier between bindings or "" for none (written as "-" on disk)
 */

/**
 * @typedef {Object} Camera
 * @property {String} up         key name
 * @property {String} down       key name
 * @property {String} left       key name
 * @property {String} right      key name
 * @property {Integer} tapstep   px per nudge, 5..5000, multiple of 5
 * @property {Integer} panstep   px per pan tick, 5..5000, multiple of 5
 * @property {Integer} pantick   ms between pan ticks, 1..200
 * @property {Integer} tapms     a press shorter than this is a tap, 20..1000
 */

/**
 * A file line: a key/value, a bare comment, or both, carried through untouched.
 * @typedef {Object} IniPair
 * @property {String} [name]
 * @property {String} [value]
 * @property {String} [comment]
 */

/**
 * @typedef {Object} IniSection
 * @property {String} name
 * @property {Array<IniPair>} pairs
 */

/**
 * What the file holds that the record does not use, so a save writes it back.
 * @typedef {Map} RawSettings
 * @property {Array<IniPair>} meta
 * @property {Array<IniPair>} camera
 * @property {Array<IniPair>} bindings
 * @property {Array<IniSection>} sections
 */

/**
 * @typedef {Object} Settings
 * @property {Array<Binding>} bindings
 * @property {Camera} camera
 * @property {String} game       window title pattern the hotkeys watch for
 * @property {RawSettings} raw
 */

;--- Enums ---

class ActionType {
    static REPEAT_CLICK_DEPRECATED:= "repeat-click" ;DEPRECATED; Use REPEAT for LButton instead
    static REPEAT:= "repeat"    ; Repeat the trigger key or click the target button
    static HOLD:= "hold-click"  ; Hold the target button for the linger duration, then release
}

;--- --- ---

/**
 * The built-in record used when there is no file, or as the base a load fills in.
 * @returns {Settings} {bindings: Array<Binding>, camera: Camera, game: String, raw: Map}
 */
DefaultSettings() {
    return {
        bindings: [
            {
                trigger: "Space",
                action: ActionType.REPEAT,
                target: "Space",
                timing: 150,
                linger: 0,
                group: ""
            },
            {
                trigger: "1",
                action: ActionType.REPEAT,
                target: "1",
                timing: 100,
                linger: 800,
                group: "switch"
            },
            {
                trigger: "2",
                action: ActionType.REPEAT,
                target: "2",
                timing: 100,
                linger: 800,
                group: "switch"
            },
            {
                trigger: "3",
                action: ActionType.REPEAT,
                target: "3",
                timing: 100,
                linger: 800,
                group: "switch"
            },
            {
                trigger: "4",
                action: ActionType.REPEAT,
                target: "4",
                timing: 100,
                linger: 800,
                group: "switch"
            },
            {
                trigger: "5",
                action: ActionType.REPEAT,
                target: "5",
                timing: 100,
                linger: 800,
                group: "switch"
            },
            {
                trigger: "i",
                action: ActionType.REPEAT,
                target: "LButton",
                timing: 150,
                linger: 0,
                group: ""
            },
            {
                trigger: "p",
                action: ActionType.HOLD,
                target: "LButton",
                timing: 0,
                linger: 350,
                group: ""
            },
        ],
        camera: {
            up: "o",
            down: "l",
            left: "k",
            right: ";",
            tapstep: 500,
            panstep: 60,
            pantick: 40,
            tapms: 200
        },
        game: "ahk_exe (GenshinImpact|YuanShen|HTGame)\.exe$",
        ; keys and sections the file has but we do not use
        raw: Map("meta", [], "camera", [], "bindings", [], "sections", [])
    }
}

/**
 * Hold v inside [lo, hi].
 * @param {Number} v - value to clamp
 * @param {Number} lo - lower bound
 * @param {Number} hi - upper bound
 * @returns {Number} v, or the nearest bound
 */
Clamp(v, lo, hi) => Min(Max(v, lo), hi)

/**
 * Camera steps are multiples of 5 so the 5-way split of a tap keeps its distance.
 * @param {Number} v - requested step in pixels
 * @returns {Integer} clamped to 5..5000 and rounded to a multiple of 5
 */
Step(v) => Round(Clamp(v, 5, 5000) / 5) * 5

/**
 * Values keep their leading integer, so a hand-written trailing "; note" is fine.
 * @param {String} text - value text from the file
 * @param {Integer} fallback - used when text does not start with an integer
 * @returns {Integer} the parsed value, or fallback
 */
ParseNum(text, fallback) {
    if RegExMatch(text, "^\s*(-?\d+)", &m)
        return Integer(m[1])
    return fallback
}

/**
 * The camera keys, in the order the file and the window show them.
 * @returns {Array<String>} field names
 */
CameraFields() {
    static fields := [
        "up",
        "down",
        "left",
        "right",
        "tapstep",
        "panstep",
        "pantick",
        "tapms"
    ]
    return fields
}

/**
 * The binding fields, in the order FormatBinding writes them.
 * @returns {Array<String>} field names
 */
BindingFields() {
    static fields := [
        "trigger",
        "action",
        "target",
        "timing",
        "linger",
        "group"
    ]
    return fields
}

/**
 * Case-insensitive test for a known [camera] key.
 * @param {String} name - key name from the file
 * @returns {Integer} 1 when name is a camera field, else 0
 */
IsCameraField(name) {
    for f in CameraFields()
        if (f = StrLower(name))
            return true
    return false
}

/**
 * Sanitise one [camera] value into the record: keys are trimmed, numbers get
 * their clamp and step rule.
 * @param {Camera} c - camera map to update
 * @param {String} name - camera field, already lowercased
 * @param {String} value - raw value from the file
 * @returns {String} ""
 */
SetCamera(c, name, value) {
    switch name {
        case "up", "down", "left", "right":
            if (Trim(value) != "")
                c[name] := Trim(value)
        case "tapstep", "panstep":
            c[name] := Step(ParseNum(value, c[name]))
        case "pantick":
            c[name] := Clamp(ParseNum(value, c[name]), 1, 200)
        case "tapms":
            c[name] := Clamp(ParseNum(value, c[name]), 20, 1000)
    }
}

/**
 * Every trigger, camera key and the quit key must be different. Returns "" when
 * the records are usable, otherwise a message for the user.
 * @param {Settings} s - settings record to check
 * @returns {String} "" when usable, else the reason
 */
ConfigProblem(s) {
    seen := Map()
    for b in s.bindings
        for k in StrSplit(b.trigger, ",") {
            k := StrLower(Trim(k))
            if (k = "")
                return "a binding has no trigger"
            if seen.Has(k)
                return "key " . k . " is used twice"
            seen[k] := true
        }
    for f in [
        "up",
        "down",
        "left",
        "right"
    ] {
        k := StrLower(Trim(s.camera.%f%))
        if (k = "")
            return "camera " . f . " has no key"
        if seen.Has(k)
            return "key " . k . " is used twice"
        seen[k] := true
    }
    return seen.Has("end") ? "key End is reserved for quitting" : ""
}

; ===== the record as the file holds it =====

/**
 * One "trigger | action | target | timing | linger | group" row. Missing parts
 * and unknown actions fall back to the defaults.
 * @param {String} text - row value from the file
 * @returns {Binding} {trigger, action, target, timing, linger, group}
 */
ParseBinding(text) {
    parts := StrSplit(text, "|")
    while (parts.Length < 6)
        parts.Push("")
    action := StrLower(Trim(parts[2]))
    if (action != "repeat-key" && action != "repeat-click" && action != "hold-click")
        action := "repeat-key"
    target := Trim(parts[3])
    group := Trim(parts[6])
    return {
        trigger: Trim(parts[1]),
        action: action,
        target: (target = "-" ? "" : target),
        timing: Clamp(ParseNum(parts[4], 70), 20, 2000),
        linger: Clamp(ParseNum(parts[5], 0), 0, 5000),
        group: (group = "-" ? "" : group)
    }
}

/**
 * The record as one "trigger | action | target | timing | linger | group" row.
 * @param {Binding} b - binding record
 * @returns {String} the row
 */
FormatBinding(b) {
    return b.trigger . " | " . b.action . " | " . b.target . " | " . b.timing . " | " . b.linger . " | " . (b.group =
        "" ? "-" : b.group)
}

/**
 * The [camera] pairs, comments included: the file documents itself for whoever
 * edits it by hand.
 * @param {Camera} c - camera map
 * @returns {Array<IniPair>} {name, value} and {comment} entries, in file order
 */
CameraPairs(c) {
    return [
        {
            comment: "hold a key to pan, tap it to nudge"
        },
        {
            name: "up",
            value: c.up
        },
        {
            name: "down",
            value: c.down
        },
        {
            name: "left",
            value: c.left
        },
        {
            name: "right",
            value: c.right
        },
        {
            comment: "pixels per nudge, sent in 5 moves"
        },
        {
            name: "tapstep",
            value: c["tapstep"]
        },
        {
            comment: "pixels per pan tick"
        },
        {
            name: "panstep",
            value: c["panstep"]
        },
        {
            comment: "ms between pan ticks"
        },
        {
            name: "pantick",
            value: c["pantick"]
        },
        {
            comment: "a press shorter than this is a tap"
        },
        {
            name: "tapms",
            value: c[
                "tapms"]
        },
    ]
}

/**
 * The record as the sections the file holds, in file order: the three known
 * sections, then the unknown keys and sections the user added, carried on raw.
 * @param {Settings} s - settings record
 * @returns {Array<IniSection>} {name, pairs} sections, in file order
 */
SettingsSections(s) {
    sections := [
        {
            name: "meta",
            pairs: [
                {
                    name: "version",
                    value: "2"
                },
                {
                    name: "game",
                    value: s.game
                }
            ]
        },
        {
            name: "camera",
            pairs: CameraPairs(s.camera)
        },
        {
            name: "bindings",
            pairs: []
        },
    ]
    for p in s.raw["meta"]
        sections[1].pairs.Push(p)
    for p in s.raw["camera"]
        sections[2].pairs.Push(p)
    n := 0
    for b in s.bindings {
        n += 1
        sections[3].pairs.Push({
            name: String(n),
            value: FormatBinding(b)
        })
    }
    for p in s.raw["bindings"]
        sections[3].pairs.Push(p)
    ; Unknown sections are carried on the record, never re-read from disk: a save
    ; must write what was loaded, not whatever landed in the file meanwhile.
    for section in s.raw["sections"]
        sections.Push(section)
    return sections
}

/**
 * Read the file into a settings record. `quiet` suppresses the migration notice,
 * for the self-check.
 * @param {String} path - ini file to read (default: ConfigPath())
 * @param {Boolean} quiet - true to skip the v1 migration MsgBox
 * @returns {Settings} the settings record; defaults when the file is missing
 */
LoadSettings(path := ConfigPath(), quiet := false) {
    s := DefaultSettings()
    if !FileExist(path)
        return s
    if !HasSections(path) {          ; no [sections]: a flat v1 file
        moved := true
        try FileMove(path, path . ".v1.bak", 1)
        catch
            moved := false
        if !quiet
            MsgBox(moved ? "The old config.ini was moved to config.ini.v1.bak; the defaults are in use." :
                "config.ini has no sections and could not be moved; the defaults are in use.", "Game Input Assistance")
        return s
    }

    raw := Map("meta", [], "camera", [], "bindings", [], "sections", [])
    for section in ReadSections(path) {
        name := StrLower(section.name)
        if (name = "meta") {
            for p in section.pairs
                if (StrLower(p.name) = "game" && p.value != "")
                    s.game := p.value
                else if (StrLower(p.name) != "version")       ; the version is ours to write
                    raw["meta"].Push(p)
        } else if (name = "camera") {
            for p in section.pairs
                if IsCameraField(p.name)
                    SetCamera(s.camera, StrLower(p.name), p.value)
                else
                    raw["camera"].Push(p)
        } else if (name = "bindings") {
            ; Numbered keys are bindings; the numbers give the window its row order.
            byIndex := Map()
            for p in section.pairs
                if (p.name ~= "^\d+$")
                    byIndex[Integer(p.name)] := ParseBinding(p.value)
                else
                    raw["bindings"].Push(p)
            if byIndex.Count {
                last := 0
                for i, b in byIndex
                    last := Max(last, i)
                s.bindings := []
                loop last
                    if byIndex.Has(A_Index)
                        s.bindings.Push(byIndex[A_Index])
            }
        } else
            raw["sections"].Push(section)
    }
    s.raw := raw
    return s
}

/**
 * Write the file from the record. Everything it contains comes from the record,
 * so no read happens here.
 * @param {Settings} s - settings record to write
 * @param {String} path - ini file to write (default: ConfigPath())
 * @returns {String} ""
 */
SaveSettings(s, path := ConfigPath()) {
    WriteSections(SettingsSections(s), path, "; game-assistant settings")
}
