#Requires AutoHotkey v2.0

ArrayToString(arr) {
    if ( not (arr is Array)) {
        throw TypeError("ArrayToString expects an array, got " . Type(arr))
    }
    s := ""
    for v in arr
        if (v is Array)
            s .= ArrayToString(v) ", "
        else
            s .= v ", "
    return "[" RTrim(s, ", ") "]"
}
