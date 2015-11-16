unit UserInformation;

interface

uses
  Windows, SysUtils, Classes, System.JSON, Authorization,
  JSONUtils, FMX.Graphics, DownloadHelper;

type
  TFMXBitmap = FMX.Graphics.TBitmap;

  TUserLogonData = record
    Login       : string;
    AccessToken : string;
    UUID        : string;
  end;

  TUserInfo = class
    private
      FUserLogonData: TUserLogonData;
      FSkinBitmap, FCloakBitmap: TFMXBitmap;
    public
      property UserLogonData: TUserLogonData read FUserLogonData;
      property SkinBitmap: TFMXBitmap read FSkinBitmap;
      property CloakBitmap: TFMXBitmap read FCloakBitmap;

      constructor Create;
      destructor Destroy; override;

      function ExtractUserInfo(const AuthResponse: TAuthResponse): Boolean;
      procedure LoadInternalSkin;
      procedure LoadInternalCloak;
      procedure Clear;
  end;

implementation

{ TUserInfo }

constructor TUserInfo.Create;
begin
  FSkinBitmap := TFMXBitmap.Create;
  FCloakBitmap := TFMXBitmap.Create;
  Clear;
end;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

destructor TUserInfo.Destroy;
begin
  Clear;
  FreeAndNil(FSkinBitmap);
  FreeAndNil(FCloakBitmap);
  inherited;
end;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

function TUserInfo.ExtractUserInfo(const AuthResponse: TAuthResponse): Boolean;
var
  UserObject: TJSONObject;
  SkinAddress, CloakAddress: string;

  // Флажки окончания загрузки скина и плаща:
  DownloadEvents: packed record
    SkinEvent: THandle;
    CloakEvent: THandle;
  end;
begin
  if AuthResponse = nil then Exit(False);
  if not GetJSONObjectValue(AuthResponse, 'user_info', UserObject) then Exit(False);

  // Вытаскиваем информацию о пользователе:
  with FUserLogonData do
  begin
    Login       := GetJSONStringValue(UserObject, 'login');
    AccessToken := GetJSONStringValue(UserObject, 'access_token');
    UUID        := GetJSONStringValue(UserObject, 'uuid');
  end;

  // Создаём события ожидания загрузки:
  DownloadEvents.SkinEvent  := CreateEvent(nil, True, True, nil);
  DownloadEvents.CloakEvent := CreateEvent(nil, True, True, nil);

  // Загружаем скин:
  if GetJSONStringValue(UserObject, 'skin', SkinAddress) then
  begin
    ResetEvent(DownloadEvents.SkinEvent);
    TThread.CreateAnonymousThread(procedure()
    begin
      if not DownloadImage(SkinAddress, FSkinBitmap) then LoadInternalSkin;
      SetEvent(DownloadEvents.SkinEvent);
    end).Start;
  end
  else
  begin
    try
      LoadInternalSkin;
    except
      FSkinBitmap.Width  := 64;
      FSkinBitmap.Height := 32;
      FSkinBitmap.Clear($00000000);
    end;
  end;

  // Загружаем плащ:
  if GetJSONStringValue(UserObject, 'cloak', CloakAddress) then
  begin
    ResetEvent(DownloadEvents.CloakEvent);
    TThread.CreateAnonymousThread(procedure()
    begin
      if not DownloadImage(CloakAddress, FCloakBitmap) then LoadInternalCloak;
      SetEvent(DownloadEvents.CloakEvent);
    end).Start;
  end
  else
  begin
    try
      LoadInternalCloak;
    except
      FCloakBitmap.Width  := 64;
      FCloakBitmap.Height := 32;
      FCloakBitmap.Clear($00000000);
    end;
  end;

  // Ждём, пока все загрузятся:
  WaitForMultipleObjects(2, @DownloadEvents, TRUE, INFINITE);
  CloseHandle(DownloadEvents.SkinEvent);
  CloseHandle(DownloadEvents.CloakEvent);

  Result := True;
end;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

// Загрузка скина из ресурсов:
procedure TUserInfo.LoadInternalSkin;
var
  ResourceStream: TResourceStream;
begin
  try
    ResourceStream := TResourceStream.Create(hInstance, 'DEFAULT_SKIN', RT_RCDATA);
    FSkinBitmap.LoadFromStream(ResourceStream);
    FreeAndNil(ResourceStream);
  except
    FSkinBitmap.Width  := 64;
    FSkinBitmap.Height := 32;
    FSkinBitmap.Clear($00000000);
  end;
end;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

// Загрузка плаща из ресурсов:
procedure TUserInfo.LoadInternalCloak;
var
  ResourceStream: TResourceStream;
begin
  try
    ResourceStream := TResourceStream.Create(hInstance, 'DEFAULT_CLOAK', RT_RCDATA);
    FCloakBitmap.LoadFromStream(ResourceStream);
    FreeAndNil(ResourceStream);
  except
    FCloakBitmap.Width  := 64;
    FCloakBitmap.Height := 32;
    FCloakBitmap.Clear($00000000);
  end;
end;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

// Очистка информации о пользователе:
procedure TUserInfo.Clear;
begin
  with FUserLogonData do
  begin
    Login       := '';
    AccessToken := '';
    UUID        := '';
  end;

  FSkinBitmap.Clear($00000000);
  FCloakBitmap.Clear($00000000);
end;

end.
