unit HWID;

interface

function GetHWID: string;

implementation

uses
  Windows, SysUtils, CodepageAPI, StringsAPI;


function GetHDDSerialNumber(PhysicalDriveNumber: Integer; out HDDSerialNumber: string): Boolean;

  function ShiftPtr(Ptr: Pointer; Offset: NativeInt): Pointer; inline;
  begin
    Result := Pointer(NativeInt(Ptr) + Offset);
  end;

type
  STORAGE_PROPERTY_QUERY = record
    PropertyId: DWORD;
    QueryType: DWORD;
    AdditionalParameters: array [0..1] of WORD;
  end;

  STORAGE_DEVICE_DESCRIPTOR = record
    Version: ULONG;
    Size: ULONG;
    DeviceType: Byte;
    DeviceTypeModifier: Byte;
    RemovableMedia: Boolean;
    CommandQueueing: Boolean;
    VendorIdOffset: ULONG;         // 0x0C Vendor ID
    ProductIdOffset: ULONG;        // 0x10 Product ID
    ProductRevisionOffset: ULONG;  // 0x15 Revision
    SerialNumberOffset: ULONG;     // 0x18 Serial Number
    STORAGE_BUS_TYPE: DWORD;
    RawPropertiesLength: ULONG;
    RawDeviceProperties: array [0..2048] of Byte;
  end;

  PCharArray = ^TCharArray;
  TCharArray = array [0..32767] of AnsiChar;

const
  IOCTL_STORAGE_QUERY_PROPERTY = $2D1400;

var
  DriveHandle: THandle;
  PropQuery: STORAGE_PROPERTY_QUERY;
  DeviceDescriptor: STORAGE_DEVICE_DESCRIPTOR;
  Status: LongBool;
  Returned: LongWord;
begin
  Result := False;

  DriveHandle := CreateFile (
                              PChar('\\.\PhysicalDrive' + IntToStr(PhysicalDriveNumber)),
                              GENERIC_READ,
                              FILE_SHARE_READ,
                              nil,
                              OPEN_EXISTING,
                              0,
                              0
                             );

  if DriveHandle = INVALID_HANDLE_VALUE then Exit;

  ZeroMemory(@PropQuery, SizeOf(PropQuery));
  Status := DeviceIoControl(
                             DriveHandle,
                             IOCTL_STORAGE_QUERY_PROPERTY,
                             @PropQuery,
                             SizeOf(PropQuery),
                             @DeviceDescriptor,
                             SizeOf(DeviceDescriptor),
                             Returned,
                             nil
                            );

  CloseHandle(DriveHandle);

  if not Status then Exit;

  HDDSerialNumber := Trim(AnsiToWide(PAnsiChar(ShiftPtr(@DeviceDescriptor, DeviceDescriptor.SerialNumberOffset))));
  Result := True;
end;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

function GetHWID: string;
var
  PhysicalDriveNumber: Integer;
  HDDSerialNumber: string;
begin
  // Получаем номер системного HDD:
  GetHDDSerialNumber(0, Result);

  // Получаем остальные серийники:
  PhysicalDriveNumber := 1;
  while GetHDDSerialNumber(PhysicalDriveNumber, HDDSerialNumber) do
  begin
    if Length(Result) = 0 then HDDSerialNumber := 'UNKNOWN';
    Result := Result + ':' + HDDSerialNumber;
    Inc(PhysicalDriveNumber);
  end;

  if Length(Result) = 0 then Result := 'UNKNOWN';
end;

end.
