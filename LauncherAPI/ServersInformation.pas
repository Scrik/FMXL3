unit ServersInformation;

interface

uses
  System.SysUtils, System.JSON, JSONUtils, MinecraftLauncher, System.Threading;

type
  TClientsArray = array of TMinecraftLauncher;
  TClients = class
    private
      FClients: TClientsArray;
      FClientsCount: Integer;
    public
      property Count: Integer read FClientsCount;
      property ClientsArray: TClientsArray read FClients;

      constructor Create;
      destructor Destroy; override;

      function ExtractServersInfo(const ServersInfo: TJSONObject; const HostBaseFolder: string): Boolean;
      procedure Clear;
  end;

implementation

{ TClients }

constructor TClients.Create;
begin
  Clear;
end;

destructor TClients.Destroy;
begin
  Clear;
  inherited;
end;

function TClients.ExtractServersInfo(const ServersInfo: TJSONObject;
  const HostBaseFolder: string): Boolean;
var
  ClientsArray: TJSONArray;
begin
  Clear;

  if ServersInfo = nil then Exit(False);

  // Получаем из джейсона массив клиентов:
  if not GetJSONArrayValue(ServersInfo, 'servers', ClientsArray) then Exit(False);

  FClientsCount := ClientsArray.Count;
  if FClientsCount = 0 then Exit(False);

  // Получаем информацию обо всех клиентах:
  SetLength(FClients, FClientsCount);
  TParallel.&For(0, FClientsCount - 1, procedure(I: Integer)
  begin
    FClients[I] := TMinecraftLauncher.Create;
    FClients[I].ExtractClientInfo(GetJSONArrayElement(ClientsArray, I), HostBaseFolder);
  end);

  Result := True;
end;

procedure TClients.Clear;
var
  I: Integer;
begin
  if FClientsCount > 0 then
    for I := 0 to FClientsCount - 1 do
      if Assigned(FClients[I]) then FreeAndNil(FClients[I]);
  FClientsCount := 0;
  SetLength(FClients, FClientsCount);
end;

end.
