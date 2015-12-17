unit SpliceProtection;

interface

implementation

uses
  Windows, HookAPI;

type
  NTSTATUS = LongWord;

const
  STATUS_SUCCESS = 0;
  MemoryBasicInformation: Integer = 0;

var
  VirtualProtectHookInfo: THookInfo;
  VirtualProtectExHookInfo: THookInfo;
  IsProtectionEnabled: Boolean = False;

function NtProtectVirtualMemory(
                                 hProcess       : THandle;
                                 BaseAddressPtr : Pointer;
                                 SizePtr        : Pointer;
                                 NewProtect     : Cardinal;
                                 OldProtect     : PCardinal
                                ): NTSTATUS; stdcall; external 'ntdll.dll';

function NtQueryVirtualMemory(
                               hProcess: THandle;
                               BaseAddress: Pointer;
                               MemoryInformationClass: Integer;
                               MemoryInformation: Pointer;
                               MemoryInformationLength: NativeUInt;
                               ReturnLength: PNativeUInt
                              ): NTSTATUS; stdcall; external 'ntdll.dll';


function NtProtectVirtualMemoryFilter(hProcess: THandle; BaseAddress: Pointer; Size: NativeUInt; NewProtect: Cardinal; OldProtect: PCardinal): NTSTATUS; stdcall;
  function IsProtectReadableExecutable(Protect: LongWord): Boolean; inline;
  begin
    Result := (Protect = PAGE_EXECUTE) or (Protect = PAGE_EXECUTE_READ);
  end;

  function IsProtectWriteable(Protect: LongWord): Boolean; inline;
  begin
    Result := (Protect = PAGE_READWRITE) or (Protect = PAGE_WRITECOPY) or (Protect = PAGE_EXECUTE_READWRITE) or (Protect = PAGE_EXECUTE_WRITECOPY);
  end;
var
  Status: NTSTATUS;
  ReturnLength: NativeUInt;
  MemoryInfo: MEMORY_BASIC_INFORMATION;
begin
  if IsProtectionEnabled then
  begin
    // Получаем информацию о регионе памяти:
    Status := NtQueryVirtualMemory(hProcess, BaseAddress, MemoryBasicInformation, @MemoryInfo, SizeOf(MEMORY_BASIC_INFORMATION), @ReturnLength);
    if Status = STATUS_SUCCESS then
    begin
      // Если там исполняемая память - не даём сменить атрибуты, выходим:
      if IsProtectReadableExecutable(MemoryInfo.Protect) and IsProtectWriteable(NewProtect) then
        Exit(STATUS_SUCCESS);
    end;
  end;

  // Если ни одно из этих условий - меняем атрибуты:
  Result := NtProtectVirtualMemory(hProcess, @BaseAddress, @Size, NewProtect, OldProtect);
end;



function HookedVirtualProtectEx(hProcess: THandle; BaseAddress: Pointer; Size: NativeUInt; NewProtect: Cardinal; OldProtect: PCardinal): BOOL; stdcall;
begin
  Result := NtProtectVirtualMemoryFilter(hProcess, BaseAddress, Size, NewProtect, OldProtect) = STATUS_SUCCESS;
end;

function HookedVirtualProtect(BaseAddress: Pointer; Size: NativeUInt; NewProtect: Cardinal; OldProtect: PCardinal): BOOL; stdcall;
begin
  Result := NtProtectVirtualMemoryFilter(GetCurrentProcess, BaseAddress, Size, NewProtect, OldProtect) = STATUS_SUCCESS;
end;



initialization
  VirtualProtectHookInfo.OriginalProcAddress := GetProcAddress(GetModuleHandle('kernel32.dll'), 'VirtualProtect');
  VirtualProtectHookInfo.HookProcAddress := @HookedVirtualProtect;
  VirtualProtectExHookInfo.OriginalProcAddress := GetProcAddress(GetModuleHandle('kernel32.dll'), 'VirtualProtectEx');
  VirtualProtectExHookInfo.HookProcAddress := @HookedVirtualProtectEx;

  StopThreads;
  SetHook(VirtualProtectHookInfo, FALSE);
  SetHook(VirtualProtectExHookInfo, FALSE);
  RunThreads;

  IsProtectionEnabled := True;

finalization
  IsProtectionEnabled := False;
  UnHook(VirtualProtectExHookInfo);

end.
