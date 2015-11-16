unit CodepageAPI;

interface

uses
  Windows, SysUtils, Classes;

// Константы для CodePage:
const
  CP_ACP                   = 0;             { default to ANSI code page }
  CP_OEMCP                 = 1;             { default to OEM  code page }
  CP_MACCP                 = 2;             { default to MAC  code page }
  CP_THREAD_ACP            = 3;             { current thread's ANSI code page }
  CP_SYMBOL                = 42;            { SYMBOL translations }
  CP_UTF7                  = 65000;         { UTF-7 translation }
  CP_UTF8                  = 65001;         { UTF-8 translation }

// Перевод из ANSI-кодировки в UTF-8:
procedure UTF8Convert(const StringStream: TStringStream);

// Unicode в ANSI и обратно:
function WideToAnsi(const WideString: WideString; CodePage: Word = CP_ACP): AnsiString;
function AnsiToWide(const AnsiString: AnsiString; CodePage: Word = CP_ACP): WideString;

// OEM в ANSI и обратно:
function StrOemToAnsi(const S: AnsiString): AnsiString;
function StrAnsiToOem(const S: AnsiString): AnsiString;
function ConvertToAnsi(OEM: PAnsiChar): PAnsiChar;
function ConvertToOEM(Ansi: PAnsiChar): PAnsiChar;

implementation

procedure UTF8Convert(const StringStream: TStringStream);
var
  DecodedStream: TBytes;
begin
  try
    DecodedStream := StringStream.Encoding.Convert(
                                                    StringStream.Encoding.UTF8,
                                                    StringStream.Encoding.ANSI,
                                                    StringStream.Bytes,
                                                    0,
                                                    Length(StringStream.DataString)
                                                   );
    StringStream.Clear;
    StringStream.WriteData(DecodedStream, Length(DecodedStream));
  except
    StringStream.Clear;
    SetLength(DecodedStream, 0);
    Exit;
  end;

  SetLength(DecodedStream, 0);
end;

function WideToAnsi(const WideString: WideString; CodePage: Word = CP_ACP): AnsiString;
var
  L: Integer;
begin
  if WideString = '' then
    Result := ''
  else
  begin
    L := WideCharToMultiByte(
                              CodePage,
                              WC_COMPOSITECHECK or WC_DISCARDNS or WC_SEPCHARS or WC_DEFAULTCHAR,
                              @WideString[1],
                              -1,
                              nil,
                              0,
                              nil,
                              nil
                            );

    SetLength(Result, L - 1);

    if L > 1 then
      WideCharToMultiByte(
                           CodePage,
                           WC_COMPOSITECHECK or WC_DISCARDNS or WC_SEPCHARS or WC_DEFAULTCHAR,
                           @WideString[1],
                           -1,
                           @Result[1],
                           L - 1,
                           nil,
                           nil
                         );
  end;
end;


// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -


function AnsiToWide(const AnsiString: AnsiString; CodePage: Word = CP_ACP): WideString;
var
  L: Integer;
begin
  if AnsiString = '' then
    Result := ''
  else
  begin
    L := MultiByteToWideChar(
                              CodePage,
                              MB_PRECOMPOSED,
                              PAnsiChar(@AnsiString[1]),
                              -1,
                              nil,
                              0
                            );

    SetLength(Result, L - 1);

    if L > 1 then
      MultiByteToWideChar(
                           CodePage,
                           MB_PRECOMPOSED,
                           PAnsiChar(@AnsiString[1]),
                           -1,
                           PWideChar(@Result[1]),
                           L - 1
                         );
  end;
end;


// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -


function StrOemToAnsi(const S: AnsiString): AnsiString;
begin
  if Length(S) = 0 then Result := ''
  else
    begin
      SetLength(Result, Length(S));
      OemToAnsiBuff(@S[1], @Result[1], Length(S));
    end;
end;


// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -


function StrAnsiToOem(const S: AnsiString): AnsiString;
begin
  if Length(S) = 0 then Result := ''
  else
    begin
      SetLength(Result, Length(S));
      AnsiToOemBuff(@S[1], @Result[1], Length(S));
    end;
end;


// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -


function ConvertToAnsi(OEM: PAnsiChar): PAnsiChar;
begin
  OemToAnsi(OEM, OEM);
  Result := OEM;
end;


// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -


function ConvertToOEM(Ansi: PAnsiChar): PAnsiChar;
begin
  AnsiToOem(Ansi, Ansi);
  Result := Ansi;
end;

end.
