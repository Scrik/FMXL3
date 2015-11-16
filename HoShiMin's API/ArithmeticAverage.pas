unit ArithmeticAverage;

interface

//HHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHH

type
  // Усредняет с предыдущим средним:
  TAverageOverLastAveragedValue = class
    private
      FFirstTime: Boolean;
      FLastAverage: Single;
      FLastValue: Single;
    public
      property LastAverage: Single read FLastAverage;
      property LastValue: Single read FLastValue;

      function Add(Value: Single): Single;
      procedure Clear;

      constructor Create;
      destructor Destroy; override;
  end;

//HHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHH

  // Усредняет по определённому количеству предыдущих значений:
  TLastValues = array of Single;
  TAverageOverLastValues = class
    private
      FNotInitializedCount: Integer;
      FAveragingSize: Integer;
      FLastValues: TLastValues;
      FLastAverage: Single;
      FLastValue: Single;
    public
      property LastValues: TLastValues read FLastValues;
      property LastAverage: Single read FLastAverage;
      property LastValue: Single read FLastValue;

      function Add(Value: Single): Single;
      procedure SetAveragingSize(AveragingSize: Integer);
      procedure Clear;

      constructor Create(AveragingSize: Integer);
      destructor Destroy; override;
  end;

//HHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHH

  // Усредняет со всеми предыдущими значениями:
  TAverageOverAllLastValues = class
    private
      FAveragingSize: Integer;
      FLastValues: TLastValues;
      FLastAverage: Single;
      FLastValue: Single;
    public
      property AveragingSize: Integer read FAveragingSize;
      property LastValues: TLastValues read FLastValues;
      property LastAverage: Single read FLastAverage;
      property LastValue: Single read FLastValue;

      function Add(Value: Single): Single;
      procedure Clear;

      constructor Create;
      destructor Destroy; override;
  end;

//HHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHH



implementation


{ TAverageOverLastAveragedValue }

function TAverageOverLastAveragedValue.Add(Value: Single): Single;
begin
  if FFirstTime then
    FLastAverage := Value
  else
    FLastAverage := (FLastAverage + Value) / 2;

  FFirstTime := False;
  FLastValue := Value;
  Result     := FLastAverage;
end;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

procedure TAverageOverLastAveragedValue.Clear;
begin
  FFirstTime   := True;
  FLastAverage := 0;
  FLastValue   := 0;
end;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

constructor TAverageOverLastAveragedValue.Create;
begin
  inherited;
  Clear;
end;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

destructor TAverageOverLastAveragedValue.Destroy;
begin
  Clear;
  inherited;
end;

//HHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHH

{ TAverageOverLastValues }

function TAverageOverLastValues.Add(Value: Single): Single;
var
  I: Integer;
  Sum: Single;
begin

  if (FAveragingSize > 1) and (FNotInitializedCount < FAveragingSize) then
  begin
    Sum := 0;

    for I := 0 to FAveragingSize - 2 do
    begin
      FLastValues[I] := FLastValues[I + 1];
      Sum := Sum + FLastValues[I + 1];
    end;
    FLastValues[FAveragingSize - 1] := Value;
    Sum := Sum + Value;

    if FNotInitializedCount > 0 then Dec(FNotInitializedCount);

    FLastAverage := Sum / (FAveragingSize - FNotInitializedCount);
  end
  else
  begin
    // Записываем первое значение (крайнее правое):
    if (FAveragingSize > 0) then FLastValues[FAveragingSize - 1] := Value;
    FLastAverage := Value;
    if FNotInitializedCount > 0 then Dec(FNotInitializedCount);
  end;

  FLastValue := Value;
  Result := FLastAverage;
end;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

procedure TAverageOverLastValues.SetAveragingSize(AveragingSize: Integer);
begin
  FNotInitializedCount := FNotInitializedCount + (AveragingSize - FAveragingSize);
  if FNotInitializedCount < 0 then FNotInitializedCount := 0;

  FAveragingSize := AveragingSize;
  SetLength(FLastValues, FAveragingSize);
end;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

procedure TAverageOverLastValues.Clear;
var
  I: Integer;
begin
  FLastAverage := 0;
  FLastValue   := 0;
  FNotInitializedCount := FAveragingSize;
  if FAveragingSize > 0 then for I := 0 to FAveragingSize - 1 do FLastValues[I] := 0;
  FNotInitializedCount := FAveragingSize;
end;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

constructor TAverageOverLastValues.Create(AveragingSize: Integer);
begin
  FAveragingSize := 0;
  FNotInitializedCount := 0;
  SetAveragingSize(AveragingSize);
  Clear;
end;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

destructor TAverageOverLastValues.Destroy;
begin
  SetAveragingSize(0);
  inherited;
end;

//HHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHH

{ TAverageOverAllLastValues }

function TAverageOverAllLastValues.Add(Value: Single): Single;
var
  Sum: Single;
  I: Integer;
begin
  Inc(FAveragingSize);
  SetLength(FLastValues, FAveragingSize);

  FLastValues[FAveragingSize - 1] := Value;
  Sum := 0;
  for I := 0 to FAveragingSize - 1 do
    Sum := Sum + FLastValues[I];

  FLastAverage := Sum / FAveragingSize;
  FLastValue := Value;
  Result := FLastAverage;
end;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

procedure TAverageOverAllLastValues.Clear;
begin
  SetLength(FLastValues, 0);
  FLastValue := 0;
  FLastAverage := 0;
  FAveragingSize := 0;
end;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

constructor TAverageOverAllLastValues.Create;
begin
  Clear;
end;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

destructor TAverageOverAllLastValues.Destroy;
begin
  Clear;
  inherited;
end;

end.
