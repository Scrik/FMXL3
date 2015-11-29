program MojangParser;

uses
  Vcl.Forms,
  Main in 'Main.pas' {MainForm},
  StringsAPI in 'StringsAPI.pas',
  JSONUtils in 'JSONUtils.pas';

{$R *.res}

{$WEAKLINKRTTI ON}
{$RTTI EXPLICIT METHODS([]) PROPERTIES([]) FIELDS([])}
{$SETPEFLAGS
  $0001 or (* IMAGE_FILE_RELOCS_STRIPPED         *)
  $0004 or (* IMAGE_FILE_LINE_NUMS_STRIPPED      *)
  $0008 or (* IMAGE_FILE_LOCAL_SYMS_STRIPPED     *)
  $0020 or (* IMAGE_FILE_LARGE_ADDRESS_AWARE     *)
  $0200 or (* IMAGE_FILE_DEBUG_STRIPPED          *)
  $0400 or (* IMAGE_FILE_REMOVABLE_RUN_FROM_SWAP *)
  $0800    (* IMAGE_FILE_NET_RUN_FROM_SWAP       *)
}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TMainForm, MainForm);
  Application.Run;
end.
