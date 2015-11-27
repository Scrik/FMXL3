library RatiborLib;

{$WEAKLINKRTTI ON}
{$RTTI EXPLICIT METHODS([]) PROPERTIES([]) FIELDS([])}
{$SETPEFLAGS
  $0004 or (* IMAGE_FILE_LINE_NUMS_STRIPPED      *)
  $0008 or (* IMAGE_FILE_LOCAL_SYMS_STRIPPED     *)
  $0020 or (* IMAGE_FILE_LARGE_ADDRESS_AWARE     *)
  $0200 or (* IMAGE_FILE_DEBUG_STRIPPED          *)
  $0400 or (* IMAGE_FILE_REMOVABLE_RUN_FROM_SWAP *)
  $0800    (* IMAGE_FILE_NET_RUN_FROM_SWAP       *)
}

uses
  Windows,
  SysUtils,
  MappingAPI in '..\Ratibor Commons\MappingAPI.pas',
  HookAPI    in '..\Ratibor Commons\HookAPI\HookAPI.pas',
  MicroDAsm  in '..\Ratibor Commons\HookAPI\MicroDAsm.pas',
  Ratibor    in '..\Ratibor Commons\Ratibor.pas';


//HHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHH
//                           Настройки перехвата
//HHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHH

const
  NtWriteVirtualMemoryEvent        = 0;
  NtWow64WriteVirtualMemory64Event = 1;

var
  IsHooked: Boolean = False;
  GlobalHookHandle: THandle = 0; // Хэндл глобального хука

  Events: array [0..1] of THandle = (0, 0);

  ProtectedProcessID: LongWord;
  ProtectedProcessHandle: THandle;

  NtWriteVirtualMemoryHookInfo: THookInfo;
  {$IFDEF CPUX86}
    NtWow64WriteVirtualMemory64HookInfo: THookInfo;
  {$ENDIF}

type
  NTSTATUS = NativeUInt;

  TNtWriteVirtualMemory = function(
                                    hProcess: THandle;
                                    BaseAddress: Pointer;
                                    Buffer: Pointer;
                                    BufferLength: NativeUInt;
                                    ReturnLength: PNativeUInt
                                   ): NTSTATUS; stdcall;
{$IFDEF CPUX86}
  TNtWow64WriteVirtualMemory64 = function(
                                           ProcessHandle: THandle;
                                           BaseAddress: UInt64;
                                           Buffer: Pointer;
                                           BufferLength: UInt64;
                                           ReturnLength: PUInt64
                                          ): NTSTATUS; stdcall;
{$ENDIF}


//HHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHH


procedure DbgPrint(const DbgString: string);
const
  Prefix: string = {$IFDEF CPUX64}'[RatiborLib|x64]: '{$ELSE}'[RatiborLib|x32]: '{$ENDIF};
begin
  OutputDebugString(PChar(Prefix + '(PID: ' + IntToStr(GetCurrentProcessID) + ') ' + DbgString));
end;


//HHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHH
//                      Обработчик перехваченных функций
//HHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHH

function HookedNtWriteVirtualMemory(
                                     hProcess: THandle;
                                     BaseAddress: Pointer;
                                     Buffer: Pointer;
                                     BufferLength: NativeUInt;
                                     ReturnLength: PNativeUInt
                                    ): NTSTATUS; stdcall;
var
  TargetProcessID: LongWord;
begin
  ResetEvent(Events[NtWriteVirtualMemoryEvent]);

  TargetProcessID := GetProcessID(hProcess);

  // Если работаем сами по себе или по незащищаемому процессу - разрешаем:
  if (TargetProcessID <> ProtectedProcessID) or (TargetProcessID = GetCurrentProcessID) then
  begin
    Result := TNtWriteVirtualMemory(NtWriteVirtualMemoryHookInfo.OriginalBlock)(hProcess, BaseAddress, Buffer, BufferLength, ReturnLength);
  end
  else
  begin
    Result := $C0000022;
  end;

  SetEvent(Events[NtWriteVirtualMemoryEvent]);
end;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

{$IFDEF CPUX86}
function HookedNtWow64WriteVirtualMemory64(
                                            hProcess: THandle;
                                            BaseAddress: UInt64;
                                            Buffer: Pointer;
                                            BufferLength: UInt64;
                                            ReturnLength: PUInt64
                                           ): NTSTATUS; stdcall;
var
  TargetProcessID: LongWord;
begin
  ResetEvent(Events[NtWow64WriteVirtualMemory64Event]);

  TargetProcessID := GetProcessID(hProcess);

  // Если работаем сами по себе или по незащищаемому процессу - разрешаем:
  if (TargetProcessID <> ProtectedProcessID) or (TargetProcessID = GetCurrentProcessID) then
  begin
    Result := TNtWow64WriteVirtualMemory64(NtWow64WriteVirtualMemory64HookInfo.OriginalBlock)(hProcess, BaseAddress, Buffer, BufferLength, ReturnLength);
  end
  else
  begin
    Result := $C0000022;
  end;

  SetEvent(Events[NtWow64WriteVirtualMemory64Event]);
end;

{$ENDIF}


//HHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHH
//                    Функции запуска и остановки защиты
//HHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHH

// Запуск защиты:
procedure StartDefence; stdcall; export;
begin
  if GlobalHookHandle = 0 then HookEmAll(GlobalHookHandle);
end;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

// Остановка защиты:
procedure StopDefence; stdcall; export;
begin
  if GlobalHookHandle <> 0 then UnHookEmAll(GlobalHookHandle);
end;

//HHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHH
//                   Обработка загрузки и выгрузки библиотеки
//HHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHH

procedure WaitForHooksExit;
begin
  {$IFDEF CPUX86}
    WaitForMultipleObjects(2, @Events[0], TRUE, INFINITE);
  {$ELSE}
    WaitForMultipleObjects(1, @Events[0], TRUE, INFINITE);
  {$ENDIF}
end;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

// Инициализация библиотеки:
procedure DLLMain(dwReason: LongWord);
var
  RatiborWrapper: TRatibor;
  hNTDLL: THandle;
begin
  case dwReason of
    DLL_PROCESS_ATTACH:
    begin
      // Получаем параметры в отображённой памяти:
      RatiborWrapper := TRatibor.Create;

      if not RatiborWrapper.OpenRatiborMapping then
      begin
        DbgPrint('Unable to open mapping!');
        Exit;
      end;

      if not RatiborWrapper.GetProtectedProcess(ProtectedProcessID) then
      begin
        DbgPrint('Unable to query protected process!');
        Exit;
      end;

      FreeAndNil(RatiborWrapper);

      // Если внедняемся в защищаемый процесс, то ничего не перехватываем:
      if ProtectedProcessID = GetCurrentProcessID then
      begin
        DbgPrint('Skip the protected process!');
        Exit;
      end;

      ProtectedProcessHandle := OpenProcess(SYNCHRONIZE, FALSE, ProtectedProcessID);
      if (ProtectedProcessHandle = 0) or (ProtectedProcessHandle = INVALID_HANDLE_VALUE) then
      begin
        DbgPrint('Unable to obtain protected process handle!');
        Exit;
      end;

      // Создаём события входа/выхода из функций:
      Events[NtWriteVirtualMemoryEvent] := CreateEvent(nil, True, True, nil);
      {$IFDEF CPUX86}
        Events[NtWow64WriteVirtualMemory64Event] := CreateEvent(nil, True, True, nil);
      {$ENDIF}

      hNTDLL := GetModuleHandle('ntdll.dll');

      StopThreads;

      NtWriteVirtualMemoryHookInfo.OriginalProcAddress := GetProcAddress(hNTDLL, 'NtWriteVirtualMemory');
      NtWriteVirtualMemoryHookInfo.HookProcAddress := @HookedNtWriteVirtualMemory;
      SetHook(NtWriteVirtualMemoryHookInfo, False);

      {$IFDEF CPUX86}
        NtWow64WriteVirtualMemory64HookInfo.OriginalProcAddress := GetProcAddress(hNTDLL, 'NtWow64WriteVirtualMemory64');
        NtWow64WriteVirtualMemory64HookInfo.HookProcAddress := @HookedNtWriteVirtualMemory;
        SetHook(NtWow64WriteVirtualMemory64HookInfo, False);
      {$ENDIF}

      RunThreads;

      IsHooked := True;
    end;

    DLL_PROCESS_DETACH:
    begin
{
      if (ProtectedProcessHandle <> 0) and (ProtectedProcessHandle <> INVALID_HANDLE_VALUE) then
        WaitForSingleObject(ProtectedProcessHandle, INFINITE);
}
      WaitForHooksExit;

      // Снимаем перехват:
      if IsHooked then
      begin
        StopThreads;
        UnHook(NtWriteVirtualMemoryHookInfo);
        {$IFDEF CPUX86}
          UnHook(NtWow64WriteVirtualMemory64HookInfo);
        {$ENDIF}
        RunThreads;
      end;

      WaitForHooksExit;
      Sleep(500);

      CloseHandle(Events[NtWriteVirtualMemoryEvent]);
      {$IFDEF CPUX86}
        CloseHandle(Events[NtWow64WriteVirtualMemory64Event]);
      {$ENDIF}

      StopDefence;
    end;
  end;
end;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

exports StartDefence;
exports StopDefence;

begin
  DllProc := @DLLMain;
  DllProc(DLL_PROCESS_ATTACH);
end.


