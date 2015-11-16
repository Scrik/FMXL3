unit DownloadHelper;

interface

uses
  SysUtils, FMX.Graphics, HTTPUtils;

function DownloadImage(const ImageLink: string; const Bitmap: FMX.Graphics.TBitmap): Boolean;

implementation

function DownloadImage(const ImageLink: string; const Bitmap: FMX.Graphics.TBitmap): Boolean;
var
  HTTPSender: THTTPSender;
begin
  Bitmap.Clear($00000000);

  HTTPSender := THTTPSender.Create;
  HTTPSender.GET(ImageLink);

  if not HTTPSender.Status then
  begin
    FreeAndNil(HTTPSender);
    Exit(False);
  end;

  try
    Bitmap.LoadFromStream(HTTPSender.HTTPSend.Document);
    Result := True;
  except
    Result := False;
  end;

  FreeAndNil(HTTPSender);
end;

end.
