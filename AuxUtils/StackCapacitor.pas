unit StackCapacitor;

interface

uses
  Windows, SysUtils, Classes, Generics.Collections;

type
  TStackCapacitor<T> = class
    private
      FInitialValue: T;
      FCapacity: Integer;
      FList: TList<T>;
      function GetItem(Index: Integer): T;
      procedure SetItem(Index: Integer; const Value: T);
      procedure FillInitialValues;
    public
      property Capacity: Integer read FCapacity;
      property Items[Index: Integer]: T read GetItem write SetItem;

      constructor Create(Capacity: Integer; const InitialValue: T);
      destructor Destroy; override;

      procedure Add(Value: T);
      procedure Clear;
  end;

implementation

{ TStackCapacitor<T> }

procedure TStackCapacitor<T>.FillInitialValues;
var
  I: Integer;
begin
  for I := 0 to FCapacity - 1 do Add(FInitialValue);
end;



constructor TStackCapacitor<T>.Create(Capacity: Integer; const InitialValue: T);
begin
  FCapacity     := Capacity;
  FInitialValue := InitialValue;
  FList := TList<T>.Create;
  FillInitialValues;
end;

destructor TStackCapacitor<T>.Destroy;
begin
  FList.Clear;
  FList.Free;
end;



function TStackCapacitor<T>.GetItem(Index: Integer): T;
begin
  Result := FList.Items[Index];
end;

procedure TStackCapacitor<T>.SetItem(Index: Integer; const Value: T);
begin
  FList[Index] := Value;
end;



procedure TStackCapacitor<T>.Add(Value: T);
begin
  if FList.Count = FCapacity then FList.Delete(0);
  FList.Add(Value)
end;

procedure TStackCapacitor<T>.Clear;
begin
  FList.Clear;
  FillInitialValues;
end;

end.
