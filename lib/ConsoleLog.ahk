#Requires AutoHotkey v2.0
#Include ArrayToString.ahk

; Logging function; Public
LoggerWrite(context, level, message) {
    ConsoleLogger.Instance.Write(context, level, message)
}

; internal helper: bind a context and level to produce a logging function
class ConsoleLogger {
    static Instance := ConsoleLogger()

    __New() {
        ; this.Gui := 0
        ; this.Box := 0
        this._AlwaysOnTop := false

        this.Gui := Gui(this._AlwaysOnTop ? "+AlwaysOnTop" : "", "Debug Log")
        this.Box := this.Gui.AddEdit("w500 h300 ReadOnly -Wrap")
    }

    AlwaysOnTop {
        get => this._AlwaysOnTop
        set {
            this._AlwaysOnTop := value
            this.Gui.Opt(this._AlwaysOnTop ? "+AlwaysOnTop" : "-AlwaysOnTop")
        }
    }

    Write(context, level, message) {
        if (message is Array)
            message := ArrayToString(message)

        this.Gui.Show("x+0 y+0 NoActivate")

        timestamp := FormatTime(, "HH:mm:ss")
        levelText := level ? "[" . level . "]" : ""
        contextText := context ? "[" . context . "]" : ""
        this.Box.Value .= "[" timestamp "]" contextText levelText " " message "`r`n"

        SendMessage(0x115, 7, 0, this.Box.Hwnd)
    }

}