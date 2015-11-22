unit FilesScanner;

interface

uses
  SysUtils, Classes, FileAPI, StringsAPI, Generics.Collections;

type
  TExclusivesHashmap = class
    public type
      TStringHashmap = TDictionary<string, Boolean>;
    private
      FCount: Integer;
      FHashmap: TStringHashmap;
    public
      property Count: Integer read FCount;
      property Hashmap: TStringHashmap read FHashmap;

      constructor Create;
      destructor Destroy; override;

      function Contains(const RelativeFilePath: string): Boolean;
      procedure Add(const RelativeFilePath: string);
      procedure Clear;
  end;

  TFilesScannerStruct = record
    Path       : string;  // Путь относительно BaseFolder
    Mask       : string;  // Маска проверки (например, *.txt)
    Recursive  : Boolean; // Проверять ли подпапки
    Exclusives : TExclusivesHashmap; // Хэшмап "путь относительно Path" -> "исключение из проверки"
  end;

procedure ScanFiles(const BaseFolder: string; const FilesScannerStruct: TFilesScannerStruct; const FilesList: TStringList);

implementation

procedure ScanFiles(const BaseFolder: string; const FilesScannerStruct: TFilesScannerStruct; const FilesList: TStringList);
var
  ScanPath: string;
  I: Integer;
  FixedBaseFolder, RelativePath: string;
begin
  ScanPath := FixSlashes(BaseFolder + '\' + FilesScannerStruct.Path);

  FilesList.Clear;

// Получаем полный список в соответствии с маской:
  GetFilesList(ScanPath, FilesScannerStruct.Mask, FilesList, FilesScannerStruct.Recursive);
  if FilesList.Count = 0 then Exit;

  // Исправляем двойные слэши, если есть:
  FilesList.Text := FixSlashes(FilesList.Text);

// Обрабатываем исключения:

  if not Assigned(FilesScannerStruct.Exclusives) then Exit;
  if FilesScannerStruct.Exclusives.Count = 0 then Exit;

  // Проходимся по всем файлам, исключаем необходимые:
  I := 0;
  FixedBaseFolder := LowerCase(FixSlashes(BaseFolder));
  while I < FilesList.Count do
  begin
    GetRemainder(LowerCase(FixSlashes(FilesList[I])), FixSlashes(FixedBaseFolder + '\' + FilesScannerStruct.Path), RelativePath);
    RelativePath := LowerCase(FixSlashes(RelativePath));
    if StartsWith(RelativePath, '\') then
      RelativePath := Copy(RelativePath, 2, Length(RelativePath) - 1);

    if FilesScannerStruct.Exclusives.Contains(RelativePath) then
      FilesList.Delete(I)
    else
      Inc(I);
  end;
end;

{ TExclusivesHashmap }

constructor TExclusivesHashmap.Create;
begin
  FHashmap := TDictionary<string, Boolean>.Create;
  Clear;
end;

destructor TExclusivesHashmap.Destroy;
begin
  Clear;
  FreeAndNil(FHashmap);
end;

function TExclusivesHashmap.Contains(const RelativeFilePath: string): Boolean;
var
  Existing: Boolean;
begin
  Result := FHashmap.TryGetValue(RelativeFilePath, Existing);
end;

procedure TExclusivesHashmap.Add(const RelativeFilePath: string);
var
  FixedPath: string;
begin
  Inc(FCount);
  FixedPath := LowerCase(FixSlashes(RelativeFilePath));
  FHashmap.Add(FixedPath, True);
end;

procedure TExclusivesHashmap.Clear;
begin
  FCount := 0;
  FHashmap.Clear;
end;


end.
