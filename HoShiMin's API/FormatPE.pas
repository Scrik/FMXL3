unit FormatPE;

interface

uses
  Windows, FileAPI, SysUtils;

type
  TMachineType = (mtUnknown, mt32Bit, mt64Bit, mtOther);
  TPEType      = (peExe, peDll, peSystem, peOther);

const
  PESignature = $00004550;
  OptionalPEHEaderOffset = $3C;

type
  TFileHeader = packed record
    Machine              : Word;
    NumberOfSections     : Word;
    TimeDateStamp        : LongWord;
    PointerToSymbolTable : LongWord;
    NumberOfSymbols      : LongWord;
    SizeOfOptionalHeader : Word;
    Characteristics      : Word;
  end;

  TNTHeader = packed record
    Signature: LongWord;
    FileHeader: TFileHeader;
  end;

// Получить NT-заголовок:
procedure GetNTHeader(const FileName: string; out NTHeader: TNTHeader);

// Получить тип PE-файла:
function GetPEType(const FileName: string): TPEType;

// Разрядность PE-файла:
function GetPEMachineType(const FileName: string): TMachineType;


implementation

procedure GetNTHeader(const FileName: string; out NTHeader: TNTHeader);
var
  hFile: THandle;
  PEOffset: Integer;
begin
  FillChar(NTHeader, SizeOf(NTHeader), #0);

  if not FileExists(FileName) then Exit;
  hFile := CreateFile(FileName, OPEN_EXISTING, GENERIC_READ, FILE_SHARE_READ, False);
  if hFile = INVALID_HANDLE_VALUE then Exit;

  ReadFromFile(hFile, @PEOffset, SizeOf(PEOffset), OptionalPEHEaderOffset, FROM_BEGIN);
  ReadFromFile(hFile, @NTHeader, SizeOf(NTHeader), PEOffset, FROM_BEGIN);

  CloseHandle(hFile);
end;

function GetPEType(const FileName: string): TPEType;
var
  NTHeader: TNTHeader;
const
  EXE = $0002;
  DLL = $2000;
  SYS = $1000;
begin
  GetNTHeader(FileName, NTHeader);
  if (NTHeader.FileHeader.Characteristics and EXE) = EXE then
    if (NTHeader.FileHeader.Characteristics and DLL) = DLL then
      Result := peDll
    else if (NTHeader.FileHeader.Characteristics and SYS) = SYS then
      Result := peSystem
    else
      Result := peOther
  else
    Result := peOther;
end;

function GetPEMachineType(const FileName: string): TMachineType;
var
  hFile: THandle;
  PEOffset: Integer;
  PEHead: LongWord;
  MachineType: Word;
begin
  Result := mtUnknown;

  if not FileExists(FileName) then Exit;
  hFile := CreateFile(FileName, OPEN_EXISTING, GENERIC_READ, FILE_SHARE_READ, False);
  if hFile = INVALID_HANDLE_VALUE then Exit;

  ReadFromFile(hFile, @PEOffset, SizeOf(PEOffset), OptionalPEHEaderOffset, FROM_BEGIN);
  ReadFromFile(hFile, @PEHead, SizeOf(PEHead), PEOffset, FROM_BEGIN);

  if PEHead <> PESignature then Exit;
  ReadFromFile(hFile, @MachineType, SizeOf(MachineType));

  case MachineType of
    $8664, // AMD64
    $0200: // IA-64
      Result := mt64Bit;
    $014C: // i386
      Result := mt32Bit;
  else
    Result := mtOther;
  end;

  CloseHandle(hFile);
end;

end.
