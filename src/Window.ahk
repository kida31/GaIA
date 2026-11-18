; Settings window. Included by game-assistant.ahk with #Include "*i", so this
; file is optional: delete it and the tool runs headless on config.ini.
;
; The window owns no rules. It turns the loaded records into controls, reads
; them back into fresh records, and hands them to SaveSettings(). Validation
; it does show is the same range/duplicate check the logic file applies at load.

#Include Settings.ahk
#Include ../lib/ConsoleLog.ahk

ConsoleLog := LoggerWrite.Bind("Window", "Info")

Ui := {
    gui: 0, rows: [], extra: [], camKeys: {}, camNums: Map(),
    capture: Map(), initial: "", status: 0, save: 0,
    actions: [ActionType.REPEAT, ActionType.REPEAT_CLICK_DEPRECATED, ActionType.HOLD],
    labels: ["repeat", "repeat left click (deprecated)", "hold & release"]
}

/**
 * Build and show the settings window from the loaded record.
 * @returns {String} ""
 */
ShowSettings() {
    global Settings, Ui

    w := Gui("", "Game Input Assistance — settings")
    Ui.gui := w

    w.AddText("x12 y10 w110", "trigger")
    w.AddText("x130 y10 w150", "action")
    w.AddText("x290 y10 w110", "target")

    for b in Settings.bindings {
        if (Ui.rows.Length >= 8) {            ; the file has more than the window shows
            Ui.extra.Push(b)
            continue
        }
        y := 30 + Ui.rows.Length * 56
        r := { keys: SplitKeys(b.trigger), group: b.group }

        r.trigger := w.AddEdit("x12 y" . y . " w110 +ReadOnly", JoinKeys(r.keys))
        r.action := w.AddDropDownList("x130 y" . y . " w150", Ui.labels)
        for n, a in Ui.actions
            if (a = b.action)
                r.action.Choose(n)
        r.target := w.AddEdit("x290 y" . y . " w110 +ReadOnly", b.target)
        w.AddText("x406 y" . (y + 4) . " w80", "= trigger")
        r.timing := w.AddEdit("x12 y" . (y + 26) . " w50 +Number", b.timing)
        w.AddUpDown("x62 y" . (y + 26) . " w16 Range20-2000", b.timing)
        w.AddText("x84 y" . (y + 30) . " w20", "ms")
        r.sticky := w.AddCheckBox("x110 y" . (y + 26) . " w150", "sticky after release")
        r.sticky.Value := (b.linger > 0)
        r.linger := w.AddEdit("x270 y" . (y + 26) . " w50 +Number", b.linger)
        w.AddUpDown("x320 y" . (y + 26) . " w16 Range0-5000", b.linger)
        w.AddText("x342 y" . (y + 30) . " w20", "ms")

        Ui.rows.Push(r)
        AddKey(r.trigger, { kind: "trigger", index: Ui.rows.Length })
        AddKey(r.target, { kind: "target", index: Ui.rows.Length })
        r.action.OnEvent("Change", Refresh)
        r.sticky.OnEvent("Click", Refresh)
        r.timing.OnEvent("Change", Refresh)
        r.linger.OnEvent("Change", Refresh)
    }

    y := 30 + Ui.rows.Length * 56 + 10
    w.AddText("x12 y" . y . " w200", "Camera — hold to pan, tap to nudge")
    y += 24
    n := 0
    for f in ["up", "down", "left", "right"] {
        x := Mod(n, 2) = 0 ? 12 : 300
        yy := y + (n // 2) * 26
        w.AddText("x" . x . " y" . (yy + 4) . " w40", f)
        ctl := w.AddEdit("x" . (x + 45) . " y" . yy . " w100 +ReadOnly", Settings.camera.%f%)
        Ui.camKeys.%f% := ctl
        AddKey(ctl, { kind: "camera", key: f })
        n += 1
    }

    y += 60
    Ui.camNums["tapstep"] := AddNum(w, 12, y, "tap step", Settings.camera.tapstep, "5-5000", "px")
    Ui.camNums["panstep"] := AddNum(w, 300, y, "pan step", Settings.camera.panstep, "5-5000", "px")
    y += 26
    Ui.camNums["pantick"] := AddNum(w, 12, y, "pan tick", Settings.camera.pantick, "1-200", "ms")
    Ui.camNums["tapms"] := AddNum(w, 300, y, "tap under", Settings.camera.tapms, "20-1000", "ms")

    y += 30
    w.AddText("x12 y" . y . " w560", "Steps are multiples of 5; a tap is sent as 5 moves.")

    y += 26
    Ui.status := w.AddText("x12 y" . (y + 4) . " w360", "")
    cancel := w.AddButton("x380 y" . y . " w80", "Cancel")
    Ui.save := w.AddButton("x470 y" . y . " w110", "Save and restart")

    Ui.checkboxExitOnClose := w.AddCheckbox("y+16 Checked", "Closing window exits script")

    w.OnEvent("Close", CloseWindow)
    w.OnEvent("Escape", CloseWindow)
    cancel.OnEvent("Click", CloseWindow)
    Ui.save.OnEvent("Click", SaveClick)

    OnMessage(0x100, KeyDown)          ; WM_KEYDOWN, for capturing keys
    Ui.initial := Sig(Settings)
    Refresh()
    w.Show()
}

/**
 * Add a labelled number row (edit + spinner + unit) and return the edit control.
 * @param {Gui} g - window to add to
 * @param {Integer} x - left position
 * @param {Integer} y - top position
 * @param {String} label - text label
 * @param {Integer} value - initial value
 * @param {String} range - AddUpDown range, e.g. "5-5000"
 * @param {String} unit - unit text after the spinner
 * @returns {Gui.Control} the edit control
 */
AddNum(g, x, y, label, value, range, unit) {
    g.AddText("x" . x . " y" . (y + 4) . " w70", label)
    ctl := g.AddEdit("x" . (x + 72) . " y" . y . " w60 +Number", value)
    g.AddUpDown("x" . (x + 132) . " y" . y . " w16 Range" . range, value)
    g.AddText("x" . (x + 152) . " y" . (y + 4) . " w30", unit)
    return ctl
}

/**
 * A key cell takes the next key pressed. Shift toggles a key in a group row.
 * @param {Gui.Control} ctrl - edit control to fill
 * @param {Object} ctx - capture context, {kind, index} or {kind, key}
 * @returns {String} ""
 */
AddKey(ctrl, ctx) {
    global Ui
    Ui.capture[ctrl.Hwnd] := ctx
}

/**
 * WM_KEYDOWN handler: turns the next key press into the focused cell's value.
 * @param {Integer} wParam - virtual key code
 * @param {Integer} lParam - key flags (bit 30 = auto-repeat)
 * @param {Integer} msg - message number
 * @param {Integer} hwnd - target window handle
 * @returns {Integer} 1 to swallow the key, otherwise ""
 */
KeyDown(wParam, lParam, msg, hwnd) {
    global Ui
    if !WinActive("ahk_id " . Ui.gui.Hwnd)
        return
    ctl := Ui.gui.FocusedCtrl
    if !IsObject(ctl)
        return
    ctx := Ui.capture[ctl.Hwnd]
    if !IsObject(ctx)
        return
    if (lParam & 0x40000000)          ; auto-repeat while the key is held
        return 1
    key := GetKeyName("vk" . Format("{:X}", wParam))
    if (key = "" || key = "Escape" || key = "Tab" || key = "Enter")
        return
    if (key ~= "^(L|R)?(Shift|Ctrl|Control|Alt|Win)$")
        return 1                      ; modifiers drive Shift+key, not capture
    if (ctx.kind = "trigger") {
        r := Ui.rows[ctx.index]
        r.keys := GetKeyState("Shift", "P") ? ToggleKey(r.keys, key) : [key]
        r.trigger.Text := JoinKeys(r.keys)
    } else if (ctx.kind = "target") {
        Ui.rows[ctx.index].target.Text := (key = "Backspace" || key = "Delete") ? "" : key
    } else
        Ui.camKeys[ctx.key].Text := key
    Refresh()
    return 1                          ; the game never sees this key
}

/**
 * Add key to the list, or remove it when already there; never leaves it empty.
 * @param {Array<String>} keys - current keys
 * @param {String} key - key to toggle
 * @returns {Array<String>} the new list
 */
ToggleKey(keys, key) {
    out := []
    found := false
    for k in keys {
        if (k = key)
            found := true
        else
            out.Push(k)
    }
    if !found
        out.Push(key)
    return out.Length ? out : [key]
}

/**
 * "a,b,c" -> ["a", "b", "c"]; blanks dropped.
 * @param {String} text - comma-separated trigger text
 * @returns {Array<String>} trimmed keys
 */
SplitKeys(text) {
    out := []
    for part in StrSplit(text, ",")
        if (Trim(part) != "")
            out.Push(Trim(part))
    return out
}

/**
 * ["a", "b"] -> "a,b".
 * @param {Array<String>} keys - keys to join
 * @returns {String} comma-separated text
 */
JoinKeys(keys) {
    out := ""
    for k in keys
        out .= (out = "" ? "" : ",") . k
    return out
}

/**
 * Read a number edit, falling back when it is empty.
 * @param {Gui.Control} ctl - number edit
 * @param {Integer} fallback - used when the control is blank
 * @returns {Integer} the value
 */
Num(ctl, fallback) {
    return ctl.Text = "" ? fallback : Integer(ctl.Text)
}

/**
 * Build a fresh settings record from the controls; the rules stay in the logic
 * file.
 * @returns {Object} {bindings, camera, game, raw}
 */
Collect() {
    global Ui, Settings
    s := { bindings: [], camera: Map(), game: Settings.game, raw: Settings.raw }
    for row, r in Ui.rows {
        s.bindings.Push({
            trigger: JoinKeys(r.keys),
            action: Ui.actions[r.action.Value],
            target: r.action.Value = 1 ? r.target.Text : "",
            timing: Num(r.timing, 70),
            linger: r.sticky.Value ? Num(r.linger, 0) : 0,
            group: r.keys.Length > 1 ? (r.group = "" ? "group" . row : r.group) : ""
        })
    }
    for b in Ui.extra
        s.bindings.Push(b)
    s.camera.up := Ui.camKeys.up.Text
    s.camera.down := Ui.camKeys.down.Text
    s.camera.left := Ui.camKeys.left.Text
    s.camera.right := Ui.camKeys.right.Text
    s.camera.tapstep := Num(Ui.camNums["tapstep"], 500)
    s.camera.panstep := Num(Ui.camNums["panstep"], 60)
    s.camera.pantick := Num(Ui.camNums["pantick"], 40)
    s.camera.tapms := Num(Ui.camNums["tapms"], 200)
    return s
}

/**
 * Canonical text of the records, for the Save button's dirty check. Not the
 * file's format: adding a field to BindingFields is enough here.
 * @param {Object} s - settings record
 * @returns {String} comparable text
 */
Sig(s) {
    out := ""
    BF := BindingFields() ; ["trigger", "action", "target", "timing", "linger", "group"]
    CF := CameraFields()
    for b in s.bindings {
        for idx, keyName in BF {
            out := out . b.%keyName% . "`n"
        }
    }
    for keyName in CF {
        out := out . s.camera.%keyName% . "`n"
    }
    return out
}

/**
 * Re-apply the enabled states and the Save button's dirty check.
 * @param {...Any} _ - event callback arguments, ignored
 * @returns {String} ""
 */
Refresh(*) {
    global Ui
    for r in Ui.rows {
        r.linger.Enabled := r.sticky.Value
        r.target.Enabled := (r.action.Value = 1)
    }
    Ui.status.Text := ""
    Ui.save.Enabled := (Sig(Collect()) != Ui.initial)
}

/**
 * Validate what the controls hold, then save and restart; on refusal, say why
 * in the status line.
 * @param {...Any} _ - event callback arguments, ignored
 * @returns {String} ""
 */
SaveClick(*) {
    global Ui
    s := Collect()
    if (Mod(s.camera.tapstep, 5) || Mod(s.camera.panstep, 5)) {
        Ui.status.Text := "Tap and pan steps must be multiples of 5."
        ctl := Mod(s.camera.tapstep, 5) ? Ui.camNums["tapstep"] : Ui.camNums["panstep"]
        ctl.Focus()
        return
    }
    problem := ConfigProblem(s)
    if (problem != "") {
        Ui.status.Text := problem . "."
        return
    }
    SaveSettings(s)
    Reload()                          ; the tool restarts on the new settings
}

/**
 * Close the window without saving.
 * @param {...Any} _ - event callback arguments, ignored
 * @returns {String} ""
 */
CloseWindow(*) {
    global Ui
    if (Ui.checkboxExitOnClose.Value)
        ExitApp(0)
    Ui.gui.Destroy()
}
