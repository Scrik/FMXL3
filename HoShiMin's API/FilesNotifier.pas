unit FilesNotifier;

interface

uses
  Windows, SysUtils, Classes, ShlwAPI, StringsAPI;

const
  FULL_NOTIFY_FILTER = FILE_NOTIFY_CHANGE_FILE_NAME  or
                       FILE_NOTIFY_CHANGE_DIR_NAME   or
                       FILE_NOTIFY_CHANGE_ATTRIBUTES or
                       FILE_NOTIFY_CHANGE_SIZE       or
                       FILE_NOTIFY_CHANGE_LAST_WRITE or
                       FILE_NOTIFY_CHANGE_SECURITY;

type
  FILE_ACTION = (
    FILE_ACTION_ADDED = 1,
    FILE_ACTION_REMOVED,
    FILE_ACTION_MODIFIED,
    FILE_ACTION_RENAMED_OLD_NAME, // В FileName - старое имя файла
    FILE_ACTION_RENAMED_NEW_NAME  // В FileName - новое имя файла
  );

  TFileChangesInfo = record
    FileName : string;
    Action   : FILE_ACTION;
  end;

  TNotifyStruct = record
    ChangesCount : LongWord;
    Changes      : array of TFileChangesInfo;
  end;

  TFilesNotifier = class
    public type
      TOnDirChange = reference to procedure(const FilesNotifier: TFilesNotifier; const NotifyStruct: TNotifyStruct);
    private const
      BufferSize = 8192;
    private
      FBaseFolder: string;
      FFilesTypes: TStringArray;
      FExclusivesTypes: TStringArray;
      FFilesTypesCount: Integer;
      FExclusivesTypesCount: Integer;
      FDirHandle: THandle;
      FWatcherHandle: THandle;
      FOnDirChange: TOnDirChange;
      function OpenFolder(const Directory: string): THandle;
    public
      property OnDirChange: TOnDirChange read FOnDirChange write FOnDirChange;
      property BaseFolder: string read FBaseFolder;

      constructor Create(const Directory: string; const FilesTypes: string = ''; const ExclusivesTypes: string = '');
      destructor Destroy; override;

      procedure StartWatching(WatchSubfolders: Boolean = True; NotifyFilter: LongWord = FULL_NOTIFY_FILTER);
      procedure StopWatching;
  end;

implementation

type
  FILE_NOTIFY_INFORMATION = record
    NextEntryOffset : LongWord;
    Action          : LongWord;
    FileNameLength  : LongWord;
    FileName        : WideChar;
  end;
  PFILE_NOTIFY_INFORMATION = ^FILE_NOTIFY_INFORMATION;

function CancelIoEx(hFile: THandle; lpOverlapped: POverlapped): LongBool; stdcall; external 'kernel32.dll';

{ TFilesNotifier }



constructor TFilesNotifier.Create(const Directory: string; const FilesTypes: string = ''; const ExclusivesTypes: string = '');
begin
  FWatcherHandle := 0;
  SetLength(FFilesTypes, 0);
  FFilesTypesCount := 0;
  FOnDirChange := nil;

  FBaseFolder := Directory;
  FDirHandle := OpenFolder(FBaseFolder);
  FFilesTypesCount := ParseDelimiteredData(FilesTypes, ',', FFilesTypes);
  FExclusivesTypesCount := ParseDelimiteredData(ExclusivesTypes, ',', FExclusivesTypes);
end;

destructor TFilesNotifier.Destroy;
begin
  StopWatching;
  if (FDirHandle <> 0) and (FDirHandle <> INVALID_HANDLE_VALUE) then CloseHandle(FDirHandle);
  inherited;
end;


function TFilesNotifier.OpenFolder(const Directory: string): THandle;
begin
  Result := CreateFile(
                        PChar('\\?\' + Directory),
                        FILE_LIST_DIRECTORY,
                        FILE_SHARE_READ or FILE_SHARE_WRITE or FILE_SHARE_DELETE,
                        nil,
                        OPEN_EXISTING,
                        FILE_FLAG_BACKUP_SEMANTICS,
                        0
                       );
end;



procedure TFilesNotifier.StartWatching(WatchSubfolders: Boolean = True; NotifyFilter: LongWord = FULL_NOTIFY_FILTER);
var
  WatcherThread: TThread;
begin
  StopWatching;

  WatcherThread := TThread.CreateAnonymousThread(procedure
  var
    Buffer: Pointer;
    BytesReturned: LongWord;
    FileNotifyInformation: PFILE_NOTIFY_INFORMATION;
    NotifyStruct: TNotifyStruct;
    FileName: string;
    I, J: Integer;
    NeedToAdd: Boolean;
  begin
    GetMem(Buffer, BufferSize);
    FillChar(Buffer^, BufferSize, #0);

    while ReadDirectoryChanges(FDirHandle, Buffer, BufferSize, WatchSubfolders, NotifyFilter, @BytesReturned, nil, nil) do
    begin
      FileNotifyInformation := Buffer;

      NotifyStruct.ChangesCount := 0;
      SetLength(NotifyStruct.Changes, 0);

      if BytesReturned <> 0 then
      repeat
        if FileNotifyInformation.FileNameLength > 0 then
        begin
          SetLength(FileName, FileNotifyInformation.FileNameLength div SizeOf(WideChar));
          Move(FileNotifyInformation.FileName, FileName[1], FileNotifyInformation.FileNameLength);

          NeedToAdd := True;
          if FFilesTypesCount > 0 then
          begin
            NeedToAdd := False;

            // Проверяем маску:
            for I := 0 to FFilesTypesCount - 1 do if PathMatchSpec(PChar(FileName), PChar(FFilesTypes[I])) then
            begin
              NeedToAdd := True;

              // Проверяем исключения:
              if FExclusivesTypesCount > 0 then for J := 0 to FExclusivesTypesCount - 1 do
              begin
                if PathMatchSpec(PChar(FileName), PChar(FExclusivesTypes[J])) then
                begin
                  NeedToAdd := False;
                  Break;
                end;
              end;

              Break;
            end;
          end;

          if NeedToAdd then
          begin
            Inc(NotifyStruct.ChangesCount);
            SetLength(NotifyStruct.Changes, NotifyStruct.ChangesCount);
            NotifyStruct.Changes[NotifyStruct.ChangesCount - 1].FileName := FileName;
            NotifyStruct.Changes[NotifyStruct.ChangesCount - 1].Action := FILE_ACTION(FileNotifyInformation.Action);
          end;
        end;

        FileNotifyInformation := Pointer(NativeUInt(FileNotifyInformation) + FileNotifyInformation.NextEntryOffset);
      until FileNotifyInformation.NextEntryOffset = 0;

      if (NotifyStruct.ChangesCount > 0) and Assigned(FOnDirChange) then
        TThread.Synchronize(TThread.CurrentThread, procedure
        begin
          FOnDirChange(Self, NotifyStruct);
        end);

      FillChar(Buffer^, BufferSize, #0);
    end;

    SetLength(NotifyStruct.Changes, 0);
    FreeMem(Buffer);
  end);
  WatcherThread.FreeOnTerminate := True;
  WatcherThread.Priority := tpLower;
  FWatcherHandle := WatcherThread.Handle;
  WatcherThread.Start;
end;

procedure TFilesNotifier.StopWatching;
begin
  //if (FDirHandle <> 0) and (FDirHandle <> INVALID_HANDLE_VALUE) then CancelIoEx(FDirHandle, nil);
  WaitForSingleObject(FWatcherHandle, INFINITE);
  FWatcherHandle := 0;
end;

end.
