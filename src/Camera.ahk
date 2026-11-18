; Camera: hold a direction key to pan, tap it to nudge once. Tap vs hold is
; decided on release from how long the key was down. While any camera key is
; held a timer keeps panning; it stops itself when none are down, or when the
; game is no longer the active window (the key-up hotkey is skipped then).
;
; Included by game-assistant.ahk and reads its Camera record and Game, so it is
; not runnable on its own.

CameraHeld := Map()                   ; camera keys down: key -> {t, sx, sy}

/**
 * Register the eight camera hotkeys (four press, four release).
 * Call inside HotIfWinActive Game.
 * @param {Camera} c - camera map from the settings record
 * @returns {String} ""
 */
BindCamera(c) {
    BindHotkey(c.up, CamDown.Bind(c.up, 0, -1))
    BindHotkey(c.down, CamDown.Bind(c.down, 0, 1))
    BindHotkey(c.left, CamDown.Bind(c.left, -1, 0))
    BindHotkey(c.right, CamDown.Bind(c.right, 1, 0))
    BindHotkey(c.up . " Up", CamUp.Bind(c.up))
    BindHotkey(c.down . " Up", CamUp.Bind(c.down))
    BindHotkey(c.left . " Up", CamUp.Bind(c.left))
    BindHotkey(c.right . " Up", CamUp.Bind(c.right))
}

/**
 * A direction key went down: remember the press and keep the pan timer running.
 * @param {String} key - camera key
 * @param {Integer} sx - x direction, -1, 0 or 1
 * @param {Integer} sy - y direction, -1, 0 or 1
 * @param {...Any} _ - extra hotkey callback arguments, ignored
 * @returns {String} ""
 */
CamDown(key, sx, sy, *) {
    global CameraHeld, Camera
    if CameraHeld.Has(key)            ; key auto-repeat, not a new press
        return
    CameraHeld[key] := {
        t: A_TickCount,
        sx: sx,
        sy: sy
    }
    SetTimer(CamTick, Camera.pantick)
}

/**
 * A direction key was released: a short press is a tap nudge, else it just stops.
 * @param {String} key - camera key
 * @param {...Any} _ - extra hotkey callback arguments, ignored
 * @returns {String} ""
 */
CamUp(key, *) {
    global CameraHeld, Camera
    if !CameraHeld.Has(key)
        return
    p := CameraHeld[key]
    CameraHeld.Delete(key)
    if (A_TickCount - p.t < Camera.tapms)          ; released quickly = tap
        CamStep(p.sx * Camera.tapstep, p.sy * Camera.tapstep, 8)
    if !CameraHeld.Count
        SetTimer(CamTick, 0)
}

/**
 * Timer body: pan while keys are held, stop when none are or focus is lost.
 * @returns {String} ""
 */
CamTick() {
    global CameraHeld, Camera, Game
    if !WinActive(Game) {             ; focus lost: stop instead of panning other windows
        CameraHeld.Clear()
        SetTimer(CamTick, 0)
        return
    }
    dx := 0
    dy := 0
    for key, p in CameraHeld.Clone() {
        if !GetKeyState(key, "P")             ; up hotkey missed: forget it
            CameraHeld.Delete(key)
        else if (A_TickCount - p.t >= Camera.tapms) {
            dx += p.sx * Camera.panstep
            dy += p.sy * Camera.panstep
        }
    }
    if (dx || dy)
        CamStep(dx, dy)
    if !CameraHeld.Count
        SetTimer(CamTick, 0)
}

/**
 * Move the mouse by dx,dy pixels, in 5 sub-moves for a tap so the game does not
 * clamp one large delta.
 * @param {Integer} dx - horizontal pixels
 * @param {Integer} dy - vertical pixels
 * @param {Integer} subMs - ms between sub-moves; 0 = one move (default)
 * @returns {String} ""
 */
CamStep(dx, dy, subMs := 0) {
    if (true) {
        ; Small steps so the game does not clamp a single large delta; only the
        ; tap spaces them out, since the hold's deltas are already small.
        loop 5 {
            DllCall("mouse_event", "UInt", 1, "Int", Round(dx / 5), "Int", Round(dy / 5), "UInt", 0, "UPtr", 0)
            if (subMs and A_Index < 5)
                Sleep subMs
        }
    } else {
        ; Does not seem to work

        ; Pan is one move per tick; only the tap nudge is split so the game does
        ; not clamp a single large delta.
        steps := subMs ? 5 : 1
        loop steps {
            MouseMove(Round(dx / steps), Round(dy / steps), 0, "R")
            if (subMs && A_Index < steps)
                Sleep(subMs)
        }
    }
}