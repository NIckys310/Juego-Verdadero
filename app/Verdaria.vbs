' Verdaria como aplicación: servidor local invisible + ventana propia de Edge/Chrome.
' Al cerrar la ventana del juego se detiene el servidor. Las partidas se guardan en
' %LOCALAPPDATA%\Verdaria\perfil (perfil del navegador exclusivo de la app).
Option Explicit
Dim sh, fso, base, web, profile, browser, server, url, candidates, c
Set sh = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")
base = fso.GetParentFolderName(WScript.ScriptFullName)
web = fso.GetAbsolutePathName(fso.BuildPath(base, "..\export\web"))
url = "http://127.0.0.1:8765/"

If Not fso.FileExists(fso.BuildPath(web, "index.html")) Then
  MsgBox "No encuentro el juego exportado en:" & vbCrLf & web, vbExclamation, "Verdaria"
  WScript.Quit 1
End If

candidates = Array( _
  sh.ExpandEnvironmentStrings("%ProgramFiles(x86)%") & "\Microsoft\Edge\Application\msedge.exe", _
  sh.ExpandEnvironmentStrings("%ProgramFiles%") & "\Microsoft\Edge\Application\msedge.exe", _
  sh.ExpandEnvironmentStrings("%ProgramFiles%") & "\Google\Chrome\Application\chrome.exe", _
  sh.ExpandEnvironmentStrings("%LOCALAPPDATA%") & "\Google\Chrome\Application\chrome.exe")
browser = ""
For Each c In candidates
  If browser = "" And fso.FileExists(c) Then browser = c
Next
If browser = "" Then
  MsgBox "Verdaria necesita Microsoft Edge o Google Chrome.", vbExclamation, "Verdaria"
  WScript.Quit 1
End If

On Error Resume Next
Set server = sh.Exec("pythonw -I -m http.server 8765 --bind 127.0.0.1 --directory """ & web & """")
If Err.Number <> 0 Then
  MsgBox "Verdaria necesita Python instalado (python.org).", vbExclamation, "Verdaria"
  WScript.Quit 1
End If
On Error GoTo 0
WScript.Sleep 800

profile = sh.ExpandEnvironmentStrings("%LOCALAPPDATA%") & "\Verdaria\perfil"
' Perfil nuevo: sin modo en segundo plano, para que cerrar la ventana cierre la app.
If Not fso.FileExists(profile & "\Local State") Then
  If Not fso.FolderExists(sh.ExpandEnvironmentStrings("%LOCALAPPDATA%") & "\Verdaria") Then fso.CreateFolder sh.ExpandEnvironmentStrings("%LOCALAPPDATA%") & "\Verdaria"
  If Not fso.FolderExists(profile) Then fso.CreateFolder profile
  fso.CreateTextFile(profile & "\Local State", True).Write "{""background_mode"":{""enabled"":false},""startup_boost"":{""enabled"":false}}"
End If
' Espera a que se cierre la ventana del juego.
sh.Run """" & browser & """ --app=" & url & " --user-data-dir=""" & profile & """ --window-size=1300,860 --no-first-run --no-default-browser-check --autoplay-policy=no-user-gesture-required", 1, True

On Error Resume Next
server.Terminate
