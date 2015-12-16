unit MappingAPI;

interface

uses
  Windows;

function CreateFileMapping(MappingName: string; MappingSize: LongWord): THandle; overload;
function OpenFileMapping(MappingName: string): THandle; overload;

function GetMappedMemory(MappingName: string; Size: LongWord = 0): Pointer; overload;
function GetMappedMemory(MappingObject: THandle; Size: LongWord = 0): Pointer; overload;

procedure ReadMemory(SrcBaseAddress: Pointer; SrcOffset: LongWord; DestBaseAddress: Pointer; Size: LongWord);
procedure WriteMemory(SrcBaseAddress: Pointer; DestBaseAddress: Pointer; DestOffset: LongWord; Size: LongWord);

procedure FreeMappedMemory(MappedMemoryPointer: Pointer);
procedure CloseFileMapping(MappingObject: THandle);

implementation

//HHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHH

function CreateFileMapping(MappingName: string; MappingSize: LongWord): THandle; overload;
begin
  Result := Windows.CreateFileMapping(GetCurrentProcess, nil, PAGE_EXECUTE_READWRITE, 0, MappingSize, PChar(MappingName));
end;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

function OpenFileMapping(MappingName: string): THandle; overload;
begin
  Result := Windows.OpenFileMapping(FILE_MAP_ALL_ACCESS, FALSE, PChar(MappingName));
end;

//HHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHH

function GetMappedMemory(MappingName: string; Size: LongWord = 0): Pointer; overload;
var
  MappingObject: THandle;
begin
  MappingObject := OpenFileMapping(MappingName);

  if MappingObject = 0 then
  begin
    Result := nil;
    Exit;
  end;

  Result := MapViewOfFile(MappingObject, FILE_MAP_ALL_ACCESS, 0, 0, Size);
  CloseHandle(MappingObject);
end;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

function GetMappedMemory(MappingObject: THandle; Size: LongWord = 0): Pointer; overload;
begin
  Result := MapViewOfFile(MappingObject, FILE_MAP_ALL_ACCESS, 0, 0, Size);
end;

//HHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHH

procedure ReadMemory(SrcBaseAddress: Pointer; SrcOffset: LongWord; DestBaseAddress: Pointer; Size: LongWord);
begin
  Move((Pointer(NativeUInt(SrcBaseAddress) + SrcOffset))^, DestBaseAddress^, Size);
end;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

procedure WriteMemory(SrcBaseAddress: Pointer; DestBaseAddress: Pointer; DestOffset: LongWord; Size: LongWord);
begin
  Move((Pointer(NativeUInt(SrcBaseAddress) + DestOffset))^, DestBaseAddress^, Size);
end;

//HHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHH

procedure FreeMappedMemory(MappedMemoryPointer: Pointer);
begin
  UnmapViewOfFile(MappedMemoryPointer);
end;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

procedure CloseFileMapping(MappingObject: THandle);
begin
  CloseHandle(MappingObject);
end;

//HHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHH

end.