unit AuxUtils;

interface

uses
  Windows, TlHelp32;

procedure StopThreads;
function Is64BitWindows: BOOL;
procedure StartProcess(const CommandLine: string; out ProcessHandle: THandle; out ProcessID: LongWord);

function MessageBoxTimeout(hWnd: HWND; lpText: PChar; lpCaption: PChar; uType: UINT; wLanguageId: WORD; dwMilliseconds: DWORD): Integer; stdcall; external user32 name 'MessageBoxTimeoutW';

implementation

const
  THREAD_SUSPEND_RESUME = $0002;

function OpenThread(
                     dwDesiredAccess: LongWord;
                     bInheritHandle: LongBool;
                     dwThreadId: LongWord
                    ): LongWord; stdcall; external 'kernel32.dll';

// Заморозить все потоки процесса, кроме текущего:
procedure StopThreads;
var
  TlHelpHandle, CurrentThreadID, ThreadHandle, CurrentProcessID: LongWord;
  ThreadEntry32: TThreadEntry32;
begin
  CurrentThreadID := GetCurrentThreadId;
  CurrentProcessID := GetCurrentProcessId;
  TlHelpHandle := CreateToolhelp32Snapshot(TH32CS_SNAPTHREAD, 0);
  if TlHelpHandle <> INVALID_HANDLE_VALUE then
  begin
    ThreadEntry32.dwSize := SizeOf(TThreadEntry32);
    if Thread32First(TlHelpHandle, ThreadEntry32) then
    repeat
      if (ThreadEntry32.th32ThreadID <> CurrentThreadID) and (ThreadEntry32.th32OwnerProcessID = CurrentProcessID) then
      begin
        ThreadHandle := OpenThread(THREAD_SUSPEND_RESUME, FALSE, ThreadEntry32.th32ThreadID);
        if ThreadHandle > 0 then
        begin
          SuspendThread(ThreadHandle);
          CloseHandle(ThreadHandle);
        end;
      end;
    until not Thread32Next(TlHelpHandle, ThreadEntry32);

    CloseHandle(TlHelpHandle);
  end;
end;


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
