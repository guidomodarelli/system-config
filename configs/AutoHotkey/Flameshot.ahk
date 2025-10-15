#Requires AutoHotkey v2.0
; Win+Shift+S -> Flameshot (GUI mode)
; Ajustá la ruta si instalaste Flameshot en otro lugar.
exe := "C:\Program Files\Flameshot\bin\flameshot.exe"

#+s::
{
    if !FileExist(exe) {
        MsgBox "No encontré Flameshot en:`n" exe "`nAjustá la variable 'exe' en este script."
        return
    }
    Run '"' exe '" gui'
}
