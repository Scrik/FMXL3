unit MicroDAsm;

interface

type
  TREXStruct = record
    B: Boolean; // Extension of the ModR/M r/m field, SIB base field, or Opcode reg field
    X: Boolean; // Extension of the SIB index field
    R: Boolean; // Extension of the ModR/M reg field
    W: Boolean; // 0 = Operand size determined by CS.D; 1 = 64 Bit Operand Size
  end;

type
  TInstruction = record
    PrefixesSize   : Byte;
    LegacyPrefixes : array [0..3] of Byte;

    REXPresent : Boolean;
    REXOffset  : Byte;
    REXPrefix  : Byte;
    REXStruct  : TREXStruct;

    OpcodeOffset     : Byte;
    OpcodeIsExtended : Boolean;
    OpcodeFlags      : Byte;
    OpcodeSize       : Byte;
    Opcode           : array [0..2] of Byte;
    FullOpcode       : LongWord;

    ModRMPresent : Boolean;
    ModRMOffset  : Byte;
    ModRM        : Byte;

    SIBPresent : Boolean;
    SIBOffset  : Byte;
    SIB        : Byte;

    AddressDisplacementPresent : Boolean;
    AddressDisplacementOffset  : Byte;
    AddressDisplacementSize    : Byte;
    AddressDisplacement        : UInt64;

    ImmediateDataPresent : Boolean;
    ImmediateDataOffset  : Byte;
    ImmediateDataSize    : Byte;
    ImmediateData        : UInt64;

    ScaleIndex : Byte;
    DisplacementWithBase : Boolean;
  end;

// GRP:
const
  GRP1 = 0;
  GRP2 = 1;
  GRP3 = 2;
  GRP4 = 3;

// Legacy Prefixes:
const
  PrefixNone = $00;

  // Legacy Prefix GRP 1:
  LockPrefix       = $F0;
  RepneRepnzPrefix = $F2;
  RepeRepzPrefix   = $F3;

  // Legacy Prefix GRP 2:
  CSOverridePrefix     = $2E;
  SSOverridePrefix     = $36;
  DSOverridePrefix     = $3E;
  ESOverridePrefix     = $26;
  FSOverridePrefix     = $64;
  GSOverridePrefix     = $65;
  BranchNotTakenPrefix = $2E; // Только с Jcc
  BranchTakenPrefix    = $3E; // Только с Jcc

  // Legacy Prefix GRP 3:
  OperandSizeOverridePrefix = $66;

  // Legacy Prefix GRP 4:
  AddressSizeOverridePrefix = $67;

// REX Prefix - определяет 64х-битный размер операндов, расширенные контрольные регистры:
const
  REXNone = $00;
  RexDiapason = [$40..$4F];

// Опкоды:
const
  EXTENDED_OPCODE = $0F;
  ThirdByteOpcodeSignature = [$66, $F2, $F3];


//HHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHH

function LDasm(Code: Pointer; Is64Bit: Boolean; out Instruction: TInstruction): Byte;

//HHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHH

{$I MicroDAsmTables.inc}

implementation

{$IFDEF CPUX64}
  type
    NativeUInt = UInt64;
{$ELSE}
  type
    NativeUInt = LongWord;
{$ENDIF}

function GetByte(BaseAddress: Pointer; Offset: NativeUInt): Byte; inline;
begin
  Result := Byte((Pointer(NativeUInt(BaseAddress) + Offset))^);
end;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

function GetWord(BaseAddress: Pointer; Offset: NativeUInt): Word; inline;
begin
  Result := Word((Pointer(NativeUInt(BaseAddress) + Offset))^);
end;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

function GetDWord(BaseAddress: Pointer; Offset: NativeUInt): LongWord; inline;
begin
  Result := LongWord((Pointer(NativeUInt(BaseAddress) + Offset))^);
end;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

function GetQWord(BaseAddress: Pointer; Offset: NativeUInt): UInt64; inline;
begin
  Result := UInt64((Pointer(NativeUInt(BaseAddress) + Offset))^);
end;

//HHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHH

function IsBitSet(Number, BitNumber: LongWord): Boolean; inline;
begin
  Result := (Number and (1 shl BitNumber)) <> 0;
end;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

function IsNumberContains(Number, SubNumber: LongWord): Boolean; inline;
begin
  Result := (Number and SubNumber) = SubNumber;
end;

//HHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHH

procedure GetModRmParts(ModRM: Byte; out _Mod, _Reg, _RM: Byte); inline;
begin
  // 192 = 11 000 000
  // 56  =    111 000
  // 7   =        111

  _Mod := (ModRM and 192) shr 6;
  _Reg := (ModRM and 56) shr 3;
  _RM  := (ModRM and 7);
end;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

procedure GetSibParts(SIB: Byte; out _Scale, _Index, _Base: Byte); inline;
begin
  // 192 = 11 000 000
  // 56  =    111 000
  // 7   =        111

  _Scale := (SIB and 192) shr 6;
  _Index := (SIB and 56) shr 3;
  _Base  := (SIB and 7);
end;

//HHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHH

function IsModRmPresent(Opcode: LongWord; Size: LongWord): Boolean; inline;
begin
  Result := False;
  case Size of
    1: Result := (OneByteOpcodeFlags[Opcode] and OP_MODRM) = OP_MODRM;
    2: Result := (TwoBytesOpcodeFlags[Opcode] and OP_MODRM) = OP_MODRM;
    //3: ...
  end;
end;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

function IsSibPresent(ModRM: Byte): Boolean; inline;
begin
  //      Mod Reg R/M
  // 192 = 11 000 000b - Mod
  //   4 =        100b - R/M
  Result := ((ModRM and 192) <> 192) and ((ModRM and $7) = 4);
end;

//HHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHH

function LDasm(Code: Pointer; Is64Bit: Boolean; out Instruction: TInstruction): Byte;
var
  TempByte    : Byte;
  RexByte     : Byte;
  OpCodeByte  : Byte;
  ModRmByte   : Byte;
  SibByte     : Byte;
  I           : Byte;
  //OperandSize : Byte;
  _Mod,   _Reg,   _RM   : Byte;
  _Scale, _Index, _Base : Byte;
begin
{

  Структура инструкции:

        GRP 1, 2, 3, 4                          7.....0   7.....0   7.....0
  +------------------------+-------------------+---------------------------+
  | Legacy Prefixes (opt.) | REX Prefix (opt.) | = OPCODE (1, 2, 3 byte) = +--+
  +------------------------+-------------------+---------------------------+  |
                                                                              |
      +-----------------------------------------------------------------------+
      |
      |   +-----+-----+-----+   +-------+-------+------+
      +-->| Mod | Reg | R/M | + | Scale | Index | Base |  +  d32|16|8|N + d32|16|8|N
          +-----+-----+-----+   +-------+-------+------+       Address     Immediate
            7-6   5-3   2-0        7-6     5-3    2-0       Displacement     Data

              Mod R/M Byte               SIB Byte


  Принцип разбора:
   1) Получить префиксы (опциональные, до 4х байт)
   2) Если код х64 - получить опциональный REX-префикс, отвечающий за 64х-битную адресацию.
   3) Спарсить опкод (от одного до трёх байт, в зависимости от префиксов и первого байта опкода)
   4) По таблице опкодов определить наличие байта ModRM и размер данных
   5) По таблице ModRM (если инструкция использует ModRM) определить наличие SIB

}

  Result := 0;
  FillChar(Instruction, SizeOf(Instruction), #0);
  //OperandSize := 0;

  // Получаем Legacy Prefix всех групп (GRP 1 - GRP 4):
  for I := 0 to 3 do
  begin
    case GetByte(Code, I) of
      LockPrefix       : Instruction.LegacyPrefixes[I] := LockPrefix;
      RepneRepnzPrefix : Instruction.LegacyPrefixes[I] := RepneRepnzPrefix;
      RepeRepzPrefix   : Instruction.LegacyPrefixes[I] := RepeRepzPrefix;
      CSOverridePrefix : Instruction.LegacyPrefixes[I] := CSOverridePrefix;
      SSOverridePrefix : Instruction.LegacyPrefixes[I] := SSOverridePrefix;
      DSOverridePrefix : Instruction.LegacyPrefixes[I] := DSOverridePrefix;
      ESOverridePrefix : Instruction.LegacyPrefixes[I] := ESOverridePrefix;
      FSOverridePrefix : Instruction.LegacyPrefixes[I] := FSOverridePrefix;
      GSOverridePrefix : Instruction.LegacyPrefixes[I] := GSOverridePrefix;
      // BranchNotTakenPrefix : Instruction.LegacyPrefixes[I] := BranchNotTakenPrefix;
      // BranchTakenPrefix    : Instruction.LegacyPrefixes[I] := BranchTakenPrefix;
      OperandSizeOverridePrefix : Instruction.LegacyPrefixes[I] := OperandSizeOverridePrefix;
      AddressSizeOverridePrefix : Instruction.LegacyPrefixes[I] := AddressSizeOverridePrefix;
    else
      Break;
    end;

    Inc(Instruction.PrefixesSize);
  end;

  Instruction.REXOffset := Instruction.PrefixesSize;

  // Выставляем смещение опкода равное REX'у - вдруг REX'a нет,
  // а смещение опкода уже стоит:
  Instruction.OpcodeOffset := Instruction.REXOffset;

  // Получаем REX-префикс:
  if Is64Bit then
  begin
    TempByte := GetByte(Code, Instruction.REXOffset);

    // Проверяем, является ли байт REX-префиксом [$40..$4F]:
    if TempByte in RexDiapason then
    begin
      Inc(Result);

      RexByte := TempByte;
      Instruction.REXPrefix := RexByte;
      Instruction.REXPresent := True;

      Instruction.REXStruct.B := IsBitSet(RexByte, 0);
      Instruction.REXStruct.X := IsBitSet(RexByte, 1);
      Instruction.REXStruct.R := IsBitSet(RexByte, 2);
      Instruction.REXStruct.W := IsBitSet(RexByte, 3);
{
      // Обрабатываем REX:
      case Instruction.REXStruct.W of
        True: if (Instruction.LegacyPrefixes[GRP1] = OperandSizeOverridePrefix) or
                 (Instruction.LegacyPrefixes[GRP2] = OperandSizeOverridePrefix) or
                 (Instruction.LegacyPrefixes[GRP3] = OperandSizeOverridePrefix) or
                 (Instruction.LegacyPrefixes[GRP4] = OperandSizeOverridePrefix)
              then
                OperandSize := 4  // 4 байта = 32 бита
              else
                OperandSize := 0; // Размер операнда определяется через CS.D

        False: OperandSize := 8; // 8 байт = 64 бита
      end;
}
      // Увеличиваем смещение опкода:
      Inc(Instruction.OpcodeOffset);

    // if byte is REX-byte <-
    end;

  // if Is64Bit then <-
  end;


  // Разбираем опкод:
  OpCodeByte := GetByte(Code, Instruction.OpcodeOffset);
  Instruction.OpcodeIsExtended := OpCodeByte = EXTENDED_OPCODE;

  case Instruction.OpcodeIsExtended of
    True:
    begin
      // Разделяем двухбайтные и трёхбайтные опкоды:
      if Instruction.OpcodeOffset > 0 then
      begin
        if GetByte(Code, Instruction.OpcodeOffset - 1) in ThirdByteOpcodeSignature then
        begin
          // Трёхбайтный опкод:
          Instruction.LegacyPrefixes[Instruction.PrefixesSize - 1] := PrefixNone;
          Dec(Instruction.OpcodeOffset);

          Instruction.OpcodeSize := 3;
          Instruction.Opcode[0] := GetByte(Code, Instruction.OpcodeOffset);
          Instruction.Opcode[1] := GetByte(Code, Instruction.OpcodeOffset + 1);
          Instruction.Opcode[2] := GetByte(Code, Instruction.OpcodeOffset + 2);
        end
        else
        begin
          // Двухбайтный опкод:
          Instruction.OpcodeSize := 2;
          Instruction.Opcode[0] := OpCodeByte;
          Instruction.Opcode[1] := GetByte(Code, Instruction.OpcodeOffset + 1);
        end;
      end
      else
      begin
        // Двухбайтный опкод:
        Instruction.OpcodeSize := 2;
        Instruction.Opcode[0] := OpCodeByte;
        Instruction.Opcode[1] := GetByte(Code, Instruction.OpcodeOffset + 1);
      end;
    end;

    False:
    begin
      Instruction.OpcodeSize := 1;
      Instruction.Opcode[0] := OpCodeByte;
    end;
  end;

  // Получаем полный опкод:
  for I := 0 to Instruction.OpcodeSize - 1 do
  begin
    Instruction.FullOpcode := Instruction.FullOpcode shl 8;
    Instruction.FullOpcode := Instruction.FullOpcode + Instruction.Opcode[I];
  end;

  Instruction.ModRMPresent := IsModRmPresent(Instruction.FullOpcode, Instruction.OpcodeSize);
  if Instruction.ModRMPresent then
  begin
    Inc(Result);
    Instruction.ModRMOffset := Instruction.OpcodeOffset + Instruction.OpcodeSize;

    // Разбираем байт ModR/M:
    ModRmByte := GetByte(Code, Instruction.ModRMOffset);
    Instruction.SIBPresent := IsSibPresent(ModRmByte);
    GetModRmParts(ModRmByte, _Mod, _Reg, _RM);

    if Instruction.SIBPresent then
    begin
      Inc(Result);
      Instruction.SIBOffset := Instruction.ModRMOffset + 1;
      SibByte := GetByte(Code, Instruction.SIBOffset);
      GetSibParts(SibByte, _Scale, _Index, _Base);

      Instruction.ScaleIndex := _Scale * 2; // [Регистр * ScaleIndex]

      if _Base = 5 { 101b } then
      begin
        if (_Mod = 1 { 01b } ) or (_Mod = 2 { 10b } ) then
          Instruction.DisplacementWithBase := True;
      end;
    end;

    case _Mod of
      0: { 00b }
      with Instruction do
      begin
        if (_RM = 5 { 101b } ) or (Instruction.SIBPresent and (_Base = 5 { 101b } )) then
        begin
          Instruction.AddressDisplacementPresent := True;
          AddressDisplacementSize := 4;
          AddressDisplacementOffset := SIBOffset + 1;
          AddressDisplacement := GetDWord(Code, AddressDisplacementOffset);
        end;
      end;

      1: { 01b }
      with Instruction do
      begin
        Instruction.AddressDisplacementPresent := True;
        AddressDisplacementSize := 1;
        AddressDisplacementOffset := SIBOffset + 1;
        AddressDisplacement := GetByte(Code, AddressDisplacementOffset);
      end;

      2: { 10b }
      with Instruction do
      begin
        Instruction.AddressDisplacementPresent := True;
        AddressDisplacementSize := 4;
        AddressDisplacementOffset := SIBOffset + 1;
        AddressDisplacement := GetDWord(Code, AddressDisplacementOffset);
      end;
    end;
  end;

  // Получаем флаги опкода:
  case Instruction.OpcodeSize of
    1: Instruction.OpcodeFlags := OneByteOpcodeFlags[Instruction.FullOpcode];
    2: Instruction.OpcodeFlags := TwoBytesOpcodeFlags[Instruction.FullOpcode];
    //3: ...
  end;

  // Получаем Immediate Data:
  if IsNumberContains(Instruction.OpcodeFlags, OP_DATA_I8) then
  begin
    Instruction.ImmediateDataPresent := True;
    Instruction.ImmediateDataOffset := Instruction.OpcodeOffset +
                                       Instruction.OpcodeSize +
                                       Byte(Instruction.ModRMPresent) +
                                       Byte(Instruction.SIBPresent) +
                                       Instruction.AddressDisplacementSize;
    Instruction.ImmediateDataSize := 1;
    Instruction.ImmediateData := GetByte(Code, Instruction.ImmediateDataOffset);
  end;

  if IsNumberContains(Instruction.OpcodeFlags, OP_DATA_I16) then
  begin
    Instruction.ImmediateDataPresent := True;
    Instruction.ImmediateDataOffset := Instruction.OpcodeOffset +
                                       Instruction.OpcodeSize +
                                       Byte(Instruction.ModRMPresent) +
                                       Byte(Instruction.SIBPresent) +
                                       Instruction.AddressDisplacementSize;
    Instruction.ImmediateDataSize := 2;
    Instruction.ImmediateData := GetWord(Code, Instruction.ImmediateDataOffset);
  end;

  if IsNumberContains(Instruction.OpcodeFlags, OP_DATA_I16_I32) then
  begin
    Instruction.ImmediateDataPresent := True;
    Instruction.ImmediateDataOffset := Instruction.OpcodeOffset +
                                       Instruction.OpcodeSize +
                                       Byte(Instruction.ModRMPresent) +
                                       Byte(Instruction.SIBPresent) +
                                       Instruction.AddressDisplacementSize;

    if (Instruction.LegacyPrefixes[GRP1] = OperandSizeOverridePrefix) or
       (Instruction.LegacyPrefixes[GRP2] = OperandSizeOverridePrefix) or
       (Instruction.LegacyPrefixes[GRP3] = OperandSizeOverridePrefix) or
       (Instruction.LegacyPrefixes[GRP4] = OperandSizeOverridePrefix)
    then
    begin
      Instruction.ImmediateDataSize := 2;
      Instruction.ImmediateData := GetWord(Code, Instruction.ImmediateDataOffset);
    end
    else
    begin
      Instruction.ImmediateDataSize := 4;
      Instruction.ImmediateData := GetDWord(Code, Instruction.ImmediateDataOffset);
    end;
  end;

  if IsNumberContains(Instruction.OpcodeFlags, OP_DATA_I16_I32_I64) then
  begin
    Instruction.ImmediateDataPresent := True;
    Instruction.ImmediateDataOffset := Instruction.OpcodeOffset +
                                       Instruction.OpcodeSize +
                                       Byte(Instruction.ModRMPresent) +
                                       Byte(Instruction.SIBPresent) +
                                       Instruction.AddressDisplacementSize;

    if (Instruction.LegacyPrefixes[GRP1] = OperandSizeOverridePrefix) or
       (Instruction.LegacyPrefixes[GRP2] = OperandSizeOverridePrefix) or
       (Instruction.LegacyPrefixes[GRP3] = OperandSizeOverridePrefix) or
       (Instruction.LegacyPrefixes[GRP4] = OperandSizeOverridePrefix)
    then
    begin
      if Instruction.REXPresent then
      begin
        Instruction.ImmediateDataSize := 4;
        Instruction.ImmediateData := GetDWord(Code, Instruction.ImmediateDataOffset);
      end
      else
      begin
        Instruction.ImmediateDataSize := 2;
        Instruction.ImmediateData := GetWord(Code, Instruction.ImmediateDataOffset);
      end;
    end
    else
    begin
      if Instruction.REXPresent then
      begin
        Instruction.ImmediateDataSize := 8;
        Instruction.ImmediateData := GetDWord(Code, Instruction.ImmediateDataOffset);
      end
      else
      begin
        Instruction.ImmediateDataSize := 4;
        Instruction.ImmediateData := GetWord(Code, Instruction.ImmediateDataOffset);
      end;
    end;
  end;

  // Выводим результат:
  Result := Result +
            Instruction.PrefixesSize +
            Instruction.OpcodeSize +
            Instruction.AddressDisplacementSize +
            Instruction.ImmediateDataSize;
end;

end.
