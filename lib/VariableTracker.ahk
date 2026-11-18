#Requires AutoHotkey v2.0
#Include ArrayToString.ahk

; ---------------------------------------------------------------------------
; Variable tracking
;
; Public API:
;   TrackVariable(&myVar)                 ; display name defaults to "Var#N"
;   TrackVariable(&myVar, "myVar")        ; explicit display name
;
; A small always-on-top window lists every tracked variable and its current
; value, refreshed by a timer while the window is open. Closing the window
; stops the timer; tracking again re-shows it and restarts the timer.
; ---------------------------------------------------------------------------
TrackVariable(varRef, altVarName := "") {
    Tracker.Add(varRef, altVarName)
}

class Tracker {
    static Items := []       ; [{name, ref}]
    static Gui := 0
    static Box := 0
    static TimerFn := 0
    static TimerOn := false
    static Counter := 0

    static Add(varRef, altName) {
        if (Type(varRef) != "VarRef")
            throw TypeError("TrackVariable expects a variable reference - call TrackVariable(&var)")

        if (altName != "")
            name := altName
        else {
            Tracker.Counter += 1
            name := Format("Var#{}", Tracker.Counter)
        }
        Tracker.Items.Push({
            name: name,
            ref: varRef
        })

        Tracker.EnsureGui()
        Tracker.Gui.Show("NoActivate")
        Tracker.Refresh()

        if not Tracker.TimerOn {
            ; Store the exact function object so the timer can be stopped reliably.
            Tracker.TimerFn := Tracker.Refresh
            SetTimer(Tracker.TimerFn, 250)
            Tracker.TimerOn := true
        }
    }

    static EnsureGui() {
        if Tracker.Gui
            return
        Tracker.Gui := Gui("+AlwaysOnTop", "Tracked Variables")
        Tracker.Box := Tracker.Gui.AddEdit("w400 h200 ReadOnly -Wrap")
        Tracker.Gui.OnEvent("Close", Tracker.OnClose)
    }

    static OnClose(*) {
        Tracker.Gui.Hide()
        if Tracker.TimerOn {
            SetTimer(Tracker.TimerFn, 0)
            Tracker.TimerOn := false
        }
    }

    static Refresh() {
        if not Tracker.Gui
            return

        text := ""
        for item in Tracker.Items {
            ref := item.ref
            try
                value := %ref%
            catch
                value := "<unset>"
            text .= Format("{} = {}`r`n", item.name, Tracker.FormatValue(value))
        }
        text := RTrim(text, "`r`n")

        ; Only write when something actually changed: avoids flicker/scroll jumps.
        if (Tracker.Box.Value != text)
            Tracker.Box.Value := text
    }

    static FormatValue(value) {
        if (value is Array)
            return ArrayToString(value)
        if IsObject(value)
            return Type(value)
        return String(value)
    }
}

