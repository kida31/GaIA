; Game Input Assistance — the self-check. Run this file directly (double-click, or
; `AutoHotkey.exe game-assistant.test.ahk`): it prints one line per check and
; exits 0 when everything passed, 1 otherwise.
;
; It includes only the record and the file layer, so it never reads your real
; config.ini, registers a hotkey or opens a window.
#Requires AutoHotkey v2.0
#Include src/Settings.ahk
#Include src/Config.ahk

TestFails := 0

/**
 * Print one check line and count the failure.
 * @param {Boolean} cond - the check
 * @param {String} what - description printed after ok/FAIL
 * @returns {String} ""
 */
Assert(cond, what) {
    global TestFails
    if cond
        FileAppend("ok   " . what . "`n", "*")
    else {
        TestFails += 1
        FileAppend("FAIL " . what . "`n", "*")
    }
}

dir := A_Temp . "\game-assistant-selftest"
DirCreate(dir)
cfg := dir . "\config.ini"
for f in [cfg, cfg . ".tmp", cfg . ".v1.bak"]
    if FileExist(f)
        FileDelete(f)

d := DefaultSettings()
Assert(d.bindings.Length = 4, "defaults: 4 bindings")
Assert(d.camera.right = ";", "defaults: ';' is a camera key")
Assert(d.camera.panstep = 60, "defaults: pan step")
Assert(ConfigProblem(d) = "", "defaults: no key used twice")

WriteLines(cfg, [
    "; game-assistant settings",
    "",
    "[meta]",
    "version = 2",
    "game = ahk_exe (GenshinImpact|YuanShen|HTGame)\.exe$",
    "",
    "[camera]",
    "; hold a key to pan, tap it to nudge",
    "up = o",
    "down = l",
    "left = k",
    'right = ";"',
    "tapstep = 500",
    "panstep = 60",
    "pantick = 40",
    "tapms = 200",
    "",
    "[bindings]",
    "1 = Space     | repeat-key   | Space | 70  | 0 | -",
    "2 = 1,2,3,4,5 | repeat-key   |       | 100 | 0 | switch",
    "3 = i         | repeat-click | -     | 150 | 0 | -",
    "4 = p         | hold-click   | -     | 350 | 0 | -",
])
s := LoadSettings(cfg, true)
Assert(s.bindings.Length = 4, "parse: 4 bindings")
Assert(s.bindings[2].group = "switch", "parse: group name")
Assert(s.bindings[2].target = "", "parse: blank target")
Assert(s.bindings[3].target = "", "parse: '-' target is blank")
Assert(s.camera.right = ";", "parse: a quoted ';' is still a key")
Assert(s.camera.tapstep = 500, "parse: tap step")
Assert(s.camera.panstep = 60, "parse: pan step")
Assert(InStr(s.game, "GenshinImpact"), "parse: game line")

WriteLines(cfg, [
    "[bindings]",
    "1 = q | repeat-key | q | 1 | -5 | -",
    "",
    "[camera]",
    "panstep = 7",
    "pantick = 999",
    "tapms = 0",
    "tapstep = 9999",
])
cl := LoadSettings(cfg, true)
Assert(cl.bindings.Length = 1, "load: the file's bindings replace the defaults")
Assert(cl.bindings[1].timing = 20, "clamp: timing min")
Assert(cl.bindings[1].linger = 0, "clamp: linger min")
Assert(cl.camera.panstep = 5, "clamp: steps are multiples of 5")
Assert(cl.camera.pantick = 200, "clamp: pan tick max")
Assert(cl.camera.tapms = 20, "clamp: tap ms min")
Assert(cl.camera.tapstep = 5000, "clamp: step max")

WriteLines(cfg, [
    "[meta]",
    "version = 2",
    "game = ahk_exe Foo.exe$",
    "note = keep me",
    "",
    "[camera]",
    "up = o",
    "down = l",
    "left = k",
    'right = ";"',
    "tapstep = 505",
    "panstep = 75",
    "pantick = 40",
    "tapms = 200",
    "color = red",
    "",
    "[bindings]",
    "1 = Space | repeat-key | Space | 70 | 0 | -",
    "2 = 1,2,3,4,5 | repeat-key |  | 100 | 0 | switch",
    "3 = i | repeat-click |  | 150 | 0 | -",
    "4 = p | hold-click |  | 350 | 250 | -",
    "note = also keep me",
    "",
    "[scratch]",
    "x = 1",
])
back := LoadSettings(cfg, true)
Assert(back.bindings.Length = 4, "round trip: 4 bindings")
Assert(back.bindings[4].linger = 250, "round trip: linger")
Assert(back.camera.panstep = 75, "round trip: camera value")
Assert(back.camera.tapstep = 505, "round trip: a 5-multiple is left alone")

SaveSettings(back, cfg)
text := FileRead(cfg, "UTF-16")
Assert(InStr(text, "note = keep me"), "save: unknown [meta] key kept")
Assert(InStr(text, "color = red"), "save: unknown [camera] key kept")
Assert(InStr(text, "note = also keep me"), "save: unknown [bindings] key kept")
Assert(InStr(text, "[scratch]") && InStr(text, "x = 1"), "save: unknown section kept")
Assert(InStr(text, "ahk_exe Foo.exe$"), "save: the game line is written back")
Assert(InStr(text, 'right = ";"'), "save: ';' is quoted")
Assert(!InStr(text, "binding = "), "save: no flat v1 lines left")

SaveSettings(back, cfg)
Assert(FileRead(cfg, "UTF-16") == text, "save: a second write is identical")

dup := DefaultSettings()
dup.bindings[1].trigger := "o"
Assert(ConfigProblem(dup) != "", "check: a key used twice is refused")
dup := DefaultSettings()
dup.bindings[1].trigger := "1, Space"
Assert(InStr(ConfigProblem(dup), "1"), "check: duplicates inside a group row")
dup := DefaultSettings()
dup.bindings[1].trigger := "end"
Assert(ConfigProblem(dup) != "", "check: the quit key is reserved")

WriteLines(cfg, [
    "; game-assistant settings",
    "binding = Space | repeat-key | Space | 70 | 0 | -",
    "camera.up = o",
])
old := LoadSettings(cfg, true)
Assert(FileExist(cfg . ".v1.bak"), "migrate: the old file is kept as config.ini.v1.bak")
Assert(!FileExist(cfg), "migrate: the old file is moved, not left in place")
Assert(old.bindings.Length = 4, "migrate: the defaults are used")

for f in [cfg, cfg . ".tmp", cfg . ".v1.bak"]
    if FileExist(f)
        FileDelete(f)
FileAppend("selftest: " . (TestFails ? TestFails . " failure(s)" : "all passed") . "`n", "*")
ExitApp(TestFails ? 1 : 0)
