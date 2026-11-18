#Requires AutoHotkey v2.0

ToastMouse(msg, durationMs := 1000) {
    static mt := MouseToast(true)
    mt.Send(msg, durationMs)
}

class MouseToast {

    __New(singleToast := false, refreshRate := 30) {
        if (refreshRate <= 0)
            throw ValueError("refreshRate must be greater than zero")

        this._singleToast := singleToast
        this._toasts := []
        this._isTracking := false

        this.refreshRate := refreshRate
    }

    Send(msg, durationMs := 1000) {
        if (durationMs <= 0)
            throw ValueError("durationMs must be greater than zero")

        if (this._singleToast) {
            this._toasts := []
        }

        toast := {
            text: msg, ; use object instead of text to maintain identity
        }
        this._AddToast(toast)

        this.UpdateText()

        _ExpireThis(*) {
            if (this._RemoveToast(toast))
                this.UpdateText()
        }
        SetTimer(_ExpireThis, -durationMs)

        this._StartTracking()
    }

    UpdateText() {
        text := this._GetText()
        if (text = "") {
            ToolTip() ; this is how you clear
        } else {
            ToolTip(text)
        }

    }

    _GetText(*) {
        str := ""
        for toast in this._toasts
            str .= toast.text . "`n"

        return Trim(str, "`n") ; Remove trailing/prepending newlines
    }

    _RefreshIntervalMs => Round(1000 / this.refreshRate)

    _TrackMouseCallback(*) {
        if (this._toasts.Length != 0) {
            ToolTip(this._GetText()) ; simplest way to update position
        } else {
            this._StopTracking()
        }
    }

    _StartTracking(*) {
        if (this._isTracking) {
            return
        }
        this._isTracking := true
        this._trackCallback := this._TrackMouseCallback.Bind(this)
        this._trackCallback()
        SetTimer(this._trackCallback, this._RefreshIntervalMs)
    }

    _StopTracking(*) {
        this._isTracking := false
        SetTimer(this._trackCallback, 0)
    }

    _AddToast(toast) {
        this._toasts.Push(toast)
    }

    _RemoveToast(toast) {
        for idx, item in this._toasts {
            if (item == toast) {
                this._toasts.RemoveAt(idx)
                return true
            }
        }

        return false
    }
}