unit FilesValidation;

interface

uses
  Windows, SysUtils, Classes, ShlwAPI,
  System.JSON, System.Threading, Generics.Collections,
  ValidationTypes, FilesScanner, JSONUtils,
  FileAPI, FilesNotifier, CodepageAPI, StringsAPI,
  cHash;

type
  TCheckingsInfo  = TJSONArray;
  TValidFilesJSON = TJSONArray;

  VALIDATION_STATUS = (
    VALIDATION_STATUS_SUCCESS,        // Все файлы прошли проверку
    VALIDATION_STATUS_DELETION_ERROR, // Не получилось удалить несоответствующий файл
    VALIDATION_STATUS_NEED_UPDATE     // Требуется обновление
  );

  TCheckingsList = array of TFilesScannerStruct; // Список файлов и папок на проверку
  TOnFilesMismatching = reference to procedure(const ErrorFiles: TStringList);

  TFilesValidator = class
    private
      FBaseFolder: string;          // Основная папка, относительно которой задаются пути в JSON'е
      FRelativeWorkingPath: string; // Папка относительно FBaseFolder, в которой лежат все файлы и папки

      FCriticalSection: _RTL_CRITICAL_SECTION; // Критическая секция для многопоточной работы со списками

      FCheckingsList : TCheckingsList;   // Список файлов и папок на проверку
      FValidFiles    : TValidFiles;      // Список верных файлов
      FErrorFiles    : TStringList;      // Список файлов, которые не удалось удалить при проверке
      FAbsentFiles   : TAbsentFilesList; // Список отсутствующих файлов

      FLocalFiles: array of TStringList;

      FWatchers: array of TFilesNotifier;

      procedure AddToErrorFiles(const FilePath: string);
      procedure AddToAbsentFiles(const FileInfo: TValidFileInfo);

      function GetFileHash(const FilePath: string): string;

      procedure FillLocalFilesArray(Multithreading: Boolean);
      procedure TryToDeleteFile(const FilePath: string);
      procedure ValidateFile(const FilePath: string);
      procedure ValidateFilesList(const FilesList: TStringList; Multithreading: Boolean);
      procedure ValidateAllFilesLists(Multithreading: Boolean);
      procedure ClearLocalFilesArray(Multithreading: Boolean);
      procedure FillAbsentFilesList(Multithreading: Boolean);
    public
      property ErrorFiles  : TStringList      read FErrorFiles;
      property AbsentFiles : TAbsentFilesList read FAbsentFiles;

      constructor Create;
      destructor Destroy; override;

      procedure ExtractCheckingsInfo(const CheckingsInfo: TCheckingsInfo);
      procedure ExtractValidFilesInfo(const ValidFilesJSON: TValidFilesJSON);
      function Validate(const BaseFolder, RelativeWorkingFolder: string; Multithreading: Boolean = True): VALIDATION_STATUS;

      procedure StartFoldersWatching(const ClientFolder: string; OnFilesMismatching: TOnFilesMismatching);
      procedure StopFoldersWatching;

      procedure ClearCheckingsList;
      procedure ClearFilesLists;
      procedure ClearValidFilesList;
      procedure Clear;
  end;

implementation

{ TFilesValidator }


// Добавляем файл в список файлов, которые не получилось удалить:
procedure TFilesValidator.AddToErrorFiles(const FilePath: string);
begin
  EnterCriticalSection(FCriticalSection);
  FErrorFiles.Add(FilePath);
  LeaveCriticalSection(FCriticalSection);
end;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

// Добавляем файл в список отсутствующих файлов:
procedure TFilesValidator.AddToAbsentFiles(const FileInfo: TValidFileInfo);
var
  AbsentFileInfo: TAbsentFileInfo;
begin
  AbsentFileInfo.Size := FileInfo.Size;
  AbsentFileInfo.Link := FileInfo.Link;

  EnterCriticalSection(FCriticalSection);
  FAbsentFiles.Add(AbsentFileInfo);
  LeaveCriticalSection(FCriticalSection);
end;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

// Получаем хэш файла:
function TFilesValidator.GetFileHash(const FilePath: string): string;
var
  FilePtr: Pointer;
  FileSize: Integer;
begin
  FilePtr := LoadFileToMemory(FilePath, FileSize);
  Result := LowerCase(AnsiToWide(MD5DigestToHex(CalcMD5(FilePtr^, FileSize))));
  FreeMem(FilePtr);
end;


//HHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHH


// Получаем списки локальных файлов для каждого элемента в массиве проверок:
procedure TFilesValidator.FillLocalFilesArray(Multithreading: Boolean);
var
  CheckingsCount: Integer;
  FixedPath: string;
  I: Integer;
begin
  CheckingsCount := Length(FCheckingsList);
  if CheckingsCount = 0 then Exit;

  FixedPath := FixSlashes(FBaseFolder + '\' + FRelativeWorkingPath);

  // Получаем список файлов для каждого элемента в списке проверок:
  SetLength(FLocalFiles, CheckingsCount);
  if Multithreading then
  begin
    TParallel.&For(0, CheckingsCount - 1, procedure(I: Integer)
    begin
      FLocalFiles[I] := TStringList.Create;
      ScanFiles(FixedPath, FCheckingsList[I], FLocalFiles[I]);
    end);
  end
  else
  begin
    for I := 0 to CheckingsCount - 1 do
    begin
      FLocalFiles[I] := TStringList.Create;
      ScanFiles(FixedPath, FCheckingsList[I], FLocalFiles[I]);
    end;
  end;
end;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

// Пробуем удалить, и если не получается - добавляем в список файлов с ошибками:
procedure TFilesValidator.TryToDeleteFile(const FilePath: string);
begin
  if not DeleteFile(FilePath) then AddToErrorFiles(FilePath);
end;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

// Проверяем файл:
procedure TFilesValidator.ValidateFile(const FilePath: string);
var
  RelativePath  : string;
  FileSize      : Integer;
  ValidFileInfo : TValidFileInfo;
begin
  RelativePath := GetRelativePath(FilePath, FBaseFolder + '\');

  // Если файла нет в списке верных файлов - удаляем:
  if not FValidFiles.Get(RelativePath, ValidFileInfo) then
  begin
    TryToDeleteFile(FilePath);
    Exit;
  end;

  // Если размер файла не совпадает с верным размером - удаляем:
  FileSize := GetFileSize(FilePath);
  if FileSize <> ValidFileInfo.Size then
  begin
    TryToDeleteFile(FilePath);
    Exit;
  end;

  // Если не совпадает хэш - удаляем:
  if GetFileHash(FilePath) <> LowerCase(ValidFileInfo.Hash) then
  begin
    TryToDeleteFile(FilePath);
    Exit;
  end;
end;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

// Проверяем каждый файл в списке локальных файлов:
procedure TFilesValidator.ValidateFilesList(const FilesList: TStringList; Multithreading: Boolean);
var
  I: Integer;
begin
  if FilesList.Count = 0 then Exit;

  FilesList.Text := FixSlashes(FilesList.Text);

  if Multithreading then
  begin
    TParallel.&For(0, FilesList.Count - 1, procedure(I: Integer)
    begin
      ValidateFile(FilesList[I]);
    end);
  end
  else
  begin
    for I := 0 to FilesList.Count - 1 do
      ValidateFile(FilesList[I]);
  end;
end;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

// Проходимся по всем списка локальных файлов, и проверяем каждый список:
procedure TFilesValidator.ValidateAllFilesLists(Multithreading: Boolean);
var
  LocalFilesEntriesCount: Integer;
  I: Integer;
begin
  LocalFilesEntriesCount := Length(FLocalFiles);
  if LocalFilesEntriesCount = 0 then Exit;

  if Multithreading then
  begin
    TParallel.&For(0, LocalFilesEntriesCount - 1, procedure(I: Integer)
    begin
      ValidateFilesList(FLocalFiles[I], Multithreading);
    end);
  end
  else
  begin
    for I := 0 to LocalFilesEntriesCount - 1 do
      ValidateFilesList(FLocalFiles[I], Multithreading);
  end;
end;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

// Освобождаем память, занятую под списки локальных файлов:
procedure TFilesValidator.ClearLocalFilesArray(Multithreading: Boolean);
var
  LocalFilesEntriesCount: Integer;
  I: Integer;
begin
  LocalFilesEntriesCount := Length(FLocalFiles);
  if LocalFilesEntriesCount = 0 then Exit;

  if Multithreading then
  begin
    TParallel.&For(0, LocalFilesEntriesCount - 1, procedure(I: Integer)
    begin
      FLocalFiles[I].Clear;
      FreeAndNil(FLocalFiles[I]);
    end);
  end
  else
  begin
    for I := 0 to LocalFilesEntriesCount - 1 do
    begin
      FLocalFiles[I].Clear;
      FreeAndNil(FLocalFiles[I]);
    end;
  end;
  SetLength(FLocalFiles, 0);
end;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

// Получаем список отсутствующих файлов:
procedure TFilesValidator.FillAbsentFilesList(Multithreading: Boolean);
var
  ValidFilesArray: TArray<TValidFileInfo>;
  I: Integer;
begin
  ValidFilesArray := FValidFiles.ValidFilesHashmap.Values.ToArray;
  if Multithreading then
  begin
    TParallel.&For(0, Length(ValidFilesArray) - 1, procedure(I: Integer)
    begin
      if not FileExists(FBaseFolder + '\' + ValidFilesArray[I].Link) then AddToAbsentFiles(ValidFilesArray[I]);
    end);
  end
  else
  begin
    for I := 0 to Length(ValidFilesArray) - 1 do
      if not FileExists(FBaseFolder + '\' + ValidFilesArray[I].Link) then AddToAbsentFiles(ValidFilesArray[I]);
  end;
end;


//HHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHH


constructor TFilesValidator.Create;
begin
  InitializeCriticalSection(FCriticalSection);
  FValidFiles  := TValidFiles.Create;
  FErrorFiles  := TStringList.Create;
  FAbsentFiles := TAbsentFilesList.Create;
  Clear;
end;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

destructor TFilesValidator.Destroy;
begin
  Clear;
  FreeAndNil(FValidFiles);
  FreeAndNil(FErrorFiles);
  FreeAndNil(FAbsentFiles);
  DeleteCriticalSection(FCriticalSection);
  inherited;
end;

//HHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHH

procedure TFilesValidator.ExtractCheckingsInfo(
  const CheckingsInfo: TCheckingsInfo);
begin
  ClearFilesLists;
  ClearCheckingsList;

  if CheckingsInfo = nil then Exit;
  if CheckingsInfo.Count = 0 then Exit;

  SetLength(FCheckingsList, CheckingsInfo.Count);
  TParallel.&For(0, CheckingsInfo.Count - 1, procedure(I: Integer)
  var
    CheckingsElement, ExclusivesElement: TJSONObject;
    ExclusivesArray: TJSONArray;
    J: Integer;
  begin
    CheckingsElement := GetJSONArrayElement(CheckingsInfo, I);

    with FCheckingsList[I] do
    begin
      Path      := GetJSONStringValue (CheckingsElement, 'path');
      Mask      := GetJSONStringValue (CheckingsElement, 'mask');
      Recursive := GetJSONBooleanValue(CheckingsElement, 'recursive');
    end;

    // Получаем список файлов, исключаемых из проверки:
    ExclusivesArray := GetJSONArrayValue(CheckingsElement, 'exclusives');
    if ExclusivesArray = nil then Exit;
    if ExclusivesArray.Count = 0 then Exit;

    FCheckingsList[I].Exclusives := TExclusivesHashmap.Create;
    for J := 0 to ExclusivesArray.Count - 1 do
    begin
      ExclusivesElement := GetJSONArrayElement(ExclusivesArray, J);
      FCheckingsList[I].Exclusives.Add(GetJSONStringValue(ExclusivesElement, 'path'));
    end;
  end);
end;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

procedure TFilesValidator.ExtractValidFilesInfo(
  const ValidFilesJSON: TValidFilesJSON);
var
  I: Integer;
  ValidFileJSON   : TJSONObject;
  ValidFileInfo   : TValidFileInfo;
begin
  ClearFilesLists;
  ClearValidFilesList;

  if ValidFilesJSON = nil then Exit;
  if ValidFilesJSON.Count = 0 then Exit;

  // Парсим список верных файлов:
  for I := 0 to ValidFilesJSON.Count - 1 do
  begin
    ValidFileJSON := GetJSONArrayElement(ValidFilesJSON, I);

    // Заполняем хэшмап "относительный путь" -> "информация"
    ValidFileInfo.Size := GetJSONIntValue   (ValidFileJSON, 'size');
    ValidFileInfo.Hash := GetJSONStringValue(ValidFileJSON, 'hash');
    ValidFileInfo.Link := GetJSONStringValue(ValidFileJSON, 'path');
    FValidFiles.Add(ValidFileInfo.Link, ValidFileInfo);
  end;
end;

//HHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHH

function TFilesValidator.Validate(const BaseFolder,
  RelativeWorkingFolder: string; Multithreading: Boolean): VALIDATION_STATUS;
begin
  if FValidFiles.ValidFilesHashmap.Count = 0 then Exit(VALIDATION_STATUS_SUCCESS);

  FBaseFolder          := BaseFolder;
  FRelativeWorkingPath := RelativeWorkingFolder;

  // Чистим списки файлов:
  ClearFilesLists;

  // Делаем проверку файлов, удаляем не прошедшие проверку:
  FillLocalFilesArray(Multithreading);   // Заполняем список локальных файлов в соответствии с проверками
  ValidateAllFilesLists(Multithreading); // Проходимся по всем спискам локальных файлов и проверяем каждый файл в них
  ClearLocalFilesArray(Multithreading);  // Освобождаем память, занятую под списки локальных файлов

  // Получаем список недостающих файлов:
  FillAbsentFilesList(Multithreading);

  // Возвращаем результат:
  if FErrorFiles.Count  > 0 then Exit(VALIDATION_STATUS_DELETION_ERROR);
  if FAbsentFiles.Count > 0 then Exit(VALIDATION_STATUS_NEED_UPDATE);
  Result := VALIDATION_STATUS_SUCCESS;
end;


// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -


procedure TFilesValidator.StartFoldersWatching(const ClientFolder: string;
  OnFilesMismatching: TOnFilesMismatching);
var
  CheckingsCount: Integer;
  I: Integer;
  ExclusivesStr: string;
begin
  StopFoldersWatching;

  CheckingsCount := Length(FCheckingsList);
  if CheckingsCount = 0 then Exit;

  SetLength(FWatchers, CheckingsCount);
  for I := 0 to CheckingsCount - 1 do
  begin
    ExclusivesStr := '';
    if Assigned(FCheckingsList[I].Exclusives) then
      ExclusivesStr := GenerateDelimiteredData(TStringArray(FCheckingsList[I].Exclusives.Hashmap.Keys.ToArray), ',');

    FWatchers[I] := TFilesNotifier.Create(ClientFolder + '\' + FCheckingsList[I].Path, FCheckingsList[I].Mask, ExclusivesStr);

    FWatchers[I].OnDirChange := procedure(const FilesNotifier: TFilesNotifier; const NotifyStruct: TNotifyStruct)
    var
      I: Integer;
    begin
      ClearFilesLists;
      if NotifyStruct.ChangesCount = 0 then Exit;

      for I := 0 to NotifyStruct.ChangesCount - 1 do
        ValidateFile(FilesNotifier.BaseFolder + '\' + NotifyStruct.Changes[I].FileName);

      if FErrorFiles.Count > 0 then
        if Assigned(OnFilesMismatching) then
          OnFilesMismatching(FErrorFiles);
    end;

    FWatchers[I].StartWatching(FCheckingsList[I].Recursive);
  end;
end;


// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -


procedure TFilesValidator.StopFoldersWatching;
var
  WatchersCount: Integer;
begin
  WatchersCount := Length(FWatchers);
  if WatchersCount > 0 then TParallel.&For(0, WatchersCount - 1, procedure(I: Integer)
  begin
    if Assigned(FWatchers[I]) then
    begin
      FWatchers[I].StopWatching;
      FreeAndNil(FWatchers[I]);
    end;
  end);
  SetLength(FWatchers, 0);
end;


//HHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHH


procedure TFilesValidator.ClearCheckingsList;
var
  CheckingsListCount: Integer;
begin
  CheckingsListCount := Length(FCheckingsList);
  if CheckingsListCount = 0 then Exit;

  TParallel.&For(0, CheckingsListCount - 1, procedure(I: Integer)
  begin
    FCheckingsList[I].Path := '';
    FCheckingsList[I].Mask := '';
    FCheckingsList[I].Recursive := False;
    if Assigned(FCheckingsList[I].Exclusives) then
    begin
      FCheckingsList[I].Exclusives.Clear;
      FreeAndNil(FCheckingsList[I].Exclusives);
    end;
  end);
end;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

procedure TFilesValidator.ClearFilesLists;
begin
  FErrorFiles.Clear;
  FAbsentFiles.Clear;
end;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

procedure TFilesValidator.ClearValidFilesList;
begin
  FValidFiles.Clear;
end;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

procedure TFilesValidator.Clear;
begin
  StopFoldersWatching;
  ClearFilesLists;
  ClearValidFilesList;
  ClearCheckingsList;
end;

end.
