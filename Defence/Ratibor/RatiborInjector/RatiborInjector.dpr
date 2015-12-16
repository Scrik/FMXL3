program RatiborInjector;

{$WEAKLINKRTTI ON}
{$RTTI EXPLICIT METHODS([]) PROPERTIES([]) FIELDS([])}
{$SETPEFLAGS
  $0001 or (* IMAGE_FILE_RELOCS_STRIPPED         *)
  $0004 or (* IMAGE_FILE_LINE_NUMS_STRIPPED      *)
  $0008 or (* IMAGE_FILE_LOCAL_SYMS_STRIPPED     *)
  $0020 or (* IMAGE_FILE_LARGE_ADDRESS_AWARE     *)
  $0200 or (* IMAGE_FILE_DEBUG_STRIPPED          *)
  $0400 or (* IMAGE_FILE_REMOVABLE_RUN_FROM_SWAP *)
  $0800    (* IMAGE_FILE_NET_RUN_FROM_SWAP       *)
}

{$APPTYPE GUI}

uses
  Windows,
  SysUtils,
  MappingAPI in '..\Ratibor Commons\MappingAPI.pas',
  HookAPI    in '..\Ratibor Commons\HookAPI\HookAPI.pas',
  MicroDAsm  in '..\Ratibor Commons\HookAPI\MicroDAsm.pas',
  Ratibor    in '..\Ratibor Commons\Ratibor.pas';

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

const
  DbgPrefix: string = {$IFDEF CPUX64}'[Ratibor|x64]: '{$ELSE}'[Ratibor|x32]: '{$ENDIF};

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

procedure Shutdown(const DbgString: string); inline;
begin
  OutputDebugString(PChar(DbgPrefix + DbgString));
  ExitProcess(0);
end;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

procedure DbgPrint(const DbgString: string); inline;
begin
  OutputDebugString(PChar(DbgPrefix + DbgString));
end;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

procedure WaitProcess(ProcessID: LongWord); inline;
var
  ProcessHandle: THandle;
begin
  ProcessHandle := OpenProcess(SYNCHRONIZE, FALSE, ProcessID);
  if ProcessHandle = 0 then Exit;

  WaitForSingleObject(ProcessHandle, INFINITE);
  CloseHandle(ProcessHandle);
end;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

var
  StartDefence : procedure; stdcall;
  StopDefence  : procedure; stdcall;
  RatiborWrapper: TRatibor;
  ProtectedProcessID: LongWord;
  hLib: THandle;
begin
  NotifyEmAll;

  if not FileExists(TRatibor.RatiborLibNativeName) then Shutdown('Library not found!');

  hLib := LoadLibrary(PChar(TRatibor.RatiborLibNativeName));
  if (hLib = 0) or (hLib = INVALID_HANDLE_VALUE) then Shutdown('Unable to load library!');

  StartDefence := GetProcAddress(hLib, 'StartDefence');
  StopDefence  := GetProcAddress(hLib, 'StopDefence');

  if (@StartDefence = nil) or (@StopDefence = nil) then Shutdown('Unable to query StartDefence ot StopDefence address!');

  RatiborWrapper := TRatibor.Create;
  if not RatiborWrapper.OpenRatiborMapping then Shutdown('Mapping not exists!');
  if not RatiborWrapper.GetProtectedProcess(ProtectedProcessID) then Shutdown('Protected process not specified!');

  DbgPrint('Protected PID = ' + ProtectedProcessID.ToString);

  StartDefence;
  WaitProcess(ProtectedProcessID);
  StopDefence;

  FreeLibrary(hLib);

  NotifyEmAll;

  DbgPrint('Protection shutdown');
end.

