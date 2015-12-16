unit HookAPI;

interface

uses
  Windows, TlHelp32, MicroDAsm;

const
  SE_DEBUG_NAME            = 'SeDebugPrivilege';
  THREAD_SUSPEND_RESUME    = $0002;
  THREAD_GET_CONTEXT       = $0008;
  THREAD_SET_CONTEXT       = $0010;
  THREAD_QUERY_INFORMATION = $0040;
  THREAD_SET_INFORMATION   = $0020;

//HHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHH

{$IFDEF CPUX64}
// Структура для х64:
type
  TFarJump = packed record
    MovRaxOp  : Word;    //                   49 B8 | mov rax
    MovRaxArg : Pointer; // 88 77 66 55 44 33 22 11 | qword $1122334455667788
    JmpRaxOp  : Word;    //                   FF E0 | jmp rax
  end;

  TCodeSelectorJump = packed record  //      |  1  |  2  |  3  |
    JmpCsOp  : array [0..2] of Word; //       FF 25 00 00 00 00 | --+
    JmpCsArg : Pointer;              // 88 77 66 55 44 33 22 11 | --+--> jmp cs:$1122334455667788
  end;

  NativeInt  = Int64;
  NativeUInt = UInt64;
{$ELSE}
// Структура для х32:
type
  TFarJump = packed record
    JmpOp  : Byte;    //          E9 | jmp
    JmpArg : Pointer; // 44 33 22 11 | dword $11223344
  end;

  NativeInt  = Integer;
  NativeUInt = LongWord;
{$ENDIF}

//HHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHH

// Установка привилегий:
function NTSetPrivilege(Privilege: string; Enabled: Boolean): Boolean;

// Внедрение библиотеки:
function InjectDll32(ProcessID: LongWord; ModulePath: PAnsiChar): Boolean;
function InjectDll64(ProcessID: LongWord; ModulePath: PAnsiChar): Boolean;

// Выгрузка библиотеки:
function UnloadDll32(ProcessID: LongWord; ModuleName: PAnsiChar): Boolean;
function UnloadDll64(ProcessID: LongWord; ModuleName: PAnsiChar): Boolean;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

// Структура с информацией о перехвате:
type
  THookInfo = record
    OriginalProcAddress : Pointer;  // [in]  Адрес оригинальной (перехватываемой) функции
    HookProcAddress     : Pointer;  // [in]  Адрес функции-перехватчика
    OriginalBlock       : Pointer;  // [out] Адрес блока с оригинальным началом перехватываемой функции
    OriginalCodeSize    : LongWord; // [out] Размер оригинального кода в OriginalBlock'е в байтах
    OriginalBlockSize   : LongWord; // [out] Полный размер OriginalBlock'а (с учётом прыжка на продолжение)
  end;
  PHookInfo = ^THookInfo;

// Для DLL:
procedure StopThreads;
procedure RunThreads;
function  SetHook(var HookInfo: THookInfo; SuspendThreads: Boolean = True): Boolean;
function  UnHook(var HookInfo: THookInfo; SuspendThreads: Boolean = True): Boolean;
function  HookEmAll(out GlobalHookHandle: THandle): Boolean;
procedure UnHookEmAll(var GlobalHookHandle: THandle);
procedure NotifyEmAll;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

(*

  Для шелл-кода использовать только соглашение о вызове stdcall!

  В шелл-коде для InjectFunction нельзя использовать код, содержащий прыжки
  по абсолютным адресам, адреса всех API-функций получать динамически
  через GetProcAddress. Адреса GetProcAddress, GetModuleHandle и LoadLibrary,
  а также все необходимые данные передавать как аргумент в виде структуры.
  Нельзя использовать ООП и Delphi RTL (строки, динамические массивы и т.д.).
  Нельзя допускать генерации компилятором прыжков по абсолютным адресам:
  код должен быть компактным, следует избегать циклов с большим телом.

  В шелл-коде для InjectExeImage/InjectSelfExeImage допускается использование
  всех возможностей языка, но предварительно нужно убедиться в наличии в
  целевом процессе необходимых библиотек: вызвать LoadLibrary,
  загрузив нужные модули.
  Для инжектируемого эксешника требуется задать IMAGE_BASE_ADDRESS таким
  образом, чтобы он попадал на свободную облась памяти в целевом процессе -
  делается это с помощью флага {$IMAGEBASE $XXXXXXXX}

*)

// Инъекция шелл-кода напрямую:
procedure InjectFunction(
                          ProcessID: LongWord;
                          InjectedFunction: Pointer;
                          InjectedFunctionSize: NativeUInt;
                          Arguments: Pointer;
                          ArgumentsSize: NativeUInt;
                          Wait: Boolean = FALSE
                         );

// Внедрение образа целиком (ExeImage - указатель на образ эксешника в памяти текущего процесса):
procedure InjectExeImage(ProcessID: LongWord; ExeImage: Pointer; Wait: Boolean = FALSE);

// Внедрение своего образа (EntryPoint - точка входа - адрес функции, которую хотим выполнить):
procedure InjectSelfExeImage(ProcessID: LongWord; EntryPoint: Pointer; Wait: Boolean = FALSE);

//HHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHH

// Атомарные операции взведения и сброса логического флажка:
procedure InterlockedSet(FlagPtr: PBoolean); register;
procedure InterlockedReset(FlagPtr: PBoolean); register;

type
  // Синхронный флажок для оригинального вызова:
  TOriginalCall = class
    private
      FCriticalSection: _RTL_CRITICAL_SECTION;
      FOriginalCall: Boolean;
    public
      constructor Create;
      destructor  Destroy; override;

      function  GetState: Boolean;        // Получить значение
      procedure SetState(Value: Boolean); // Установить значение
      procedure SetOriginalCall;          // Взвести флажок и перейти в блокирующее состояние
      procedure ResetOriginalCall;        // Сбросить флажок и выйти из блокирующего состояния
  end;

//HHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHH

implementation

type
  NTSTATUS = NativeUInt;

function NtWriteVirtualMemory(
                               hProcess: THandle;
                               BaseAddress: Pointer;
                               Buffer: Pointer;
                               BufferLength: NativeUInt;
                               out ReturnLength: NativeUInt
                              ): NTSTATUS; stdcall; external 'ntdll.dll';


function NtReadVirtualMemory(
                              hProcess: THandle;
                              BaseAddress: Pointer;
                              Buffer: Pointer;
                              BufferSize: NativeUInt;
                              out ReturnLength: NativeUInt
                             ): NTSTATUS; stdcall; external 'ntdll.dll';


function OpenThread(
                     dwDesiredAccess: LongWord;
                     bInheritHandle: LongBool;
                     dwThreadId: LongWord
                    ): LongWord; stdcall; external 'kernel32.dll';

const
  AccessRights = PROCESS_CREATE_THREAD     or
                 PROCESS_QUERY_INFORMATION or
                 PROCESS_VM_OPERATION      or
                 PROCESS_VM_WRITE          or
                 PROCESS_VM_READ;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -


// Установка привилегий для работы с чужими процессами:
function NTSetPrivilege(Privilege: string; Enabled: Boolean): Boolean;
var
  hToken: THandle;
  TokenPriv: TOKEN_PRIVILEGES;
  PrevTokenPriv: TOKEN_PRIVILEGES;
  ReturnLength: Cardinal;
begin
  if OpenProcessToken(GetCurrentProcess, TOKEN_ADJUST_PRIVILEGES or TOKEN_QUERY, hToken) then
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


(* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

// Оригинальная функция:
procedure LoadHookLib32;
const
  HookLib: PAnsiChar = 'HookLib.dll';
asm
  push HookLib
  call LoadLibraryA

  xor eax, eax
  push eax
  call ExitThread
end;

- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - *)

// Инъекция в 32х-битные процессы:
function InjectDll32(ProcessID: LongWord; ModulePath: PAnsiChar): Boolean;
var
  ProcessHandle : NativeUInt;
  Memory        : Pointer;
  Code          : LongWord;
  BytesWritten  : NativeUInt;
  ThreadId      : LongWord;
  hThread       : LongWord;
  hKernel32     : LongWord;

  DataOffset    : LongWord;

  // Структура машинного кода инициализации и запуска библиотеки:
  Inject: packed record
    // GMH* = GetModuleHandle:   { 11 байт }
    GMHPushCommand  : Byte;
    GMHPushArgument : LongWord;
    GMHCallCommand  : Word;
    GMHCallAddr     : LongWord;

    TestEaxEaxCommand : Word;    { 8 байт }
    JnzCommand        : Word;
    JnzArgument       : Pointer;

    // LL* = LoadLibrary:        { 11 байт }
    LLPushCommand  : Byte;
    LLPushArgument : LongWord;
    LLCallCommand  : Word;
    LLCallAddr     : LongWord;

    // ET* = ExitThread:         { 11 байт }
    ETPushCommand  : Byte;
    ETPushArgument : LongWord;
    ETCallCommand  : Word;
    ETCallAddr     : LongWord;

    AddrGetModuleHandle : LongWord;
    AddrLoadLibrary     : LongWord;
    AddrExitThread      : LongWord;
    LibraryName         : array [0..MAX_PATH] of AnsiChar;
  end;

  // Расчёт относительно адреса для прыжка в х32 ( 85 0F [ Относительный адрес ] )
  function GetRelativeJmp32Address(Source, Destination: Pointer): Pointer; inline;
  begin
    Result := Pointer(NativeInt(Destination) - NativeInt(Source) - 5);
  end;

  // Получает путь к папке:
  function ExtractFilePath(Path: AnsiString): AnsiString; inline;
  var
    I: LongWord;
    PathLen: LongWord;
  begin
    PathLen := Length(Path);
    I := PathLen;
    while (I <> 0) and (Path[I] <> '\') and (Path[I] <> '/') do Dec(I);
    Result := Copy(Path, 0, I);
  end;

begin
  Result := false;

  ProcessHandle := OpenProcess(AccessRights, FALSE, ProcessID);
  if ProcessHandle = 0 then Exit;

  // Выделяем память в контексте процесса, куда запишем код вызова библиотеки перехватчика:
  Memory := VirtualAllocEx(ProcessHandle, nil, SizeOf(Inject), MEM_COMMIT, PAGE_EXECUTE_READWRITE);
  if Memory = nil then Exit;

  Code := LongWord(Memory);
  FillChar(Inject, SizeOf(Inject), #0);

  DataOffset := Code + 41;

// GetModuleHandleA:
  Inject.GMHPushCommand  := $68;
  Inject.GMHPushArgument := DataOffset + 12 + Cardinal(Length(ExtractFilePath(ModulePath)));
  Inject.GMHCallCommand  := $15FF;
  Inject.GMHCallAddr     := DataOffset;

  Inject.TestEaxEaxCommand := $C085;
  Inject.JnzCommand        := $850F;
  Inject.JnzArgument       := GetRelativeJmp32Address(Pointer(NativeUInt(Code) + 14), Pointer(NativeUInt(Code) + 30));

// LoadLibraryA:
  Inject.LLPushCommand  := $68;
  Inject.LLPushArgument := DataOffset + 12;
  Inject.LLCallCommand  := $15FF;
  Inject.LLCallAddr     := DataOffset + 4;

// ExitThread:
  Inject.ETPushCommand  := $68;
  Inject.ETPushArgument := 0;
  Inject.ETCallCommand  := $15FF;
  Inject.ETCallAddr     := DataOffset + 8;

  hKernel32 := GetModuleHandle('kernel32.dll');
  Inject.AddrGetModuleHandle := LongWord(GetProcAddress(hKernel32, 'GetModuleHandleA'));
  Inject.AddrLoadLibrary := LongWord(GetProcAddress(hKernel32, 'LoadLibraryA'));
  Inject.AddrExitThread  := LongWord(GetProcAddress(hKernel32, 'ExitThread'));

  Move(ModulePath^, Inject.LibraryName, Length(ModulePath));

//  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -

  // Записываем машинный код в выделенную память:
  if NtWriteVirtualMemory(ProcessHandle, Memory, @Inject, SizeOf(Inject), BytesWritten) <> 0 then Exit;

  // Выполняем машинный код в отдельном потоке:
  hThread := CreateRemoteThread(ProcessHandle, nil, 0, Memory, nil, 0, ThreadId);

  if hThread = 0 then
  begin
    VirtualFreeEx(ProcessHandle, Memory, 0, MEM_RELEASE);
    CloseHandle(ProcessHandle);
    Exit;
  end;

  WaitForSingleObject(hThread, INFINITE);
  VirtualFreeEx(ProcessHandle, Memory, 0, MEM_RELEASE);

  CloseHandle(hThread);
  CloseHandle(ProcessHandle);

  Result := True;
end;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

// Выгрузка библиотеки из 32х-битных процессов:
function UnloadDll32(ProcessID: LongWord; ModuleName: PAnsiChar): Boolean;
var
  ProcessHandle : NativeUInt;
  Memory        : Pointer;
  Code          : LongWord;
  BytesWritten  : NativeUInt;
  ThreadId      : LongWord;
  hThread       : LongWord;
  hKernel32     : LongWord;

  // Структура машинного кода инициализации и запуска библиотеки:
  Inject: packed record
    // GMH* = GetModuleHandle:
    GMHPushCommand  : Byte;
    GMHPushArgument : LongWord;
    GMHCallCommand  : Word;
    GMHCallAddr     : LongWord;

    // FL* = FreeLibrary:
    FLPushEax     : Byte;
    FLCallCommand : Word;
    FLCallAddr    : LongWord;

    // ET* = ExitThread:
    ETPushCommand  : Byte;
    ETPushArgument : LongWord;
    ETCallCommand  : Word;
    ETCallAddr     : LongWord;

    AddrGetModuleHandle : LongWord;
    AddrFreeLibrary     : LongWord;
    AddrExitThread      : LongWord;
    LibraryName         : array [0..MAX_PATH] of AnsiChar;
  end;
begin
  Result := False;

  ProcessHandle := OpenProcess(AccessRights, FALSE, ProcessID);
  if ProcessHandle = 0 then Exit;

  // Выделяем память в контексте процесса, куда запишем код вызова библиотеки перехватчика:
  Memory := VirtualAllocEx(ProcessHandle, nil, SizeOf(Inject), MEM_COMMIT, PAGE_EXECUTE_READWRITE);
  if Memory = nil then Exit;

  Code := LongWord(Memory);
  FillChar(Inject, SizeOf(Inject), #0);

// GetModuleHandleA:
  Inject.GMHPushCommand  := $68;
  Inject.GMHPushArgument := Code + 41;
  Inject.GMHCallCommand  := $15FF;
  Inject.GMHCallAddr     := Code + 29;

// FreeLibrary:
  Inject.FLPushEax     := $50;
  Inject.FLCallCommand := $15FF;
  Inject.FLCallAddr    := Code + 33;

// ExitThread:
  Inject.ETPushCommand  := $68;
  Inject.ETPushArgument := 0;
  Inject.ETCallCommand  := $15FF;
  Inject.ETCallAddr     := Code + 37;

  hKernel32 := GetModuleHandle('kernel32.dll');
  Inject.AddrGetModuleHandle := LongWord(GetProcAddress(hKernel32, 'GetModuleHandleA'));
  Inject.AddrFreeLibrary := LongWord(GetProcAddress(hKernel32, 'FreeLibrary'));
  Inject.AddrExitThread  := LongWord(GetProcAddress(hKernel32, 'ExitThread'));

  Move(ModuleName^, Inject.LibraryName, Length(ModuleName));

//  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -

  // Записываем машинный код в выделенную память:
  if NtWriteVirtualMemory(ProcessHandle, Memory, @Inject, SizeOf(Inject), BytesWritten) <> 0 then Exit;

  // Выполняем машинный код в отдельном потоке:
  hThread := CreateRemoteThread(ProcessHandle, nil, 0, Memory, nil, 0, ThreadId);

  if hThread = 0 then
  begin
    VirtualFreeEx(ProcessHandle, Memory, 0, MEM_RELEASE);
    CloseHandle(ProcessHandle);
    Exit;
  end;

  WaitForSingleObject(hThread, INFINITE);
  VirtualFreeEx(ProcessHandle, Memory, 0, MEM_RELEASE);

  CloseHandle(hThread);
  CloseHandle(ProcessHandle);

  Result := True;
end;


(* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
{
  Передача параметров в х64-функции:

  RCX - первый параметр
  RDX - второй параметр
  R8 - третий параметр
  R9 - четвёртый параметр

  Остальное через стек в соответствии с соглашением о вызове

  Стек необходимо выравнивать при входе в функцию:
  asm
    push rbp
    sub rsp, $20
    mov rbp, rsp

    ...

    lea rsp, [rbp+$20]
    pop rbp
    ret
  end;
}

// Оригинальная функция:
procedure LoadHookLib64;
const
  HookLib: PAnsiChar = 'HookLib.dll';
asm
  push rbp
  sub rsp, $20
  mov rbp, rsp

  mov rcx, HookLibName
  call GetModuleHandleA

  test rax, rax
  jnz @Exit

  mov rcx, HookLib
  call LoadLibraryA

@Exit:
  mov rcx, $0000000000000000
  call ExitThread

  lea rsp, [rbp+$20]
  pop rbp
  ret
end;

- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - *)


// Инъекция в 64х-битные процессы:
function InjectDll64(ProcessID: LongWord; ModulePath: PAnsiChar): Boolean;
var
  ProcessHandle : NativeUInt;
  Memory        : Pointer;
  Code          : UInt64;
  BytesWritten  : NativeUInt;
  ThreadId      : LongWord;
  hThread       : LongWord;
  hKernel32     : NativeUInt;

  DataOffset    : UInt64;

  // Структура машинного кода инициализации и запуска библиотеки:
  Inject: packed record
    AlignStackAtStart: UInt64;    { 8 байт }

    // GMH* = GetModuleHandle:    { 28 байт }
    GMHMovRaxCommand  : Word;
    GMHMovRaxArgument : UInt64;
    GMHMovRaxData     : array [0..2] of Byte;
    GMHMovRcxCommand  : Word;
    GMHMovRcxArgument : UInt64;
    GMHCallRax        : array [0..2] of Byte;

                                  { 13 байт }
    TestRaxRaxCommand : array [0..2] of Byte;
    JnzCommand        : Word;
    JnzArgument       : LongWord;

    // LL* = LoadLibrary:         { 28 байт }
    LLMovRaxCommand  : Word;
    LLMovRaxArgument : UInt64;
    LLMovRaxData     : array [0..2] of Byte;
    LLMovRcxCommand  : Word;
    LLMovRcxArgument : UInt64;
    LLCallRax        : array [0..2] of Byte;

    // ET* = ExitThread:          { 28 байт }
    ETMovRaxCommand  : Word;
    ETMovRaxArgument : UInt64;
    ETMovRaxData     : array [0..2] of Byte;
    ETMovRcxCommand  : Word;
    ETMovRcxArgument : UInt64;
    ETCallRax        : array [0..2] of Byte;

    AlignStackAtEnd  : UInt64;    { 8 байт }

    NopAlignByte     : Byte;

    AddrGetModuleHandle : UInt64;
    AddrLoadLibrary     : UInt64;
    AddrExitThread      : UInt64;
    LibraryName         : array [0..MAX_PATH] of AnsiChar;
  end;

  // Расчёт относительно адреса для прыжка в х32 ( 85 0F [ Относительный адрес ] )
  function GetRelativeJmp32Address(Source, Destination: Pointer): Pointer; inline;
  begin
    Result := Pointer(NativeInt(Destination) - NativeInt(Source) - 5);
  end;

  // Получает путь к папке:
  function ExtractFilePath(Path: AnsiString): AnsiString; inline;
  var
    I: LongWord;
    PathLen: LongWord;
  begin
    PathLen := Length(Path);
    I := PathLen;
    while (I <> 0) and (Path[I] <> '\') and (Path[I] <> '/') do Dec(I);
    Result := Copy(Path, 0, I);
  end;

begin
  Result := False;

  ProcessHandle := OpenProcess(AccessRights, FALSE, ProcessID);
  if ProcessHandle = 0 then Exit;

// Выделяем память в контексте процесса, куда запишем код вызова библиотеки перехватчика:
  Memory := VirtualAllocEx(ProcessHandle, nil, SizeOf(Inject), MEM_COMMIT, PAGE_EXECUTE_READWRITE);
  if Memory = nil then Exit;

  Code := UInt64(Memory);
  FillChar(Inject, SizeOf(Inject), #0);

  DataOffset := Code + 104;

// Выравниваем 64х-битный стек:
  Inject.AlignStackAtStart := $E5894820EC834855;

{
   + - - - - - - - - - - - +
   |  RAX - адрес функции  |
   |  RCX - параметры      |
   + - - - - - - - - - - - +
}

// GetModuleHandleA:
  Inject.GMHMovRaxCommand  := $B848;
  Inject.GMHMovRaxArgument := DataOffset; // Code + смещение до адреса GetModuleHandleA

  Inject.GMHMovRaxData[0] := $48; //  ---+
  Inject.GMHMovRaxData[1] := $8B; //  ---+--->  mov RAX, [RAX]
  Inject.GMHMovRaxData[2] := $00; //  ---+

  Inject.GMHMovRcxCommand  := $B948;
  Inject.GMHMovRcxArgument := DataOffset + 24 + Cardinal(Length(ExtractFilePath(ModulePath))); // Code + смещение до начала пути к библиотеке

  Inject.GMHCallRax[0] := $48;
  Inject.GMHCallRax[1] := $FF;
  Inject.GMHCallRax[2] := $D0;


  Inject.TestRaxRaxCommand[0] := $48; // ---+
  Inject.TestRaxRaxCommand[1] := $85; // ---+---> test RAX, RAX
  Inject.TestRaxRaxCommand[2] := $C0; // ---+

  Inject.JnzCommand  := $850F; // jnz @ExitThread
  Inject.JnzArgument := LongWord(GetRelativeJmp32Address(Pointer(NativeUInt(Code) + 46), Pointer(NativeUInt(Code) + 77)));


// LoadLibraryA:
  Inject.LLMovRaxCommand  := $B848;
  Inject.LLMovRaxArgument := DataOffset + 8; // Code + смещение до адреса LoadLibraryA

  Inject.LLMovRaxData[0] := $48; //  ---+
  Inject.LLMovRaxData[1] := $8B; //  ---+--->  mov RAX, [RAX]
  Inject.LLMovRaxData[2] := $00; //  ---+

  Inject.LLMovRcxCommand  := $B948;
  Inject.LLMovRcxArgument := DataOffset + 24; // Code + смещение до начала пути к библиотеке

  Inject.LLCallRax[0] := $48;
  Inject.LLCallRax[1] := $FF;
  Inject.LLCallRax[2] := $D0;

// ExitThread:
  Inject.ETMovRaxCommand  := $B848;
  Inject.ETMovRaxArgument := DataOffset + 16; // Code + смещение до адреса ExitThread

  Inject.ETMovRaxData[0] := $48; //  ---+
  Inject.ETMovRaxData[1] := $8B; //  ---+--->  mov RAX, [RAX]
  Inject.ETMovRaxData[2] := $00; //  ---+

  Inject.ETMovRcxCommand  := $B948;
  Inject.ETMovRcxArgument := $0000000000000000; // ExitCode = 0

  Inject.ETCallRax[0] := $48;
  Inject.ETCallRax[1] := $FF;
  Inject.ETCallRax[2] := $D0;

// Выравниваем 64х-битный стек:
  Inject.AlignStackAtEnd := $90C3C35D20658D48;

  Inject.NopAlignByte := $90;

// Записываем адреса библиотек:
  hKernel32 := LoadLibrary('kernel32.dll');
  Inject.AddrGetModuleHandle := UInt64(GetProcAddress(hKernel32, 'GetModuleHandleA'));
  Inject.AddrLoadLibrary := UInt64(GetProcAddress(hKernel32, 'LoadLibraryA'));
  Inject.AddrExitThread  := UInt64(GetProcAddress(hKernel32, 'ExitThread'));

  Move(ModulePath^, Inject.LibraryName, Length(ModulePath));

//  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -

  // Записываем машинный код в выделенную память:
  if NtWriteVirtualMemory(ProcessHandle, Memory, @Inject, SizeOf(Inject), BytesWritten) <> 0 then Exit;

  // Выполняем машинный код в отдельном потоке:
  hThread := CreateRemoteThread(ProcessHandle, nil, 0, Memory, nil, 0, ThreadId);

  if hThread = 0 then
  begin
    VirtualFreeEx(ProcessHandle, Memory, 0, MEM_RELEASE);
    CloseHandle(ProcessHandle);
    Exit;
  end;

  WaitForSingleObject(hThread, INFINITE);
  VirtualFreeEx(ProcessHandle, Memory, 0, MEM_RELEASE);

  CloseHandle(hThread);
  CloseHandle(ProcessHandle);

  Result := True;
end;


// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

// Выгрузка библиотеки из 64х-битных процессов:
function UnloadDll64(ProcessID: LongWord; ModuleName: PAnsiChar): Boolean;
var
  ProcessHandle : NativeUInt;
  Memory        : Pointer;
  Code          : UInt64;
  BytesWritten  : NativeUInt;
  ThreadId      : LongWord;
  hThread       : LongWord;
  hKernel32     : NativeUInt;

  // Структура машинного кода инициализации и запуска библиотеки:
  Inject: packed record
    AlignStackAtStart: UInt64;                // 8

    // GMH* = GetModuleHandle:
    GMHMovRaxCommand  : Word;                 // 2
    GMHMovRaxArgument : UInt64;               // 8
    GMHMovRaxData     : array [0..2] of Byte; // 3
    GMHMovRcxCommand  : Word;                 // 2
    GMHMovRcxArgument : UInt64;               // 8
    GMHCallRax        : array [0..2] of Byte; // 3

    // FL* = FreeLibrary:
    FLMovRcxRax      : array [0..2] of Byte;  // 3
    FLMovRaxCommand  : Word;                  // 2
    FLMovRaxArgument : UInt64;                // 8
    FLMovRaxData     : array [0..2] of Byte;  // 3
    FLCallRax        : array [0..2] of Byte;  // 3

    // ET* = ExitThread:
    ETMovRaxCommand  : Word;                  // 2
    ETMovRaxArgument : UInt64;                // 8
    ETMovRaxData     : array [0..2] of Byte;  // 3
    ETMovRcxCommand  : Word;                  // 2
    ETMovRcxArgument : UInt64;                // 8
    ETCallRax        : array [0..2] of Byte;  // 3

    AlignStackAtEnd  : UInt64;                // 8

    AddrGetModuleHandle : UInt64;             // 8
    AddrFreeLibrary     : UInt64;             // 8
    AddrExitThread      : UInt64;             // 8
    LibraryName         : array [0..MAX_PATH] of AnsiChar;
  end;
begin
  Result := false;

  ProcessHandle := OpenProcess(AccessRights, FALSE, ProcessID);
  if ProcessHandle = 0 then Exit;

// Выделяем память в контексте процесса, куда запишем код вызова библиотеки перехватчика:
  Memory := VirtualAllocEx(ProcessHandle, nil, SizeOf(Inject), MEM_COMMIT, PAGE_EXECUTE_READWRITE);
  if Memory = nil then
  begin
    CloseHandle(ProcessHandle);
    Exit;
  end;

  Code := UInt64(Memory);
  FillChar(Inject, SizeOf(Inject), #0);

// Выравниваем 64х-битный стек:
  Inject.AlignStackAtStart := $E5894820EC834855;

{
   + - - - - - - - - - - - +
   |  RAX - адрес функции  |
   |  RCX - параметры      |
   + - - - - - - - - - - - +
}

// GetModuleHandleA:
  Inject.GMHMovRaxCommand  := $B848;
  Inject.GMHMovRaxArgument := Code + 87; // Code + смещение до адреса GetModuleHandleA

  Inject.GMHMovRaxData[0] := $48; //  ---+
  Inject.GMHMovRaxData[1] := $8B; //  ---+--->  mov RAX, [RAX]
  Inject.GMHMovRaxData[2] := $00; //  ---+

  Inject.GMHMovRcxCommand  := $B948;
  Inject.GMHMovRcxArgument := Code + 111; // Code + смещение до начала имени библиотеки

  Inject.GMHCallRax[0] := $48;
  Inject.GMHCallRax[1] := $FF;
  Inject.GMHCallRax[2] := $D0;

// FreeLibrary:
  Inject.FLMovRcxRax[0] := $48; //  ---+
  Inject.FLMovRcxRax[1] := $89; //  ---+--->  mov RCX, RAX
  Inject.FLMovRcxRax[2] := $C1; //  ---+

  Inject.FLMovRaxCommand  := $B848;
  Inject.FLMovRaxArgument := Code + 95; // Code + смещение до адреса FreeLibrary

  Inject.FLMovRaxData[0] := $48; //  ---+
  Inject.FLMovRaxData[1] := $8B; //  ---+--->  mov RAX, [RAX]
  Inject.FLMovRaxData[2] := $00; //  ---+

  Inject.FLCallRax[0] := $48;
  Inject.FLCallRax[1] := $FF;
  Inject.FLCallRax[2] := $D0;

// ExitThread:
  Inject.ETMovRaxCommand  := $B848;
  Inject.ETMovRaxArgument := Code + 103; // Code + смещение до адреса ExitThread

  Inject.ETMovRaxData[0] := $48; //  ---+
  Inject.ETMovRaxData[1] := $8B; //  ---+--->  mov RAX, [RAX]
  Inject.ETMovRaxData[2] := $00; //  ---+

  Inject.ETMovRcxCommand  := $B948;
  Inject.ETMovRcxArgument := $0000000000000000; // ExitCode = 0

  Inject.ETCallRax[0] := $48;
  Inject.ETCallRax[1] := $FF;
  Inject.ETCallRax[2] := $D0;

// Выравниваем 64х-битный стек:
  Inject.AlignStackAtEnd := $90C3C35D20658D48;


// Записываем адреса библиотек:
  hKernel32 := LoadLibrary('kernel32.dll');
  Inject.AddrGetModuleHandle := UInt64(GetProcAddress(hKernel32, 'GetModuleHandleA'));
  Inject.AddrFreeLibrary := UInt64(GetProcAddress(hKernel32, 'FreeLibrary'));
  Inject.AddrExitThread  := UInt64(GetProcAddress(hKernel32, 'ExitThread'));

  Move(ModuleName^, Inject.LibraryName, Length(ModuleName));

//  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -

  // Записываем машинный код в выделенную память:
  if NtWriteVirtualMemory(ProcessHandle, Memory, @Inject, SizeOf(Inject), BytesWritten) <> 0 then
  begin
    VirtualFreeEx(ProcessHandle, Memory, 0, MEM_RELEASE);
    CloseHandle(ProcessHandle);
    Exit;
  end;

  // Выполняем машинный код в отдельном потоке:
  hThread := CreateRemoteThread(ProcessHandle, nil, 0, Memory, nil, 0, ThreadId);

  if hThread = 0 then
  begin
    VirtualFreeEx(ProcessHandle, Memory, 0, MEM_RELEASE);
    CloseHandle(ProcessHandle);
    Exit;
  end;

  WaitForSingleObject(hThread, INFINITE);

  VirtualFreeEx(ProcessHandle, Memory, 0, MEM_RELEASE);
  CloseHandle(hThread);
  CloseHandle(ProcessHandle);

  Result := True;
end;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

// Инъекция кода напрямую из программы:
procedure InjectFunction(ProcessID: LongWord; InjectedFunction: Pointer; InjectedFunctionSize: NativeUInt; Arguments: Pointer; ArgumentsSize: NativeUInt; Wait: Boolean = FALSE);
var
  hProcess                : NativeUInt;
  RemoteThreadBaseAddress : Pointer;
  ArgumentsBaseAddress    : Pointer;
  BytesWritten            : NativeUInt;
  RemoteThreadHandle      : NativeUInt;
  RemoteThreadID          : LongWord;
  Status                  : LongWord;
begin
  if (InjectedFunction = nil) or (InjectedFunctionSize = 0) then Exit;

  hProcess := OpenProcess(AccessRights, FALSE, ProcessID);
  if hProcess = 0 then Exit;

  // Выделяем память в процессе:
  RemoteThreadBaseAddress := VirtualAllocEx(hProcess, nil, InjectedFunctionSize, MEM_COMMIT + MEM_RESERVE, PAGE_EXECUTE_READWRITE);

  if RemoteThreadBaseAddress = nil then
  begin
    CloseHandle(hProcess);
    Exit;
  end;

  // Выделяем память под аргументы:
  ArgumentsBaseAddress := nil;
  if (Arguments <> nil) and (ArgumentsSize <> 0) then
  begin
    ArgumentsBaseAddress := VirtualAllocEx(hProcess, nil, ArgumentsSize, MEM_COMMIT + MEM_RESERVE, PAGE_EXECUTE_READWRITE);
    if ArgumentsBaseAddress = nil then
    begin
      VirtualFreeEx(hProcess, RemoteThreadBaseAddress, InjectedFunctionSize, MEM_RELEASE);
      CloseHandle(hProcess);
      Exit;
    end;
  end;

  // Пишем в память наш код:
  Status := NtWriteVirtualMemory(hProcess, RemoteThreadBaseAddress, InjectedFunction, InjectedFunctionSize, BytesWritten);
  if (Status <> 0) and (InjectedFunctionSize <> BytesWritten) then
  begin
    VirtualFreeEx(hProcess, RemoteThreadBaseAddress, InjectedFunctionSize, MEM_RELEASE);
    VirtualFreeEx(hProcess, ArgumentsBaseAddress, ArgumentsSize, MEM_RELEASE);
    CloseHandle(hProcess);
    Exit;
  end;

  RemoteThreadHandle := CreateRemoteThread(hProcess, nil, 0, RemoteThreadBaseAddress, ArgumentsBaseAddress, 0, RemoteThreadID);

  if Wait then WaitForSingleObject(RemoteThreadHandle, INFINITE);

  VirtualFreeEx(hProcess, RemoteThreadBaseAddress, InjectedFunctionSize, MEM_RELEASE);
  VirtualFreeEx(hProcess, ArgumentsBaseAddress, ArgumentsSize, MEM_RELEASE);
  CloseHandle(RemoteThreadHandle);
  CloseHandle(hProcess);
end;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

// Внедрение образа целиком (ExeImage - указатель на эксешник в памяти текущего процесса):
procedure InjectExeImage(ProcessID: LongWord; ExeImage: Pointer; Wait: Boolean = FALSE);
type
  PImageOptionalHeader = {$IFDEF CPUX64}PImageOptionalHeader64{$ELSE}PImageOptionalHeader32{$ENDIF};
var
  hProcess: THandle;
  OptionalHeader: PImageOptionalHeader;
  Size: LongWord;
  Module: Pointer;
  EntryPoint: Pointer;
  InjectedModule: Pointer;
  hThread: THandle;
  BytesWritten: NativeUInt;
begin
  hProcess := OpenProcess(AccessRights, FALSE, ProcessID);

  OptionalHeader := PImageOptionalHeader(
                                          NativeInt(ExeImage) +
                                          PImageDosHeader(ExeImage)._lfanew +
                                          SizeOf(LongWord) +
                                          SizeOf(TImageFileHeader)
                                         );

  Size := OptionalHeader^.SizeOfImage;
  Module := Pointer(OptionalHeader^.ImageBase);
  EntryPoint := Pointer(OptionalHeader^.ImageBase + OptionalHeader^.AddressOfEntryPoint);

  InjectedModule := VirtualAllocEx(hProcess, Module, Size, MEM_COMMIT + MEM_RESERVE, PAGE_EXECUTE_READWRITE);
  if InjectedModule = nil then
  begin
    CloseHandle(hProcess);
    Exit;
  end;

  NtWriteVirtualMemory(hProcess, InjectedModule, Module, Size, BytesWritten);
  hThread := CreateRemoteThread(hProcess, nil, 0, EntryPoint, InjectedModule, 0, PCardinal(0)^);

  if Wait then WaitForSingleObject(hThread, INFINITE);

  CloseHandle(hThread);
  CloseHandle(hProcess);
end;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

// Внедрение своего образа (EntryPoint - точка входа):
procedure InjectSelfExeImage(ProcessID: LongWord; EntryPoint: Pointer; Wait: Boolean = FALSE);
type
  PImageOptionalHeader = {$IFDEF CPUX64}PImageOptionalHeader64{$ELSE}PImageOptionalHeader32{$ENDIF};
var
  hProcess: THandle;
  SelfModule: Pointer;
  InjectedModule: Pointer;
  Size: LongWord;
  hThread  : LongWord;
  BytesWritten: NativeUInt;
begin
  hProcess := OpenProcess(AccessRights, FALSE, ProcessID);

  SelfModule := Pointer(GetModuleHandle(nil));
  Size := PImageOptionalHeader(
                                NativeInt(SelfModule) +
                                PImageDosHeader(SelfModule)._lfanew +
                                SizeOf(LongWord) +
                                SizeOf(TImageFileHeader)
                               ).SizeOfImage;

  InjectedModule := VirtualAllocEx(hProcess, SelfModule, Size, MEM_COMMIT + MEM_RESERVE, PAGE_EXECUTE_READWRITE);
  if InjectedModule = nil then
  begin
    CloseHandle(hProcess);
    Exit;
  end;

  NtWriteVirtualMemory(hProcess, InjectedModule, SelfModule, Size, BytesWritten);
  hThread := CreateRemoteThread(hProcess, nil, 0, EntryPoint, InjectedModule, 0, PCardinal(0)^);

  if Wait then WaitForSingleObject(hThread, INFINITE);

  CloseHandle(hThread);
  CloseHandle(hProcess);
end;





//HHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHH
//
//                      #######    ####      ####
//                       ##   ##    ##        ##
//                       ##   ##    ##        ##
//                       ##   ##    ##   #    ##   #
//                      #######    #######   #######
//
//HHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHH



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

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

// Запустить все потоки процесса, кроме текущего:
procedure RunThreads;
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
          ResumeThread(ThreadHandle);
          CloseHandle(ThreadHandle);
        end;
      end;
    until not Thread32Next(TlHelpHandle, ThreadEntry32);

    CloseHandle(TlHelpHandle);
  end;
end;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

// Исправляем контекст потоков, если EIP/RIP на момент хука попал внутрь перезаписываемого блока:
procedure FixupContext(OriginalAddress, NewAddress: Pointer; Size: Byte);
  procedure FixupThreadContext(ThreadID: LongWord);
  var
    hThread: THandle;
    Context: TContext;
    CurrentAddress: NativeUInt;
    Offset: NativeUInt;
  begin
    hThread := OpenThread(THREAD_GET_CONTEXT or THREAD_SET_CONTEXT or THREAD_QUERY_INFORMATION or THREAD_SET_INFORMATION, FALSE, ThreadID);
    if (hThread = INVALID_HANDLE_VALUE) or (hThread = 0) then Exit;

    FillChar(Context, SizeOf(Context), #0);
    Context.ContextFlags := CONTEXT_FULL;
    if GetThreadContext(hThread, Context) then
    begin
      CurrentAddress := {$IFDEF CPUX64}Context.Rip{$ELSE}Context.Eip{$ENDIF};
      if (CurrentAddress >= NativeUInt(OriginalAddress)) and (CurrentAddress < (NativeUInt(OriginalAddress) + Size)) then
      begin
        OutputDebugString('### [HookAPI]: Switching context!');
        Offset := CurrentAddress - NativeUInt(OriginalAddress);
        {$IFDEF CPUX64}Context.Rip{$ELSE}Context.Eip{$ENDIF} := NativeUInt(NewAddress) + Offset;
        SetThreadContext(hThread, Context);
      end;
    end;
    CloseHandle(hThread);
  end;
var
  hSnapshot: THandle;
  ThreadInfo: TThreadEntry32;
  CurrentThreadID  : LongWord;
  CurrentProcessID : LongWord;
begin
  StopThreads;

  CurrentThreadID  := GetCurrentThreadID;
  CurrentProcessID := GetCurrentProcessID;

  ThreadInfo.dwSize := SizeOf(ThreadInfo);
  hSnapshot := CreateToolHelp32Snapshot(TH32CS_SNAPTHREAD, 0);
  if Thread32First(hSnapshot, ThreadInfo) then
  begin
    if (ThreadInfo.th32ThreadID <> CurrentThreadID) and (ThreadInfo.th32OwnerProcessID = CurrentProcessID) then
      FixupThreadContext(ThreadInfo.th32ThreadID);

    while Thread32Next(hSnapshot, ThreadInfo) do
      if (ThreadInfo.th32ThreadID <> CurrentThreadID) and (ThreadInfo.th32OwnerProcessID = CurrentProcessID) then
        FixupThreadContext(ThreadInfo.th32ThreadID);
  end;
  CloseHandle(hSnapshot);

  FlushInstructionCache(GetCurrentProcess, nil, 0);
  RunThreads;
end;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

// Установка перехватчика:
function SetHook(var HookInfo: THookInfo; SuspendThreads: Boolean = True): Boolean;

  // Расчёт относительно адреса для прыжка в х32 ( E9 [ Относительный адрес ] )
  function GetRelativeJmp32Address(Source, Destination: Pointer): Pointer; inline;
  begin
    Result := Pointer(NativeInt(Destination) - NativeInt(Source) - 5);
  end;

  // Сдвиг указателя:
  function GetShiftedPointer(Base: Pointer; Offset: NativeInt): Pointer; inline;
  begin
    Result := Pointer(NativeInt(Base) + Offset);
  end;

var
  Instruction: TInstruction;
  RequiredBufferSize: Byte; // Размер буфера для помещения целого числа инструкций

  BufferSize: Byte;
  FarJump: TFarJump;
  {$IFDEF CPUX64}
  CodeSelectorJump: TCodeSelectorJump;
  {$ENDIF}
  OldProtect: Cardinal;
const
  ProtectSize = 64;
begin
  Result := False;
  if HookInfo.OriginalProcAddress = nil then Exit;

{$IFDEF CPUX64}
  // x64:
  { 48 B8 [8 байт адреса] FF E0 }
  FarJump.MovRaxOp  := $B848;                    //  --+
  FarJump.MovRaxArg := HookInfo.HookProcAddress; //  --+-->  mov RAX, HookProcAddress
  FarJump.JmpRaxOp  := $E0FF;                    //  ----->  jmp RAX
{$ELSE}
  // х32:
  { E9 [4 байта адреса относительно следующей инструкции] }
  FarJump.JmpOp  := $E9;                     //  --+
  FarJump.JmpArg := GetRelativeJmp32Address( //  --+-->  jmp dword HookProcAddress
                                             HookInfo.OriginalProcAddress,
                                             HookInfo.HookProcAddress
                                            );
{$ENDIF}

  if SuspendThreads then StopThreads;

  // Снимаем защиту на чтение/запись:
  VirtualProtect(HookInfo.OriginalProcAddress, ProtectSize, PAGE_EXECUTE_READWRITE, @OldProtect);

  // Рассчитываем необходимый размер буфера:
  RequiredBufferSize := 0;
  while RequiredBufferSize < SizeOf(TFarJump) do
  begin
    Inc(
         RequiredBufferSize,
         LDasm(
                Pointer(NativeUInt(HookInfo.OriginalProcAddress) + RequiredBufferSize),
                {$IFDEF CPUX64}True{$ELSE}False{$ENDIF},
                Instruction
               )
        );
  end;

  // Выделяем память под оригинальное начало функции с прыжком на продолжение:
  {$IFDEF CPUX64}
    BufferSize := RequiredBufferSize + SizeOf(TCodeSelectorJump);
  {$ELSE}
    BufferSize := RequiredBufferSize + SizeOf(TFarJump);
  {$ENDIF}

  GetMem(HookInfo.OriginalBlock, BufferSize);
  HookInfo.OriginalCodeSize := RequiredBufferSize;
  HookInfo.OriginalBlockSize := BufferSize;
  FillChar(HookInfo.OriginalBlock^, BufferSize, #0);

  // Сохраняем целое число инструкций:
  Move(HookInfo.OriginalProcAddress^, HookInfo.OriginalBlock^, RequiredBufferSize);

  // Записываем прыжок на новую функцию:
  Move(FarJump, HookInfo.OriginalProcAddress^, SizeOf(TFarJump));

  // Восстанавливаем защиту на чтение/запись:
  VirtualProtect(HookInfo.OriginalProcAddress, ProtectSize, OldProtect, @OldProtect);

  // Записываем в конец оригинального блока прыжок на продолжение оригинальной функции:
  {$IFDEF CPUX64}
    CodeSelectorJump.JmpCsOp[0] := $25FF;
    CodeSelectorJump.JmpCsOp[1] := $0000;
    CodeSelectorJump.JmpCsOp[2] := $0000;
    CodeSelectorJump.JmpCsArg := GetShiftedPointer(HookInfo.OriginalProcAddress, RequiredBufferSize);
    Move(CodeSelectorJump, GetShiftedPointer(HookInfo.OriginalBlock, RequiredBufferSize)^, SizeOf(TCodeSelectorJump));
  {$ELSE}
    FarJump.JmpArg := GetRelativeJmp32Address(
                                               GetShiftedPointer(HookInfo.OriginalBlock, RequiredBufferSize),
                                               GetShiftedPointer(HookInfo.OriginalProcAddress, RequiredBufferSize)
                                              );

    Move(FarJump, GetShiftedPointer(HookInfo.OriginalBlock, RequiredBufferSize)^, SizeOf(TFarJump));
  {$ENDIF}

  // Назначаем оригинальному блоку права на исполнение:
  VirtualProtect(HookInfo.OriginalBlock, BufferSize, PAGE_EXECUTE_READWRITE, @OldProtect);

  // Исправляем контекст потоков, если EIP/RIP попал внутрь перезаписанного блока:
  FixupContext(HookInfo.OriginalProcAddress, HookInfo.OriginalBlock, RequiredBufferSize);

  if SuspendThreads then RunThreads;
  Result := True;
end;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

// Снятие перехвата:
function UnHook(var HookInfo: THookInfo; SuspendThreads: Boolean = True): Boolean;
var
  OldProtect: Cardinal;
  OriginalBlock: Pointer;
begin
  Result := False;
  if (HookInfo.OriginalProcAddress = nil) or (HookInfo.OriginalBlock = nil) then Exit;

  if SuspendThreads then StopThreads;

  VirtualProtect(HookInfo.OriginalProcAddress, HookInfo.OriginalBlockSize, PAGE_EXECUTE_READWRITE, @OldProtect);

  Move(HookInfo.OriginalBlock^, HookInfo.OriginalProcAddress^, HookInfo.OriginalCodeSize);
  Result := True;

  // Исправляем контекст потоков, если EIP/RIP попал внутрь оригинального блока:
  FixupContext(HookInfo.OriginalBlock, HookInfo.OriginalProcAddress, HookInfo.OriginalBlockSize);

  VirtualProtect(HookInfo.OriginalProcAddress, HookInfo.OriginalBlockSize, OldProtect, @OldProtect);

  OriginalBlock := HookInfo.OriginalBlock;
  HookInfo.OriginalBlock := HookInfo.OriginalProcAddress;
  HookInfo.OriginalCodeSize := 0;
  HookInfo.OriginalBlockSize := 0;

  FreeMem(OriginalBlock);

  if SuspendThreads then RunThreads;
end;


//HHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHH


procedure NotifyEmAll;
var
  hSnapshot: THandle;
  ThreadInfo: TThreadEntry32;
const
  WM_NULL = 0;
begin
  ThreadInfo.dwSize := SizeOf(ThreadInfo);
  hSnapshot := CreateToolHelp32Snapshot(TH32CS_SNAPTHREAD, 0);
  if Thread32First(hSnapshot, ThreadInfo) then
  begin
    PostThreadMessage(ThreadInfo.th32ThreadID, WM_NULL, 0, 0);
    while Thread32Next(hSnapshot, ThreadInfo) do
      PostThreadMessage(ThreadInfo.th32ThreadID, WM_NULL, 0, 0);
  end;
  CloseHandle(hSnapshot);
  PostMessage(HWND_BROADCAST, WM_NULL, 0, 0);
end;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

function MessageHandler(Code: Integer; wParam: Integer; lParam: Integer): Integer; stdcall;
begin
  Result := CallNextHookEx(0, Code, wParam, lParam);
end;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

function HookEmAll(out GlobalHookHandle: THandle): Boolean;
begin
  GlobalHookHandle := SetWindowsHookEx(WH_GETMESSAGE, @MessageHandler, hInstance, 0);
  NotifyEmAll;
  Result := GlobalHookHandle <> 0;
end;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

procedure UnHookEmAll(var GlobalHookHandle: THandle);
begin
  UnhookWindowsHookEx(GlobalHookHandle);
  NotifyEmAll;
  GlobalHookHandle := 0;
end;


//HHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHH
//                         Original Calls Helpers
//HHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHH

procedure InterlockedSet(FlagPtr: PBoolean); register;
asm
{$IFDEF CPUX64}
  mov al, $FF
  lock xchg byte [rcx], al
{$ELSE}
  mov cl, $FF
  lock xchg byte [eax], cl
{$ENDIF}
end;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

procedure InterlockedReset(FlagPtr: PBoolean); register;
asm
{$IFDEF CPUX64}
  xor al, al
  lock xchg byte [rcx], al
{$ELSE}
  xor cl, cl
  lock xchg byte [eax], cl
{$ENDIF}
end;

//HHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHH

{ TOriginalCall }

constructor TOriginalCall.Create;
begin
  InitializeCriticalSection(FCriticalSection);
  FOriginalCall := False;
end;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

destructor TOriginalCall.Destroy;
begin
  DeleteCriticalSection(FCriticalSection);
  inherited;
end;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

function TOriginalCall.GetState: Boolean;
begin
  EnterCriticalSection(FCriticalSection);
  Result := FOriginalCall;
  LeaveCriticalSection(FCriticalSection);
end;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

procedure TOriginalCall.SetState(Value: Boolean);
begin
  EnterCriticalSection(FCriticalSection);
  FOriginalCall := Value;
  LeaveCriticalSection(FCriticalSection);
end;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

procedure TOriginalCall.SetOriginalCall;
begin
  EnterCriticalSection(FCriticalSection);
  FOriginalCall := True;
end;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

procedure TOriginalCall.ResetOriginalCall;
begin
  FOriginalCall := False;
  LeaveCriticalSection(FCriticalSection);
end;

//HHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHH



end.
