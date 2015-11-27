unit Ratibor;

interface

uses
  Windows, SysUtils, Classes, ShellAPI, MappingAPI;

type
  TRatibor = class
    public const
      RatiborLib32ResName: string = 'RATIBOR_LIB_32';
      RatiborLib64ResName: string = 'RATIBOR_LIB_64';

      RatiborInjector32ResName: string = 'RATIBOR_INJECTOR_32';
      RatiborInjector64ResName: string = 'RATIBOR_INJECTOR_64';

      RatiborLib32Name: string = 'RatiborLib32.dll';
      RatiborLib64Name: string = 'RatiborLib64.dll';

      RatiborInjector32Name: string = 'RatiborInjector32.exe';
      RatiborInjector64Name: string = 'RatiborInjector64.exe';

      RatiborMappingName: string = 'RatiborMapping';

      RatiborLibNativeName: string = {$IFDEF CPUX64}'RatiborLib64.dll'{$ELSE}'RatiborLib32.dll'{$ENDIF};
      RatiborInjectorNativeName: string = {$IFDEF CPUX64}'RatiborInjector64.exe'{$ELSE}'RatiborInjector32.exe'{$ENDIF};

    private
      FRatiborMapping: THandle;
      function GetRatiborMemory: Pointer;
      function Extract(const ResName, Destination: string): Boolean;
      function Run(const WorkingFolder, LaunchObject: string): Boolean;
    public
      constructor Create;
      destructor Destroy; override;

      function IsRatiborMappingExists: Boolean;

      function CreateRatiborMapping: Boolean;
      function OpenRatiborMapping: Boolean;
      function SetProtectedProcess(ProtectedProcessID: LongWord): Boolean;
      function GetProtectedProcess(out ProtectedProcessID: LongWord): Boolean;
      procedure CloseRatiborMapping;

      function Extract32(const DestinationFolder: string): Boolean;
      function Extract64(const DestinationFolder: string): Boolean;

      function Run32(const WorkingFolder: string): Boolean;
      function Run64(const WorkingFolder: string): Boolean;
  end;


implementation


{ TRatibor }

constructor TRatibor.Create;
begin
  FRatiborMapping := 0;
end;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

destructor TRatibor.Destroy;
begin
  CloseRatiborMapping;
  inherited;
end;

//HHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHH

function TRatibor.CreateRatiborMapping: Boolean;
begin
  if not OpenRatiborMapping then
    FRatiborMapping := CreateFileMapping(RatiborMappingName, SizeOf(LongWord));

  Result := FRatiborMapping <> 0;
end;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

function TRatibor.OpenRatiborMapping: Boolean;
begin
  if FRatiborMapping <> 0 then Exit(True);
  FRatiborMapping := OpenFileMapping(RatiborMappingName);
  Result := FRatiborMapping <> 0;
end;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

procedure TRatibor.CloseRatiborMapping;
begin
  if FRatiborMapping = 0 then Exit;
  CloseFileMapping(FRatiborMapping);
  FRatiborMapping := 0;
end;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

function TRatibor.GetRatiborMemory: Pointer;
begin
  if FRatiborMapping = 0 then Exit(nil);
  Result := GetMappedMemory(FRatiborMapping);
end;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

function TRatibor.SetProtectedProcess(ProtectedProcessID: LongWord): Boolean;
var
  MappedMemory: PLongWord;
begin
  MappedMemory := GetRatiborMemory;
  Result := MappedMemory <> nil;
  if Result then
  begin
    MappedMemory^ := ProtectedProcessID;
    FreeMappedMemory(MappedMemory);
  end;
end;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

function TRatibor.GetProtectedProcess(
  out ProtectedProcessID: LongWord): Boolean;
var
  MappedMemory: PLongWord;
begin
  MappedMemory := GetRatiborMemory;
  Result := MappedMemory <> nil;
  if Result then
  begin
    ProtectedProcessID := MappedMemory^;
    FreeMappedMemory(MappedMemory);
  end;
end;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

function TRatibor.IsRatiborMappingExists: Boolean;
var
  RatiborMapping: THandle;
begin
  RatiborMapping := OpenFileMapping(RatiborMappingName);
  Result := RatiborMapping <> 0;
  if Result then CloseFileMapping(RatiborMapping);
end;

//HHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHH

function TRatibor.Extract(const ResName, Destination: string): Boolean;
var
  ResourceStream: TResourceStream;
begin
  if FileExists(Destination) then
    if not DeleteFile(Destination) then Exit(False);

  try
    try
      ResourceStream := TResourceStream.Create(hInstance, ResName, RT_RCDATA);
      ResourceStream.SaveToFile(Destination);
      Result := True;
    except
      Result := False;
    end;
  finally
    if Assigned(ResourceStream) then FreeAndNil(ResourceStream);
  end;
end;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

function TRatibor.Extract32(const DestinationFolder: string): Boolean;
var
  LibStatus, InjectorStatus: Boolean;
begin
  LibStatus := Extract(RatiborLib32ResName, DestinationFolder + '\' + RatiborLib32Name);
  InjectorStatus := Extract(RatiborInjector32ResName, DestinationFolder + '\' + RatiborInjector32Name);
  Result := LibStatus and InjectorStatus;
end;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

function TRatibor.Extract64(const DestinationFolder: string): Boolean;
var
  LibStatus, InjectorStatus: Boolean;
begin
  LibStatus := Extract(RatiborLib64ResName, DestinationFolder + '\' + RatiborLib64Name);
  InjectorStatus := Extract(RatiborInjector64ResName, DestinationFolder + '\' + RatiborInjector64Name);
  Result := LibStatus and InjectorStatus;
end;

//HHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHH

function TRatibor.Run(const WorkingFolder, LaunchObject: string): Boolean;
var
  Path: string;
begin
  Path := WorkingFolder + '\' + LaunchObject;
  if not FileExists(Path) then Exit(False);
  ShellExecute(0, nil, PChar(Path), nil, PChar(WorkingFolder), SW_SHOWNORMAL);
  Result := True;
end;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

function TRatibor.Run32(const WorkingFolder: string): Boolean;
begin
  Result := Run(WorkingFolder, RatiborInjector32Name);
end;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

function TRatibor.Run64(const WorkingFolder: string): Boolean;
begin
  Result := Run(WorkingFolder, RatiborInjector64Name);
end;

end.
