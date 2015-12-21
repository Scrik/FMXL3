unit AuxUtils;

interface

uses
  Windows, TlHelp32;

function Is64BitWindows: BOOL;
procedure StartProcess(const CommandLine: string; out ProcessHandle: THandle; out ProcessID: LongWord);

function MessageBoxTimeout(hWnd: HWND; lpText: PChar; lpCaption: PChar; uType: UINT; wLanguageId: WORD; dwMilliseconds: DWORD): Integer; stdcall; external user32 name 'MessageBoxTimeoutW';

implementation

function Is64BitWindows: BOOL;
{$IFNDEF CPUX64}
var
  IsWow64Process: function(hProcess: THandle; Wow64Process: PBOOL): BOOL; stdcall;
  Wow64Process: BOOL;
{$ENDIF}
begin
{$IFDEF CPUX64}
  Result := True;
{$ELSE}
  IsWow64Process := GetProcAddress(GetModuleHandle(kernel32), 'IsWow64Process');
  Wow64Process := False;
  if Assigned(IsWow64Process) then Wow64Process := IsWow64Process(GetCurrentProcess, @Wow64Process) and Wow64Process;

  Result := Wow64Process;
{$ENDIF}
end;


procedure StartProcess(const CommandLine: string; out ProcessHandle: THandle; out ProcessID: LongWord);
var
  ProcessInfo: _PROCESS_INFORMATION;
  StartupInfo: _STARTUPINFO;
begin
  FillChar(StartupInfo, SizeOf(StartupInfo), #0);
  FillChar(ProcessInfo, SizeOf(ProcessInfo), #0);

  StartupInfo.wShowWindow := SW_SHOWNORMAL;

  CreateProcess(
                 nil,
                 PChar(CommandLine),
                 nil,
                 nil,
                 FALSE,
                 0,
                 nil,
                 nil,
                 StartupInfo,
                 ProcessInfo
                );

  CloseHandle(ProcessInfo.hThread);

  ProcessHandle := ProcessInfo.hProcess;
  ProcessID := ProcessInfo.dwProcessId;
end;


end.
