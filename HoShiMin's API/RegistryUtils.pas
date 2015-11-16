unit RegistryUtils;

interface

uses
  Windows, SysUtils, Registry;

function GetCurrentJavaInfo(out JavaHome, RuntimeLib, CurrentVersion: string): Boolean;

// Запись параметров:
procedure SaveStringToRegistry (const Path, Name, Value: string         ; Access: LongWord = KEY_WRITE);
procedure SaveBooleanToRegistry(const Path, Name: string; Value: Boolean; Access: LongWord = KEY_WRITE);
procedure SaveNumberToRegistry (const Path, Name: string; Value: Integer; Access: LongWord = KEY_WRITE);

// Чтение параметров:
function ReadStringFromRegistry (const Path, Name: string; DefaultValue: string  = ''   ; Access: LongWord = KEY_READ): string;
function ReadBooleanFromRegistry(const Path, Name: string; DefaultValue: Boolean = False; Access: LongWord = KEY_READ): Boolean;
function ReadNumberFromRegistry (const Path, Name: string; DefaultValue: Integer = 0    ; Access: LongWord = KEY_READ): Integer;

implementation

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

function GetCurrentJavaInfo(out JavaHome, RuntimeLib, CurrentVersion: string): Boolean;
var
  Reg: TRegistry;
begin
  Reg := TRegistry.Create;
  Reg.Access := {KEY_WOW64_64KEY or} KEY_READ;
  Reg.RootKey := HKEY_LOCAL_MACHINE;

  Result := False;

  if Reg.OpenKey('SOFTWARE\JavaSoft\Java Runtime Environment', False) then
  begin
    CurrentVersion := Reg.ReadString('CurrentVersion');
    if CurrentVersion <> '' then
    begin
      Reg.CloseKey;

      if Reg.OpenKey('SOFTWARE\JavaSoft\Java Runtime Environment\' + CurrentVersion, false) then
      begin
        JavaHome   := Reg.ReadString('JavaHome');
        RuntimeLib := Reg.ReadString('RuntimeLib');
        Result := True;
      end;
    end;
  end;

  Reg.CloseKey;
  Reg.Free;
end;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

procedure SaveStringToRegistry(const Path, Name, Value: string; Access: LongWord = KEY_WRITE);
var
  Reg: TRegistry;
begin
  Reg := TRegistry.Create;
  Reg.Access := Access;
  Reg.RootKey := HKEY_CURRENT_USER;

  if Reg.OpenKey('SOFTWARE\' + Path, True) then
  begin
    Reg.WriteString(Name, Value);
  end;

  Reg.CloseKey;
  Reg.Free;
end;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

procedure SaveBooleanToRegistry(const Path, Name: string; Value: Boolean; Access: LongWord = KEY_WRITE);
var
  Reg: TRegistry;
begin
  Reg := TRegistry.Create;
  Reg.Access := Access;
  Reg.RootKey := HKEY_CURRENT_USER;

  if Reg.OpenKey('SOFTWARE\' + Path, True) then
  begin
    if Value then
      Reg.WriteString(Name, 'true')
    else
      Reg.WriteString(Name, 'false');
  end;

  Reg.CloseKey;
  Reg.Free;
end;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

procedure SaveNumberToRegistry(const Path, Name: string; Value: Integer; Access: LongWord = KEY_WRITE);
var
  Reg: TRegistry;
begin
  Reg := TRegistry.Create;
  Reg.Access := Access;
  Reg.RootKey := HKEY_CURRENT_USER;

  if Reg.OpenKey('SOFTWARE\' + Path, True) then
  begin
    Reg.WriteString(Name, IntToStr(Value));
  end;

  Reg.CloseKey;
  Reg.Free;
end;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

function ReadStringFromRegistry(const Path, Name: string; DefaultValue: string = ''; Access: LongWord = KEY_READ): string;
var
  Reg: TRegistry;
begin
  Reg := TRegistry.Create;
  Reg.Access := Access;
  Reg.RootKey := HKEY_CURRENT_USER;

  Result := DefaultValue;

  if Reg.OpenKey('SOFTWARE\' + Path, False) then
  begin
    Result := Reg.ReadString(Name);
    if (Result = '') and (DefaultValue <> '') then Result := DefaultValue;
  end;

  Reg.CloseKey;
  Reg.Free;
end;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

function ReadBooleanFromRegistry(const Path, Name: string; DefaultValue: Boolean = False; Access: LongWord = KEY_READ): Boolean;
var
  Reg: TRegistry;
  ValueStr: string;
begin
  Reg := TRegistry.Create;
  Reg.Access := Access;
  Reg.RootKey := HKEY_CURRENT_USER;

  Result := DefaultValue;

  if Reg.OpenKey('SOFTWARE\' + Path, False) then
  begin
    ValueStr := Reg.ReadString(Name);
    if ValueStr = 'true' then
      Result := True
    else
      if ValueStr = 'false' then
        Result := False
      else
        Result := DefaultValue;
  end;

  Reg.CloseKey;
  Reg.Free;
end;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

function ReadNumberFromRegistry(const Path, Name: string; DefaultValue: Integer = 0; Access: LongWord = KEY_READ): Integer;
var
  Reg: TRegistry;
  ValueStr: string;
  Code: LongWord;
begin
  Reg := TRegistry.Create;
  Reg.Access := Access;
  Reg.RootKey := HKEY_CURRENT_USER;

  Result := DefaultValue;

  if Reg.OpenKey('SOFTWARE\' + Path, False) then
  begin
    ValueStr := Reg.ReadString(Name);
    if ValueStr <> '' then Val(ValueStr, Result, Code);
  end;

  Reg.CloseKey;
  Reg.Free;
end;

end.
