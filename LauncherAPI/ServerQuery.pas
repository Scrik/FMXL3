unit ServerQuery;

interface

uses
  Windows, SysUtils, WinSock2, CodepageAPI;

type
  TMonitoringInfo = record
    IsActive: Boolean;
    MOTD: string;
    MaxPlayers: string;
    CurrentPlayers: string;
  end;

function GetServerInfo(IP: AnsiString; Port: Word; out ServerInfo: TMonitoringInfo; Timeout: Word = 0): Boolean;


implementation

function DNStoIP(Host: PAnsiChar): PAnsiChar;
var
  HostEnt: PHostEnt;
begin
  HostEnt := GetHostByName(Host);
  Result := inet_ntoa(PInAddr(HostEnt^.h_addr_list^)^);
end;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

function GetServerInfo(IP: AnsiString; Port: Word; out ServerInfo: TMonitoringInfo; Timeout: Word = 0): Boolean;
var
  Socket: TSocket;
  SockAddr: TSockAddrIn;

  FDSetW: TFDSet;
  FDSetE: TFDSet;
  TimeVal: TTimeVal;
  NonBlockingMode: Cardinal;

  ConnectionStatus: Boolean;

  RequestPackage: Word;
  Size: Integer;
  Buffer: Pointer;

  Response: string;

  StringLen: LongWord;
  Position: LongWord;

  I: Integer;
const
  BufferSize: LongWord = 1024;

begin
  Result := False;
  FillChar(ServerInfo, SizeOf(ServerInfo), #0);

  // Пытаемся установить соединение:
  Socket := WinSock2.socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);
  if Socket = INVALID_SOCKET then
  begin
    Shutdown(Socket, SD_BOTH);
    CloseSocket(Socket);
    Exit;
  end;

  IP := DNStoIP(PAnsiChar(IP));

  FillChar(SockAddr, SizeOf(SockAddr), #0);
  SockAddr.sin_family := AF_INET;
  SockAddr.sin_port := htons(Port);
  SockAddr.sin_addr.S_addr := inet_addr(PAnsiChar(IP));

  // Подключаемся:
  ConnectionStatus := False;
  if Timeout > 0 then
  begin
    NonBlockingMode := 1;
    IoCtlSocket(Socket, Integer(FIONBIO), NonBlockingMode);
    if WinSock2.connect(Socket, TSockAddr(SockAddr), SizeOf(TSockAddr)) <> 0 then
    begin
      FD_ZERO(FDSetW);
      FD_ZERO(FDSetE);
      _FD_SET(Socket, FDSetW);
      _FD_SET(Socket, FDSetE);
      TimeVal.tv_sec  := Timeout div 1000;
      TimeVal.tv_usec := (Timeout mod 1000) * 1000;
      select(0, nil, @FDSetW, @FDSetE, @TimeVal);
      ConnectionStatus := FD_ISSET(Socket, FDSetW);
    end;
    NonBlockingMode := 0;
    IoCtlSocket(Socket, Integer(FIONBIO), NonBlockingMode);
  end
  else
  begin
    ConnectionStatus := WinSock2.connect(Socket, TSockAddr(SockAddr), SizeOf(TSockAddr)) = 0;
  end;

  if not ConnectionStatus then Exit;

  // Посылаем данные:
  RequestPackage := $01FE;
  Send(Socket, RequestPackage, 2, 0);

  // Ждём ответ:
  GetMem(Buffer, BufferSize);
  FillChar(Buffer^, BufferSize, #0);

  Size := Recv(Socket, Buffer^, BufferSize, 0);

  // Закрываем соединение:
  Shutdown(Socket, SD_BOTH);
  CloseSocket(Socket);

  if (Size = SOCKET_ERROR) or (Size = 0) then
  begin
    FreeMem(Buffer);
    Exit;
  end;

  // Блок получили, можно парсить:
  Result := True;
  ServerInfo.IsActive := True;

// Для начала переведём наш блок в ANSI:

  // Нуль-терминаторы переведём в $A7 (аналог запроса $FE):
  I := 0;
  while I < Size do
  begin
    if Word(Pointer((NativeInt(Buffer) + I))^) = 0 then
      Word(Pointer((NativeInt(Buffer) + I))^) := Word(Pointer((NativeInt(Buffer) + I))^) or $00A7;
    Inc(I, 2);
  end;

  Response := PChar(Buffer);
  FreeMem(Buffer);

// Выделяем нужные блоки:

  // Получаем максимальное количество игроков:
  StringLen := Length(Response);
  Position := LastDelimiter(#$A7, Response);
  ServerInfo.MaxPlayers := Copy(Response, Position + 1, StringLen - Position);

  // Удаляем скопированную строку:
  Response := Copy(Response, 1, Position - 1);

  // Получаем количество игроков на сервере в данный момент:
  StringLen := Length(Response);
  Position := LastDelimiter(#$A7, Response);
  ServerInfo.CurrentPlayers := Copy(Response, Position + 1, StringLen - Position);

  // Удаляем скопированную строку:
  Response := Copy(Response, 1, Position - 1);

  // Получаем MOTD:
  StringLen := Length(Response);
  ServerInfo.MOTD := Copy(Response, 3, StringLen - 2);
end;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

function InitWinSock: Integer;
var
  WSAData: TWSAData;
begin
  Result := WSAStartup($202, WSAData);
end;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

initialization
begin
  InitWinSock;
end;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

finalization
begin
  WSACleanup;
end;

end.
