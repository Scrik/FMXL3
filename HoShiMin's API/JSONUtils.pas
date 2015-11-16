unit JSONUtils;

interface

uses
  SysUtils, System.JSON;

function JSONStringToJSONObject(const JSONString: string): TJSONObject;

function GetJSONStringValue (const JSONObject: TJSONObject; const ValueName: string): string;      overload;
function GetJSONObjectValue (const JSONObject: TJSONObject; const ValueName: string): TJSONObject; overload;
function GetJSONArrayValue  (const JSONObject: TJSONObject; const ValueName: string): TJSONArray;  overload;
function GetJSONIntValue    (const JSONObject: TJSONObject; const ValueName: string): Integer;     overload;
function GetJSONInt64Value  (const JSONObject: TJSONObject; const ValueName: string): Int64;       overload;
function GetJSONDoubleValue (const JSONObject: TJSONObject; const ValueName: string): Double;      overload;
function GetJSONBooleanValue(const JSONObject: TJSONObject; const ValueName: string): Boolean;     overload;

function GetJSONStringValue (const JSONObject: TJSONObject; const ValueName: string; out ResultValue: string)     : Boolean; overload;
function GetJSONObjectValue (const JSONObject: TJSONObject; const ValueName: string; out ResultValue: TJSONObject): Boolean; overload;
function GetJSONArrayValue  (const JSONObject: TJSONObject; const ValueName: string; out ResultValue: TJSONArray) : Boolean; overload;
function GetJSONIntValue    (const JSONObject: TJSONObject; const ValueName: string; out ResultValue: Integer)    : Boolean; overload;
function GetJSONInt64Value  (const JSONObject: TJSONObject; const ValueName: string; out ResultValue: Int64)      : Boolean; overload;
function GetJSONDoubleValue (const JSONObject: TJSONObject; const ValueName: string; out ResultValue: Double)     : Boolean; overload;
function GetJSONBooleanValue(const JSONObject: TJSONObject; const ValueName: string; out ResultValue: Boolean)    : Boolean; overload;

function IsJSONValueExists  (const JSONObject: TJSONObject; const ValueName: string): Boolean;
function GetJSONArrayElement(const JSONArray: TJSONArray; Index: Integer): TJSONObject;

implementation

function JSONStringToJSONObject(const JSONString: string): TJSONObject; overload;
var
  JSONValue: TJSONValue;
begin
  Result := nil;
  JSONValue := TJSONObject.Create.ParseJSONValue(JSONString);
  if JSONValue <> nil then
    if not JSONValue.Null then
      Result := JSONValue as TJSONObject
    else
      JSONValue.Free;
end;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

function GetJSONStringValue(const JSONObject: TJSONObject; const ValueName: string): string; overload;
var
  JSONValue: TJSONValue;
begin
  JSONValue := JSONObject.GetValue(ValueName);
  if JSONValue <> nil then
    if not JSONValue.Null then Result := JSONValue.Value else Result := '';
end;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

function GetJSONObjectValue(const JSONObject: TJSONObject; const ValueName: string): TJSONObject; overload;
var
  JSONValue: TJSONValue;
begin
  JSONValue := JSONObject.GetValue(ValueName);
  if JSONValue <> nil then
    if not JSONValue.Null then
      Result := JSONValue as TJSONObject else Result := nil
    else
      Result := nil;
end;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

function GetJSONArrayValue(const JSONObject: TJSONObject; const ValueName: string): TJSONArray; overload;
var
  JSONValue: TJSONValue;
begin
  JSONValue := JSONObject.GetValue(ValueName);
  if JSONValue <> nil then
    if not JSONValue.Null then
      Result := JSONValue as TJSONArray else Result := nil
    else
      Result := nil;
end;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

function GetJSONIntValue(const JSONObject: TJSONObject; const ValueName: string): Integer; overload;
var
  JSONValue: TJSONValue;
begin
  JSONValue := JSONObject.GetValue(ValueName);
  if JSONValue <> nil then
    if not JSONValue.Null then
      Result := (JSONValue as TJSONNumber).AsInt else Result := 0
    else
      Result := 0;
end;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

function GetJSONInt64Value(const JSONObject: TJSONObject; const ValueName: string): Int64; overload;
var
  JSONValue: TJSONValue;
begin
  JSONValue := JSONObject.GetValue(ValueName);
  if JSONValue <> nil then
    if not JSONValue.Null then
      Result := (JSONValue as TJSONNumber).AsInt64 else Result := 0
    else
      Result := 0;
end;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

function GetJSONDoubleValue(const JSONObject: TJSONObject; const ValueName: string): Double; overload;
var
  JSONValue: TJSONValue;
begin
  JSONValue := JSONObject.GetValue(ValueName);
  if JSONValue <> nil then
    if not JSONValue.Null then
      Result := (JSONValue as TJSONNumber).AsDouble else Result := 0
    else
      Result := 0;
end;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

function GetJSONBooleanValue(const JSONObject: TJSONObject; const ValueName: string): Boolean; overload;
var
  JSONValue: TJSONValue;
begin
  JSONValue := JSONObject.GetValue(ValueName);
  if JSONValue <> nil then
    if not JSONValue.Null then
      Result := LowerCase(JSONValue.Value) = 'true' else Result := False
    else
      Result := False;
end;

//HHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHH

function GetJSONStringValue(const JSONObject: TJSONObject; const ValueName: string; out ResultValue: string): Boolean; overload;
var
  JSONValue: TJSONValue;
begin
  JSONValue := JSONObject.GetValue(ValueName);
  Result := JSONValue <> nil;
  if Result then Result := Result and not JSONValue.Null;
  if Result then ResultValue := JSONValue.Value;
end;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

function GetJSONObjectValue(const JSONObject: TJSONObject; const ValueName: string; out ResultValue: TJSONObject): Boolean; overload;
var
  JSONValue: TJSONValue;
begin
  JSONValue := JSONObject.GetValue(ValueName);
  Result := JSONValue <> nil;
  if Result then Result := Result and not JSONValue.Null;
  if Result then ResultValue := TJSONObject(JSONValue);
end;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

function GetJSONArrayValue(const JSONObject: TJSONObject; const ValueName: string; out ResultValue: TJSONArray): Boolean; overload;
var
  JSONValue: TJSONValue;
begin
  JSONValue := JSONObject.GetValue(ValueName);
  Result := JSONValue <> nil;
  if Result then Result := Result and not JSONValue.Null;
  if Result then ResultValue := TJSONArray(JSONValue);
end;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

function GetJSONIntValue(const JSONObject: TJSONObject; const ValueName: string; out ResultValue: Integer): Boolean; overload;
var
  JSONValue: TJSONValue;
begin
  JSONValue := JSONObject.GetValue(ValueName);
  Result := JSONValue <> nil;
  if Result then Result := Result and not JSONValue.Null;
  if Result then ResultValue := TJSONNumber(JSONValue).AsInt;
end;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

function GetJSONInt64Value(const JSONObject: TJSONObject; const ValueName: string; out ResultValue: Int64): Boolean; overload;
var
  JSONValue: TJSONValue;
begin
  JSONValue := JSONObject.GetValue(ValueName);
  Result := JSONValue <> nil;
  if Result then Result := Result and not JSONValue.Null;
  if Result then ResultValue := TJSONNumber(JSONValue).AsInt64;
end;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

function GetJSONDoubleValue(const JSONObject: TJSONObject; const ValueName: string; out ResultValue: Double): Boolean; overload;
var
  JSONValue: TJSONValue;
begin
  JSONValue := JSONObject.GetValue(ValueName);
  Result := JSONValue <> nil;
  if Result then Result := Result and not JSONValue.Null;
  if Result then ResultValue := TJSONNumber(JSONValue).AsDouble;
end;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

function GetJSONBooleanValue(const JSONObject: TJSONObject; const ValueName: string; out ResultValue: Boolean): Boolean; overload;
var
  JSONValue: TJSONValue;
begin
  JSONValue := JSONObject.GetValue(ValueName);
  Result := JSONValue <> nil;
  if Result then Result := Result and not JSONValue.Null;
  if Result then ResultValue := LowerCase(JSONValue.Value) = 'true' else ResultValue := False;
end;

//HHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHH

function IsJSONValueExists(const JSONObject: TJSONObject; const ValueName: string): Boolean;
var
  JSONValue: TJSONValue;
begin
  JSONValue := JSONObject.GetValue(ValueName);
  Result := JSONValue <> nil;
end;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

function GetJSONArrayElement(const JSONArray: TJSONArray; Index: Integer): TJSONObject;
var
  JSONValue: TJSONValue;
begin
  JSONValue := JSONArray.Items[Index];
  if JSONValue <> nil then
    if not JSONValue.Null then
      Result := JSONValue as TJSONObject
    else
      Result := nil
  else
    Result := nil;
end;

end.
