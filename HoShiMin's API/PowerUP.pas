unit PowerUP;

interface

uses
  Windows, Classes;

function SetPowerValue(MinPowerValue, MaxPowerValue: Byte; out OldMinThrottle, OldMaxThrottle: Byte): Boolean;
function SetPowerPercentage(PowerPercentage: Byte): Boolean;
function SetMaximumPower: Boolean;
function GetCPUFrequency: ULONG;

type
  NTSTATUS = LongWord;
  POWER_INFORMATION_LEVEL = Integer;

  BATTERY_REPORTING_SCALE = record
    Granularity: ULONG;
    Capacity: ULONG;
  end;

  SYSTEM_POWER_STATE = (
    PowerSystemUnspecified  = 0,
    PowerSystemWorking      = 1,
    PowerSystemSleeping1    = 2,
    PowerSystemSleeping2    = 3,
    PowerSystemSleeping3    = 4,
    PowerSystemHibernate    = 5,
    PowerSystemShutdown     = 6,
    PowerSystemMaximum      = 7
  );

  SYSTEM_POWER_CAPABILITIES = packed record
    PowerButtonPresent: Boolean;
    SleepButtonPresent: Boolean;
    LidPresent: Boolean;
    SystemS1: Boolean;
    SystemS2: Boolean;
    SystemS3: Boolean;
    SystemS4: Boolean;
    SystemS5: Boolean;
    HiberFilePresent: Boolean;
    FullWake: Boolean;
    VideoDimPresent: Boolean;
    ApmPresent: Boolean;
    UpsPresent: Boolean;
    ThermalControl: Boolean;
    ProcessorThrottle: Boolean;
    ProcessorMinThrottle: Byte;
    ProcessorMaxThrottle: Byte;
    FastSystemS4: Boolean;
    HiberBoot: Boolean;
    WakeAlarmPresent: Boolean;
    AoAc: Boolean;
    DiskSpinDown: Boolean;
    spare3: array [0..7] of Byte;
    SystemBatteriesPresent: Boolean;
    BatteriesAreShortTerm: Boolean;
    BatteryScale: array [0..2] of BATTERY_REPORTING_SCALE;
    AcOnLineWake: SYSTEM_POWER_STATE;
    SoftLidWake: SYSTEM_POWER_STATE;
    RtcWake: SYSTEM_POWER_STATE;
    MinDeviceWakeState: SYSTEM_POWER_STATE;
    DefaultLowLatencyWake: SYSTEM_POWER_STATE;
  end;

  PROCESSOR_POWER_INFORMATION = record
    Number: ULONG;
    MaxMhz: ULONG;
    CurrentMhz: ULONG;
    MhzLimit: ULONG;
    MaxIdleState: ULONG;
    CurrentIdleState: ULONG;
  end;

const
  // Information Levels:
  ProcessorInformation = 11;
  SystemPowerCapabilities = 4;

  STATUS_SUCCESS = 0;

function CallNtPowerInformation(
                                 InformationLevel: POWER_INFORMATION_LEVEL;
                                 InputBuffer: Pointer;
                                 InputBufferSize: ULONG;
                                 OutputBuffer: Pointer;
                                 OutputBufferSize: ULONG
                                ): NTSTATUS; stdcall; external 'PowrProf.dll';


implementation

function SetPowerValue(MinPowerValue, MaxPowerValue: Byte; out OldMinThrottle, OldMaxThrottle: Byte): Boolean;
var
  Buffer: Pointer;
  PowerCapabilities: ^SYSTEM_POWER_CAPABILITIES;
  Status: NTSTATUS;
const
  BufferSize = 1024;
begin
  GetMem(Buffer, BufferSize);
  PowerCapabilities := Buffer;

  Status := CallNtPowerInformation(SystemPowerCapabilities, nil, 0, Buffer, BufferSize);
  Result := (Status = STATUS_SUCCESS) and PowerCapabilities.ProcessorThrottle;
  if not Result then Exit;

  OldMinThrottle := PowerCapabilities.ProcessorMinThrottle;
  OldMaxThrottle := PowerCapabilities.ProcessorMaxThrottle;

  PowerCapabilities.ProcessorMinThrottle := MinPowerValue;
  PowerCapabilities.ProcessorMaxThrottle := MaxPowerValue;

  Status := CallNtPowerInformation(SystemPowerCapabilities, @PowerCapabilities, SizeOf(PowerCapabilities), @PowerCapabilities, SizeOf(PowerCapabilities));
  Result := Status = STATUS_SUCCESS;

  FreeMem(Buffer);
end;

function SetMaximumPower: Boolean;
var
  OldMinThrottle, OldMaxThrottle: Byte;
begin
  Result := SetPowerValue($FF, $FF, OldMinThrottle, OldMaxThrottle);
end;

function SetPowerPercentage(PowerPercentage: Byte): Boolean;
var
  Value: Integer;
  OldMinThrottle, OldMaxThrottle: Byte;
begin
  Value := Round(($FF * PowerPercentage) / 100);
  if Value > $FF then Value := $FF;

  Result := SetPowerValue(Byte(Value), Byte(Value), OldMinThrottle, OldMaxThrottle);
end;

function GetCPUFrequency: ULONG;
var
  ProcessorPowerInformation: array of PROCESSOR_POWER_INFORMATION;
  Status: NTSTATUS;
  I: Integer;
begin
  SetLength(ProcessorPowerInformation, TThread.ProcessorCount);
  Status := CallNtPowerInformation(ProcessorInformation, nil, 0, @ProcessorPowerInformation[0], TThread.ProcessorCount * SizeOf(PROCESSOR_POWER_INFORMATION));
  if Status <> 0 then
  begin
    SetLength(ProcessorPowerInformation, 0);
    Exit(0);
  end;

  // Усредняем:
  Result := 0;
  for I := 0 to TThread.ProcessorCount - 1 do
    Result := Result + ProcessorPowerInformation[I].CurrentMhz;
  Result := Result div ULONG(TThread.ProcessorCount);
end;

end.
