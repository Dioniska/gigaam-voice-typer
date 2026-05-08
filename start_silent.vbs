' Тихий запуск без видимой консоли
Set sh = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")
dir = fso.GetParentFolderName(WScript.ScriptFullName)
pyw = dir & "\.venv\Scripts\pythonw.exe"
script = dir & "\voice_typer.py"

If Not fso.FileExists(pyw) Then
    MsgBox "Окружение не найдено. Сначала запустите setup.bat", 16, "GigaAM Voice Typer"
    WScript.Quit 1
End If

sh.Environment("Process").Item("PYTHONUTF8") = "1"
sh.Run """" & pyw & """ -X utf8 """ & script & """", 0, False
