unit ResUnpacker;

interface

uses
  Windows, SysUtils, Classes, FileAPI, cHash;

function UnpackRes(const ResName, Destination: string): Boolean;

implementation

function UnpackRes(const ResName, Destination: string): Boolean;
var
  ResourceStream: TResourceStream;
  MemoryStream: TMemoryStream;
  ResHash, DestHash: AnsiString;
begin
  try
    ResourceStream := TResourceStream.Create(hInstance, ResName, RT_RCDATA);

    CreatePath(ExtractFilePath(Destination));

    if FileExists(Destination) then
    begin
      MemoryStream := TMemoryStream.Create;
      MemoryStream.LoadFromFile(Destination);
      DestHash := MD5DigestToHex(CalcMD5(MemoryStream.Memory^, MemoryStream.Size));
      FreeAndNil(MemoryStream);

      ResHash := MD5DigestToHex(CalcMD5(ResourceStream.Memory^, ResourceStream.Size));

      if DestHash <> ResHash then
        ResourceStream.SaveToFile(Destination);
    end
    else
    begin
      ResourceStream.SaveToFile(Destination);
    end;

    Result := True;
  except
    Result := False;
  end;

  FreeAndNil(ResourceStream);
end;

end.
