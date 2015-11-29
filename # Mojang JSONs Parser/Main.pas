unit Main;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, StringsAPI, System.JSON, JSONUtils;

type
  TMainForm = class(TForm)
    MojangJSONPathEdit: TEdit;
    SelectMojangJSONButton: TButton;
    FullPathRadioButton: TRadioButton;
    NamesOnlyRadioButton: TRadioButton;
    ParseJSONButton: TButton;
    FilesMemo: TMemo;
    Label1: TLabel;
    ArgumentsEdit: TEdit;
    Label2: TLabel;
    Label3: TLabel;
    MainClassEdit: TEdit;
    Label4: TLabel;
    Label5: TLabel;
    VersionEdit: TEdit;
    Label6: TLabel;
    Label7: TLabel;
    AssetIndexEdit: TEdit;
    Label8: TLabel;
    Label9: TLabel;
    Label10: TLabel;
    procedure SelectMojangJSONButtonClick(Sender: TObject);
    procedure ParseJSONButtonClick(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  MainForm: TMainForm;

implementation

{$R *.dfm}

procedure TMainForm.SelectMojangJSONButtonClick(Sender: TObject);
var
  OpenDialog: TOpenDialog;
begin
  OpenDialog := TOpenDialog.Create(Self);
  OpenDialog.Filter := '*.json|*.json';
  if OpenDialog.Execute then
  begin
    MojangJSONPathEdit.Text := OpenDialog.FileName;
  end;
  FreeAndNil(OpenDialog);
end;


procedure TMainForm.ParseJSONButtonClick(Sender: TObject);

  function MavenToPath(const MavenPath: string; NamesOnly: Boolean = False): string; //inline;
  var
    FixedMaven, Path, Name, Version, FileName: string;
  begin
    FixedMaven := ReplaceParam(MavenPath, ':', '\');

    Version := ExtractFileName(FixedMaven);
    Name    := ExtractFileName(ExtractFileDir(FixedMaven));
    Path    := ExtractFilePath(FixedMaven);

    FileName := Name + '-' + Version + '.jar';
    if NamesOnly then Exit(FileName);

    Result := ReplaceParam(Path, '.', '\') + Version + '\' + FileName;
  end;

var
  JSONStream: TStringStream;
  JSON: TJSONObject;
  LibrariesArray: TJSONArray;
  LibraryEntry, Natives: TJSONObject;
  I: Integer;
  Version: string;
begin
  if not FileExists(MojangJSONPathEdit.Text) then
  begin
    MessageBox(Handle, 'Файл не найден!', 'Ошибка!', MB_ICONERROR);
    Exit;
  end;

  JSONStream := TStringStream.Create;
  JSONStream.LoadFromFile(MojangJSONPathEdit.Text);
  JSON := JSONStringToJSONObject(JSONStream.DataString);
  FreeAndNil(JSONStream);
  if JSON = nil then
  begin
    MessageBox(Handle, 'Файл имеет некорректную JSON-структуру!', 'Ошибка!', MB_ICONERROR);
    Exit;
  end;

  ArgumentsEdit.Text  := GetJSONStringValue(JSON, 'minecraftArguments');
  MainClassEdit.Text  := GetJSONStringValue(JSON, 'mainClass');
  VersionEdit.Text    := GetJSONStringValue(JSON, 'jar');
  AssetIndexEdit.Text := GetJSONStringValue(JSON, 'assets');

  // Получаем список библиотек из JSON'а:
  FilesMemo.Clear;
  LibrariesArray := GetJSONArrayValue(JSON, 'libraries');
  if LibrariesArray.Count > 0 then
  begin
    FilesMemo.Lines.BeginUpdate;
    for I := 0 to LibrariesArray.Count - 1 do
    begin
      LibraryEntry := GetJSONArrayElement(LibrariesArray, I);

      // Исключаем джарники-контейнеры для нативок:
      if not GetJSONObjectValue(LibraryEntry, 'natives', Natives) then
        FilesMemo.Lines.Add('{"name" : "libraries\' + MavenToPath(GetJSONStringValue(LibraryEntry, 'name'), NamesOnlyRadioButton.Checked) + '"},');
    end;
  end;

  Version := GetJSONStringValue(JSON, 'id');
  FilesMemo.Lines.Add('{"name" : "versions\' + Version + '\' + Version + '.jar"}');
  FilesMemo.Text := ReplaceParam(FilesMemo.Text, '\', '/');
  FilesMemo.Lines.EndUpdate;
end;

end.
