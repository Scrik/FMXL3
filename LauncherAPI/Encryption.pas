unit Encryption;

interface

procedure EncryptDecryptVerrnam(Data: Pointer; DataLength: LongWord; Key: Pointer; KeyLength: LongWord); overload;
procedure EncryptDecryptVerrnam(var Data: string; Key: Pointer; KeyLength: LongWord); overload;

implementation

procedure EncryptDecryptVerrnam(Data: Pointer; DataLength: LongWord; Key: Pointer; KeyLength: LongWord); overload;
var
  KeyOffset: LongWord;
  DataOffset: LongWord;
  CurrentDataPtr: Pointer;
begin
  if (DataLength = 0) or (KeyLength = 0) then Exit;

  KeyOffset := 0;

  for DataOffset := 0 to DataLength - 1 do
  begin
    CurrentDataPtr := Pointer(NativeUInt(Data) + DataOffset);
    Byte(CurrentDataPtr^) := Byte(Byte(CurrentDataPtr^) xor Byte(Pointer(NativeUInt(Key) + KeyOffset)^));
    Inc(KeyOffset);

    if KeyOffset = KeyLength then KeyOffset := 0;
  end;
end;


procedure EncryptDecryptVerrnam(var Data: string; Key: Pointer; KeyLength: LongWord); overload;
var
  DataLength: LongWord;
  KeyOffset: LongWord;
  I: LongWord;
begin
  DataLength := Length(Data);
  if (DataLength = 0) or (KeyLength = 0) then Exit;

  KeyOffset := 0;

  for I := 1 to DataLength do
  begin
    Data[I] := Char(Byte(Data[I]) xor Byte(Pointer(NativeUInt(Key) + KeyOffset)^));
    Inc(KeyOffset);

    if KeyOffset = KeyLength then KeyOffset := 0;
  end;
end;

end.

