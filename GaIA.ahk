; Game Input Assistance — AutoHotkey v2 input assistant for Genshin Impact.
; Hold-to-repeat keys, repeat clicks, charged attacks, camera pan and nudge.
;
; Settings come from config.ini next to this file. Without it the built-in
; defaults in settings.ahk are used, so the tool runs with no file at all.
; The optional window.ahk adds the settings window; delete it to go headless.
#Requires AutoHotkey v2.0
#SingleInstance Force
#MaxThreads 30                      ; room for every held binding at once
#MaxThreadsPerHotkey 1              ; a held key owns its hotkey until it ends

SetTitleMatchMode "RegEx"
A_HotkeyInterval := 0
Thread "Interrupt", 0

#Include src/Config.ahk             ; the file layer: ReadSections / WriteSections
#Include src/Settings.ahk           ; the record, its rules, LoadSettings / SaveSettings
#Include src/Camera.ahk             ; reads Settings.camera
#Include src/Window.ahk             ; optional GUI
#Include src/PostInput.ahk

#Include lib/ConsoleLog.ahk         ; Logging


ConsoleLog := (*) => {}             ; Replace with LoggerWrite.Bind("Main", "Info")

; ===== state =====
Owner := Map()                      ; group name -> id of the binding that owns it
HeldKeys := []                      ; list of keys currently held down, to release on exit

if A_Args.Length {
    MsgBox("Unknown argument: " . A_Args[1], "Game Input Assistance", "Icon!")
    ExitApp(2)
}
if not A_IsAdmin {
    try Run '*RunAs "' A_ScriptFullPath '"'
    ExitApp
}

Settings := LoadSettings()
Game := Settings.game

Camera := Settings.camera            ; camera.ahk reads this global

; Extra tracking for keys not handled by GetKeyState, so we can detect when the user releases a key that is being held by the tool.
globalUserHoldsButton := Map()  ; key -> true/false, so we can detect when the key is released
~LButton:: globalUserHoldsButton["LButton"] := true
~LButton Up:: globalUserHoldsButton["LButton"] := false
~RButton:: globalUserHoldsButton["RButton"] := true
~RButton Up:: globalUserHoldsButton["RButton"] := false
_GetKeyState(key, mode := "P") {
    if (mode = "P" && globalUserHoldsButton.Has(key))
        return globalUserHoldsButton[key]
    return GetKeyState(key, mode)
}
; End Extra tracking

Wire(Settings)
OnExit(OnExitHandler)
ShowSettings()
return

; ===== wiring =====

/**
 * Show the message and stop the tool; every fatal path ends here.
 * @param {String} message - what went wrong, shown to the user
 * @returns {String} does not return; exits with code 1
 */
Exit1Message(message) {
    MsgBox(message, "Game Input Assistance", "Icon!")
    ExitApp(1)
}

/**
 * Register one hotkey, failing the app on a key name AutoHotkey does not know.
 * @param {String} key - key name as the config wrote it
 * @param {Func} fn - callback to bind
 * @returns {String} ""
 */
BindHotkey(key, fn) {
    try Hotkey("~*" . key, fn)
    catch
        Exit1Message("Key '" . key . "' is not a key name AutoHotkey knows. Fix the config file.")
}

/**
 * Validate the record and register everything that drives the tool: the camera
 * keys, one hotkey per trigger, and End to quit.
 * @param {Object} s - settings record
 * @returns {String} ""
 */
Wire(s) {
    global Game, Owner
    problem := ConfigProblem(s)
    if (problem != "")
        Exit1Message("Config: " . problem . ".")
    Owner := Map()
    HotIfWinActive(Game)
    BindCamera(s.camera)
    for b in s.bindings {
        BindHotkey(b.trigger, OnHotkeyPressed.Bind(b, b.trigger))
    }
    Hotkey("End", (*) => ExitApp())   ; only inside the game, End stays normal
    HotIf()
}

OnExitHandler(*) {
    for key in HeldKeys {
        ; Release, but only if the user is not holding it down themselves.
        if (_GetKeyState(key, "P") = false)
            _Send_("{" . key . " Up}")
    }
}

; ===== engine =====

/**
 * One loop per held trigger, closed over its binding record.
 * @param {Object} b - binding record
 * @param {String} key - the trigger key that fired
 * @param {...Any} _ - extra hotkey callback arguments, ignored
 * @returns {String} ""
 */
OnHotkeyPressed(b, key, *) {
    global Owner
    static seq := 0

    if !WinActive(Game)
        return
    id := ++seq
    if (b.group != "")
        Owner[b.group] := id

    if (b.action = ActionType.HOLD) {
        HandleHold(b, key, id)
        return
    }

    ConsoleLog("Pressed " . key . " for action " . b.action)

    releasedAtMs := A_TickCount + b.linger

    while WinActive(Game) && (b.group = "" || Owner[b.group] = id) {
        ; Handle logic for cancelling
        if _GetKeyState(key, "P") {
            releasedAtMs := A_TickCount + b.linger
        } else {
            if (A_TickCount > releasedAtMs) {
                if (b.linger > 0) {
                    ConsoleLog("Released " . key . " after linger " . (b.linger + A_TickCount - releasedAtMs) . "ms (" .
                    b.linger .
                    ")")
                } else {
                    ConsoleLog("Released " . key)
                }
                break
            }
        }

        if (b.action = ActionType.REPEAT_CLICK_DEPRECATED)
        ; repeat-click
            Click() ;Deprecated; Use REPEAT for LButton instead
        else
        ; repeat-key
            _Send_("{" . (b.target = "" ? key : b.target) . "}")
        Sleep(b.timing)
    }
}

/**
 * One long hold: lasts for linger duration.
 * @param {Object} b - binding record
 * @param {String} key - the trigger key that fired
 * @param {Integer} id - sequence id, so a newer press of the group wins; TODO
 * @returns {String} ""
 */
HandleHold(b, key, id) {
    if !WinActive(Game)
        return
    _Send_("{" b.target " Down}")
    ConsoleLog("Pressed " . key . " for action hold")
    if (HeldKeys.Has(b.target) = false)
        HeldKeys.Push(b.target)  ; remember to release on exit

    start := A_TickCount
    while (WinActive(Game) && (b.group = "" || Owner[b.group] = id) && ((A_TickCount - start) < b.linger)) {
        Sleep(10)
    }
    ConsoleLog("Hold " . key . " finished after " . (A_TickCount - start) . "ms")
    if (_GetKeyState(b.target, "P") = false && _GetKeyState(b.trigger, "P") = false) {
        _Send_("{" b.target " Up}")
        ConsoleLog("Released " . key . " after hold " . (A_TickCount - start) . "ms")
    } else {
    }
}

; ==== Overwrites ====

_Send_(key) {
    static recentContext := ""
    currentContext := WinGetTitle("A")
    if (currentContext != recentContext) {
        ToastMouse(currentContext)
        recentContext := currentContext
    }

    if (InStr(currentContext, "NTE")) {
        ;; NTE needs different input type
        PostInput.Post(key)
    } else {
        Send(key)
    }
}
