unit LauncherInformation;

interface

uses
  Windows, SysUtils, System.JSON, JSONUtils, Authorization, cHash, FileAPI,
  AuxUtils, HTTPUtils, CodepageAPI;

type
  TValidLauncherInfo = record
    ValidVersion: Integer;
    Hash: string;
    Link: string;
  end;

  TLauncherInfo = class
    private
      FValidLauncherInfo: TValidLauncherInfo;
      FVersion: Integer;
      FHash: string;

      procedure CalculateHash;
    public
      property ValidLauncherInfo: TValidLauncherInfo read FValidLauncherInfo;
      property LauncherVersion: Integer read FVersion write FVersion;
      property LauncherHash: string read FHash;

      constructor Create;
      destructor Destroy; override;

      function IsLauncherValid(ValidateByHash: Boolean = False): Boolean;
      function UpdateLauncher: Boolean;

      function ExtractLauncherInfo(const AuthResponse: TAuthResponse): Boolean;
      procedure Clear;
  end;

implementation

{ TLauncherInfo }


constructor TLauncherInfo.Create;
begin
  Clear;
  CalculateHash;
  FVersion := 0;
end;

destructor TLauncherInfo.Destroy;
begin
  Clear;
  inherited;
end;


procedure TLauncherInfo.CalculateHash;
var
  FilePtr: Pointer;
  FileSize: Integer;
begin
  FilePtr := LoadFileToMemory(ParamStr(0), FileSize);
  FHash := AnsiToWide(MD5DigestToHex(CalcMD5(FilePtr^, FileSize)));
  FreeMem(FilePtr);
end;


function TLauncherInfo.IsLauncherValid(ValidateByHash: Boolean = False): Boolean;
begin
  if ValidateByHash then
    Result := LowerCase(FValidLauncherInfo.Hash) = LowerCase(FHash)
  else
    Result := FValidLauncherInfo.ValidVersion = FVersion;
end;


function TLauncherInfo.UpdateLauncher: Boolean;
var
  HTTPSender: THTTPSender;
  LauncherPath: string;
  ProcessHandle: THandle;
  ProcessID: LongWord;
const
  PESignature: LongWord = $00505A4D;
begin
  Result := False;

  if Length(FValidLauncherInfo.Link) = 0 then Exit;

  LauncherPath := ParamStr(0);

  HTTPSender := THTTPSender.Create;
  HTTPSender.GET(FValidLauncherInfo.Link);
  if HTTPSender.Status then
  begin
    if HTTPSender.HTTPSend.Document.Size >= SizeOf(PESignature) then
    begin
      if LongWord(HTTPSender.HTTPSend.Document.Memory^) = PESignature then
      begin
        RenameFile(LauncherPath, LauncherPath + '.old');
        HTTPSender.HTTPSend.Document.SaveToFile(LauncherPath);
        FreeAndNil(HTTPSender);

        StartProcess(LauncherPath, ProcessHandle, ProcessID);
        CloseHandle(ProcessHandle);
        Result := True;
        ExitProcess(0);
      end;
    end;
  end;

  FreeAndNil(HTTPSender);
end;

function TLauncherInfo.ExtractLauncherInfo(
  const AuthResponse: TAuthResponse): Boolean;
var
  LauncherInfoJSON: TJSONObject;
begin
  LauncherInfoJSON := GetJSONObjectValue(AuthResponse, 'launcher_info');
  if LauncherInfoJSON = nil then Exit(False);

  FValidLauncherInfo.ValidVersion := GetJSONIntValue(LauncherInfoJSON, 'version');

  {$IFDEF CPUX64}
    FValidLauncherInfo.Hash := GetJSONStringValue(LauncherInfoJSON, 'hash64');
    FValidLauncherInfo.Link := GetJSONStringValue(LauncherInfoJSON, 'link64');
  {$ELSE}
    if Is64BitWindows then
    begin
      FValidLauncherInfo.Hash := GetJSONStringValue(LauncherInfoJSON, 'hash64');
      FValidLauncherInfo.Link := GetJSONStringValue(LauncherInfoJSON, 'link64');
    end
    else
    begin
      FValidLauncherInfo.Hash := GetJSONStringValue(LauncherInfoJSON, 'hash32');
      FValidLauncherInfo.Link := GetJSONStringValue(LauncherInfoJSON, 'link32');
    end;
  {$ENDIF}

  Result := True;
end;


procedure TLauncherInfo.Clear;
begin
  FValidLauncherInfo.ValidVersion := 0;
  FValidLauncherInfo.Hash := '';
  FValidLauncherInfo.Link := '';
end;

end.
