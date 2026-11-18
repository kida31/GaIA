#Requires AutoHotkey v2.0
#Include ../lib/Toast.ahk

/** Alternative calling method to Send input to application if they do not react to common Send */
class PostInput {
    static GetKeySC(vk) { ; Deprecated
        static scanCodes := Map()
        if !scanCodes.Has(vk) {
            scanCodes[vk] := DllCall("MapVirtualKey", "UInt", vk, "UInt", 0, "UInt")
        }
        return scanCodes[vk]
    }

    static Post(literalKey, hwnd := "", durationMs := 50) {
        literalKey := _removeBraces(literalKey) ; "{key}" -> "key"
        keyName := _stripUpDown(literalKey)     ; "key down" -> "key"

        if (_endsWith(StrLower(literalKey), "down")) {
            ; Send("key down") ; TODO: Fix "down". Should be individual key
            return this.PostDown(keyName)
        } else if (_endsWith(StrLower(literalKey), "up")) {
            ; Send("key up")
            return this.PostUp(keyName, hwnd)
        } else {
            ; Send("key")
            b := this.PostDown(keyName, hwnd)
            SetTimer(this.PostUp.Bind(this, keyName, hwnd), -durationMs)
            return b
        }
    }

    static PostDown(keyName, hwnd := "") {        
        if !hwnd
            hwnd := WinExist()
        if !hwnd
            hwnd := WinExist("A")
        
        if !hwnd {
            ToastMouse("Failed:" . keyName)
            return false
        }
        
        vk := GetKeyVK(keyName)
        sc := GetKeySC(keyName)
        lParamDown := (sc << 16) | 1
        PostMessage(0x0100, vk, lParamDown, , hwnd) ; WM_KEYDOWN
        return true
    }

    static PostRelease(keyName, hwnd := "") {
        return this.PostUp(keyName, hwnd)
    }

    static PostUp(keyName, hwnd := "") {
        if !hwnd
            hwnd := WinExist()
        if !hwnd
            hwnd := WinExist("A")
        
        if !hwnd {
            ToastMouse("Failed:" . keyName)
            return false
        }
        
        vk := GetKeyVK(keyName)
        sc := GetKeySC(keyName)
        ; LParamUp: Bits 30 & 31 set to 1, ScanCode in bits 16-23, Repeat count 1
        lParamUp := (sc << 16) | 1 | 0xC0000000
        PostMessage(0x0101, vk, lParamUp, , hwnd)   ; WM_KEYUP
        return true
    }
}

_endsWith(str, suffix) {
    return (SubStr(str, -StrLen(suffix)) == suffix)
}

_removeBraces(str) {
    return Trim(StrReplace(StrReplace(str, "{"), "}"))
}

_stripUpDown(str) {
    return Trim(StrReplace(StrReplace(str, "down"), "up"))
}