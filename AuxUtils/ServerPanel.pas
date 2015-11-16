unit ServerPanel;

interface

uses
  SysUtils, Classes, System.UITypes,
  FMX.Types, FMX.Objects, FMX.StdCtrls, FMX.Ani, FMX.Effects, FMX.Controls;

type
  TServerPanel = class
    public type
      TOnClick = reference to procedure(const Sender: TServerPanel);
      TServerPanelSample = record
        ServerPanel    : TPanel;
        NameLabel      : TLabel;
        InfoLabel      : TLabel;
        ProgressBar    : TProgressBar;
        PreviewImage   : TImage;
        MonitoringLamp : TCircle;
        MonitoringInfo : TLabel;
        PreviewShadowEffect : TShadowEffect;
        LampGlowEffect      : TGlowEffect;
        PauseButton : TPath;
        StopButton  : TRectangle;
        PauseButtonGlowEffect : TGlowEffect;
        StopButtonGlowEffect  : TGlowEffect;
      end;
    private const
      Offset: Single = 5.0;

      BackgroundAnimationDuration : Single = 0.15;

      BackgroundDisabledOpacity : Single = 0.5;
      BackgroundNormalOpacity   : Single = 0.7;
      BackgroundHoveredOpacity  : Single = 0.95;
      BackgroundSelectedOpacity : Single = 1.0;

      LightBlinkDuration  : Single = 0.4;

      LampBrightnessStart : Single = 1.0;
      LampBrightnessStop  : Single = 0.2;

      LampNeutralColor    : TAlphaColor = $FFDDDDDD;

      LampGoodColorStart  : TAlphaColor = $FF00FF00;
      LampGoodColorStop   : TAlphaColor = $FF00AA00;

      LampBadColorStart   : TAlphaColor = $FFFF0000;
      LampBadColorStop    : TAlphaColor = $FFAA0000;

      PauseColor  : TAlphaColor = $FFFFE506;
      ResumeColor : TAlphaColor = $FF00FF00;
      StopColor   : TAlphaColor = $FFFF0000;

      PauseButtonSVG  : string = 'M0,0 L0.375,0 L0.375,1 L0,1 L0,0 M0.625,1 L0.625,0 L1,0 L1,1 L0.625,1';
      ResumeButtonSVG : string = 'M0,0 L0,1 L1,0.5 L0,0';

    private type
      TServerPanelContent = record
        ServerPanel    : TPanel;
        NameLabel      : TLabel;
        InfoLabel      : TLabel;
        ProgressBar    : TProgressBar;
        PreviewImage   : TImage;
        MonitoringLamp : TCircle;
        MonitoringInfo : TLabel;
        BackgroundOpacityAnimation: TFloatAnimation;
        PreviewShadowEffect  : TShadowEffect;
        LampGlowEffect       : TGlowEffect;
        LampOpacityAnimation : TFloatAnimation;
        LampColorAnimation   : TColorAnimation;
        PauseButton : TPath;
        StopButton  : TRectangle;
        PauseButtonGlowEffect : TGlowEffect;
        StopButtonGlowEffect  : TGlowEffect;
      end;
      INTERNAL_CONTROL_TYPE = (ctlNone, ctlPauseButton, ctlStopButton);
    private
      FContent: TServerPanelContent;
      FNumber: Integer;
      FOnClick: TOnClick;
      FOnDblClick: TOnClick;
      FOnPauseClick: TOnClick;
      FOnStopClick: TOnClick;
      FControlType: INTERNAL_CONTROL_TYPE;
      FResumeState: Boolean;
      procedure CopyBasicProperties(const Src, Dest: TControl);
      procedure CopyPanel(const Src, Dest: TPanel);
      procedure CopyLabel(const Src, Dest: TLabel);
      procedure CopyImage(const Src, Dest: TImage);
      procedure CopyShape(const Src, Dest: TShape);
      procedure CopyProgressBar(const Src, Dest: TProgressBar);
      procedure CopyShadowEffect(const Src, Dest: TShadowEffect);
      procedure CopyGlowEffect(const Src, Dest: TGlowEffect);
      //procedure CopyColorAnimation(const Src, Dest: TColorAnimation);
      //procedure CopyFloatAnimation(const Src, Dest: TFloatAnimation);
      procedure OnPanelClick(Sender: TObject);
      procedure OnPanelDblClick(Sender: TObject);
      procedure OnPanelMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Single);
      procedure OnPanelMouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Single);
      function IsCoordInRegion(const X, Y: Single; const Control: TControl): Boolean;
      procedure SetOnClick(const Value: TOnClick);
    public
      property Content: TServerPanelContent read FContent;
      property Number: Integer read FNumber;
      property ResumeState: Boolean read FResumeState default False;
      property OnClick: TOnClick read FOnClick write SetOnClick;
      property OnDblClick: TOnClick read FOnDblClick write FOnDblClick;
      property OnPauseClick: TOnClick read FOnPauseClick write FOnPauseClick;
      property OnStopClick: TOnClick read FOnStopClick write FOnStopClick;

      constructor Create(const Parent: TFMXObject; const Sample: TServerPanelSample; Number: Integer);
      destructor Destroy; override;

      procedure SetDisabledView;
      procedure SetNormalView;
      procedure SetHoveredView;
      procedure SetSelectedView;

      procedure ShowDownloadPanel;
      procedure HideDownloadPanel;

      procedure EnableDownloadButtons;
      procedure DisableDownloadButtons;

      procedure ShowPauseButton;
      procedure ShowResumeButton;

      procedure SetLightColor(Color: TAlphaColor);
      procedure SetNeutralLight;
      procedure SetGoodLight;
      procedure SetBadLight;
      procedure Blink(StartColor, StopColor: TAlphaColor; const Duration: Single = 0.2);
      procedure BlinkGood;
      procedure BlinkBad;
  end;

implementation

{ TServerPanel }

constructor TServerPanel.Create(const Parent: TFMXObject;
  const Sample: TServerPanelSample; Number: Integer);
begin
  FNumber := Number;

  // Подложка:
  FContent.ServerPanel := TPanel.Create(Parent);
  FContent.ServerPanel.Parent := Parent;
  FContent.ServerPanel.BeginUpdate;
  CopyPanel(Sample.ServerPanel, FContent.ServerPanel);
  FContent.ServerPanel.Opacity := BackgroundNormalOpacity;
  FContent.ServerPanel.Position.Y := Sample.ServerPanel.Position.Y + (Sample.ServerPanel.Height + Offset) * FNumber;
  FContent.ServerPanel.OnClick := OnPanelClick;
  FContent.ServerPanel.OnDblClick := OnPanelDblClick;
  FContent.ServerPanel.OnMouseDown := OnPanelMouseDown;
  FContent.ServerPanel.OnMouseUp := OnPanelMouseUp;

  // Анимация подложки:
  FContent.BackgroundOpacityAnimation := TFloatAnimation.Create(FContent.ServerPanel);
  FContent.BackgroundOpacityAnimation.Parent := FContent.ServerPanel;
  FContent.BackgroundOpacityAnimation.Duration := BackgroundAnimationDuration;
  FContent.BackgroundOpacityAnimation.StartValue := BackgroundNormalOpacity;
  FContent.BackgroundOpacityAnimation.StopValue := BackgroundHoveredOpacity;
  FContent.BackgroundOpacityAnimation.PropertyName := 'Opacity';
  FContent.BackgroundOpacityAnimation.Trigger        := 'IsMouseOver=true';
  FContent.BackgroundOpacityAnimation.TriggerInverse := 'IsMouseOver=false';

  // Имя сервера:
  FContent.NameLabel := TLabel.Create(FContent.ServerPanel);
  FContent.NameLabel.Parent := FContent.ServerPanel;
  CopyLabel(Sample.NameLabel, FContent.NameLabel);

  // Информация о сервере:
  FContent.InfoLabel := TLabel.Create(FContent.ServerPanel);
  FContent.InfoLabel.Parent := FContent.ServerPanel;
  CopyLabel(Sample.InfoLabel, FContent.InfoLabel);

  // Прогрессбар:
  FContent.ProgressBar := TProgressBar.Create(FContent.ServerPanel);
  FContent.ProgressBar.Parent := FContent.ServerPanel;
  CopyProgressBar(Sample.ProgressBar, FContent.ProgressBar);

  // Превью:
  FContent.PreviewImage := TImage.Create(FContent.ServerPanel);
  FContent.PreviewImage.Parent := FContent.ServerPanel;
  CopyImage(Sample.PreviewImage, FContent.PreviewImage);

  // Тень от превью:
  FContent.PreviewShadowEffect := TShadowEffect.Create(FContent.PreviewImage);
  FContent.PreviewShadowEffect.Parent := FContent.PreviewImage;
  CopyShadowEffect(Sample.PreviewShadowEffect, FContent.PreviewShadowEffect);

  // Лампочка:
  FContent.MonitoringLamp := TCircle.Create(FContent.ServerPanel);
  FContent.MonitoringLamp.Parent := FContent.ServerPanel;
  CopyShape(Sample.MonitoringLamp, FContent.MonitoringLamp);

  // Свечение от лампочки:
  FContent.LampGlowEffect := TGlowEffect.Create(FContent.MonitoringLamp);
  FContent.LampGlowEffect.Parent := FContent.MonitoringLamp;
  CopyGlowEffect(Sample.LampGlowEffect, FContent.LampGlowEffect);

  // Анимация смены цвета:
  FContent.LampColorAnimation := TColorAnimation.Create(FContent.MonitoringLamp);
  FContent.LampColorAnimation.Parent := FContent.MonitoringLamp;
  FContent.LampColorAnimation.Duration := LightBlinkDuration;
  FContent.LampColorAnimation.PropertyName := 'Fill.Color';

  // Анимация свечения:
  FContent.LampOpacityAnimation := TFloatAnimation.Create(FContent.LampGlowEffect);
  FContent.LampOpacityAnimation.Parent := FContent.LampGlowEffect;
  FContent.LampOpacityAnimation.Duration := LightBlinkDuration;
  FContent.LampOpacityAnimation.StartValue := LampBrightnessStart;
  FContent.LampOpacityAnimation.StopValue := LampBrightnessStop;
  FContent.LampOpacityAnimation.PropertyName := 'Opacity';

  // Информация мониторинга:
  FContent.MonitoringInfo := TLabel.Create(FContent.ServerPanel);
  FContent.MonitoringInfo.Parent := FContent.ServerPanel;
  CopyLabel(Sample.MonitoringInfo, FContent.MonitoringInfo);

  // Кнопка паузы:
  FContent.PauseButton := TPath.Create(FContent.ServerPanel);
  FContent.PauseButton.Parent := FContent.ServerPanel;
  CopyShape(Sample.PauseButton, FContent.PauseButton);
  FContent.PauseButton.Data.Data := PauseButtonSVG;
  FContent.PauseButton.Fill.Color := PauseColor;
  FContent.PauseButton.Cursor := crHandPoint;
  FContent.PauseButton.HitTest := False;

  // Свечение кнопки паузы:
  FContent.PauseButtonGlowEffect := TGlowEffect.Create(FContent.PauseButton);
  FContent.PauseButtonGlowEffect.Parent := FContent.PauseButton;
  CopyGlowEffect(Sample.PauseButtonGlowEffect, FContent.PauseButtonGlowEffect);

  // Кнопка стопа:
  FContent.StopButton := TRectangle.Create(FContent.ServerPanel);
  FContent.StopButton.Parent := FContent.ServerPanel;
  CopyShape(Sample.StopButton, FContent.StopButton);
  FContent.StopButton.Fill.Color := StopColor;
  FContent.StopButton.Cursor := crHandPoint;
  FContent.StopButton.HitTest := False;

  // Свечение кнопки стопа:
  FContent.StopButtonGlowEffect := TGlowEffect.Create(FContent.StopButton);
  FContent.StopButtonGlowEffect.Parent := FContent.StopButton;
  CopyGlowEffect(Sample.StopButtonGlowEffect, FContent.StopButtonGlowEffect);

  HideDownloadPanel;
  SetNeutralLight;

  FContent.ServerPanel.EndUpdate;
end;

destructor TServerPanel.Destroy;
begin
  FreeAndNil(FContent.ServerPanel);
  inherited;
end;



procedure TServerPanel.SetOnClick(const Value: TOnClick);
begin
  FOnClick := Value;
end;



function TServerPanel.IsCoordInRegion(const X, Y: Single;
  const Control: TControl): Boolean;
begin
  Result := Control.Visible and Control.Enabled and
            (X >= Control.Position.X) and
            (X < Control.Position.X + Control.Width) and
            (Y >= Control.Position.Y) and
            (Y < Control.Position.Y + Control.Height);
end;

procedure TServerPanel.OnPanelMouseDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Single);
begin
  if IsCoordInRegion(X, Y, FContent.PauseButton) then
  begin
    FControlType := ctlPauseButton;
    Exit;
  end;

  if IsCoordInRegion(X, Y, FContent.StopButton) then
  begin
    FControlType := ctlStopButton;
    Exit;
  end;

  FControlType := ctlNone;
end;

procedure TServerPanel.OnPanelMouseUp(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Single);
begin
  if FControlType = ctlNone then Exit;

  case FControlType of
    ctlPauseButton:
      if IsCoordInRegion(X, Y, FContent.PauseButton) then
        if Assigned(FOnPauseClick) then FOnPauseClick(Self);

    ctlStopButton:
      if IsCoordInRegion(X, Y, FContent.StopButton) then
        if Assigned(FOnStopClick) then FOnStopClick(Self);
  end;
end;



procedure TServerPanel.OnPanelClick(Sender: TObject);
begin
  if FControlType <> ctlNone then Exit;
  if Assigned(FOnClick) then FOnClick(Self);
end;



procedure TServerPanel.OnPanelDblClick(Sender: TObject);
begin
  if FControlType <> ctlNone then Exit;
  if Assigned(FOnDblClick) then FOnDblClick(Self);
end;


procedure TServerPanel.CopyBasicProperties(const Src, Dest: TControl);
begin
  Dest.Enabled  := Src.Enabled;
  Dest.Visible  := Src.Visible;
  Dest.Position := Src.Position;
  Dest.Width    := Src.Width;
  Dest.Height   := Src.Height;
  Dest.HitTest  := Src.HitTest;
  Dest.Opacity  := Src.Opacity;
end;

procedure TServerPanel.CopyImage(const Src, Dest: TImage);
begin
  CopyBasicProperties(Src, Dest);
  Dest.MarginWrapMode := Src.MarginWrapMode;
  Dest.WrapMode := Src.WrapMode;
  Dest.Bitmap.Assign(Src.Bitmap);
end;

procedure TServerPanel.CopyLabel(const Src, Dest: TLabel);
begin
  CopyBasicProperties(Src, Dest);
  Dest.TextSettings   := Src.TextSettings;
  Dest.StyledSettings := Src.StyledSettings;
end;

procedure TServerPanel.CopyPanel(const Src, Dest: TPanel);
begin
  CopyBasicProperties(Src, Dest);
end;

procedure TServerPanel.CopyProgressBar(const Src, Dest: TProgressBar);
begin
  CopyBasicProperties(Src, Dest);
end;

procedure TServerPanel.CopyShape(const Src, Dest: TShape);
begin
  CopyBasicProperties(Src, Dest);
  Dest.Fill := Src.Fill;
  Dest.Stroke := Src.Stroke;
end;

procedure TServerPanel.CopyShadowEffect(const Src, Dest: TShadowEffect);
begin
  Dest.Enabled   := Src.Enabled;
  Dest.Opacity   := Src.Opacity;
  Dest.Softness  := Src.Softness;
  Dest.Direction := Src.Direction;
  Dest.Distance  := Src.Distance;
end;

procedure TServerPanel.CopyGlowEffect(const Src, Dest: TGlowEffect);
begin
  Dest.Enabled   := Src.Enabled;
  Dest.Opacity   := Src.Opacity;
  Dest.Softness  := Src.Softness;
  Dest.GlowColor := Src.GlowColor;
end;


{
procedure TServerPanel.CopyColorAnimation(const Src, Dest: TColorAnimation);
begin
  Dest.Enabled        := Src.Enabled;
  Dest.StartValue     := Src.StartValue;
  Dest.StopValue      := Src.StopValue;
  Dest.PropertyName   := Src.PropertyName;
  Dest.Duration       := Src.Duration;
  Dest.Trigger        := Src.Trigger;
  Dest.TriggerInverse := Src.TriggerInverse;
end;

procedure TServerPanel.CopyFloatAnimation(const Src, Dest: TFloatAnimation);
begin
  Dest.Enabled        := Src.Enabled;
  Dest.StartValue     := Src.StartValue;
  Dest.StopValue      := Src.StopValue;
  Dest.PropertyName   := Src.PropertyName;
  Dest.Duration       := Src.Duration;
  Dest.Trigger        := Src.Trigger;
  Dest.TriggerInverse := Src.TriggerInverse;
end;
}


procedure TServerPanel.SetLightColor(Color: TAlphaColor);
begin
  FContent.MonitoringLamp.BeginUpdate;
  FContent.MonitoringLamp.Fill.Color := Color;
  FContent.LampGlowEffect.GlowColor := Color;
  FContent.MonitoringLamp.EndUpdate;
  FContent.MonitoringLamp.Repaint;
end;

procedure TServerPanel.SetNeutralLight;
begin
  SetLightColor(LampNeutralColor);
  FContent.LampGlowEffect.GlowColor := $00000000;
end;

procedure TServerPanel.SetGoodLight;
begin
  SetLightColor(LampGoodColorStart);
end;

procedure TServerPanel.SetBadLight;
begin
  SetLightColor(LampBadColorStart);
end;


procedure TServerPanel.Blink(StartColor, StopColor: TAlphaColor; const Duration: Single = 0.2);
begin
  FContent.MonitoringLamp.BeginUpdate;

  FContent.MonitoringLamp.Fill.Color := StartColor;
  FContent.LampGlowEffect.GlowColor  := StartColor;

  FContent.LampColorAnimation.StartValue := StartColor;
  FContent.LampColorAnimation.StopValue  := StopColor;
  FContent.LampGlowEffect.GlowColor      := StartColor;

  FContent.LampColorAnimation.Duration   := Duration;
  FContent.LampOpacityAnimation.Duration := Duration;

  FContent.MonitoringLamp.EndUpdate;

  FContent.LampColorAnimation.Start;
  FContent.LampOpacityAnimation.Start;
end;

procedure TServerPanel.BlinkGood;
begin
  Blink(LampGoodColorStart, LampGoodColorStop, LightBlinkDuration);
end;

procedure TServerPanel.BlinkBad;
begin
  Blink(LampBadColorStart, LampBadColorStop, LightBlinkDuration);
end;



procedure TServerPanel.SetDisabledView;
begin
  FContent.ServerPanel.BeginUpdate;
  FContent.ServerPanel.HitTest := False;
  FContent.BackgroundOpacityAnimation.StartValue := BackgroundDisabledOpacity;
  FContent.BackgroundOpacityAnimation.StopValue  := BackgroundDisabledOpacity;
  FContent.ServerPanel.Opacity := BackgroundDisabledOpacity;
  FContent.ServerPanel.EndUpdate;
  FContent.ServerPanel.Repaint;
end;

procedure TServerPanel.SetHoveredView;
begin
  FContent.ServerPanel.BeginUpdate;
  FContent.ServerPanel.HitTest := True;
  FContent.BackgroundOpacityAnimation.StartValue := BackgroundNormalOpacity;
  FContent.BackgroundOpacityAnimation.StopValue  := BackgroundHoveredOpacity;
  FContent.ServerPanel.Opacity := BackgroundHoveredOpacity;
  FContent.ServerPanel.EndUpdate;
  FContent.ServerPanel.Repaint;
end;

procedure TServerPanel.SetNormalView;
begin
  FContent.ServerPanel.BeginUpdate;
  FContent.ServerPanel.HitTest := True;
  FContent.BackgroundOpacityAnimation.StartValue := BackgroundNormalOpacity;
  FContent.BackgroundOpacityAnimation.StopValue  := BackgroundHoveredOpacity;
  FContent.ServerPanel.Opacity := BackgroundNormalOpacity;
  FContent.ServerPanel.EndUpdate;
  FContent.ServerPanel.Repaint;
end;

procedure TServerPanel.SetSelectedView;
begin
  FContent.ServerPanel.BeginUpdate;
  FContent.ServerPanel.HitTest := True;
  FContent.BackgroundOpacityAnimation.StartValue := BackgroundSelectedOpacity;
  FContent.BackgroundOpacityAnimation.StopValue  := BackgroundSelectedOpacity;
  FContent.ServerPanel.Opacity := BackgroundSelectedOpacity;
  FContent.ServerPanel.EndUpdate;
  FContent.ServerPanel.Repaint;
end;



procedure TServerPanel.EnableDownloadButtons;
begin
  FContent.ServerPanel.BeginUpdate;
  FContent.PauseButton.Enabled := True;
  FContent.StopButton.Enabled := True;
  FContent.ServerPanel.EndUpdate;
  FContent.ServerPanel.Repaint;
end;

procedure TServerPanel.DisableDownloadButtons;
begin
  FContent.ServerPanel.BeginUpdate;
  FContent.PauseButton.Enabled := False;
  FContent.StopButton.Enabled := False;
  FContent.ServerPanel.EndUpdate;
  FContent.ServerPanel.Repaint;
end;



procedure TServerPanel.HideDownloadPanel;
begin
  FContent.ServerPanel.BeginUpdate;
  FContent.ProgressBar.Visible := False;
  FContent.PauseButton.Visible := False;
  FContent.StopButton.Visible  := False;
  FContent.ServerPanel.EndUpdate;
  FContent.ServerPanel.Repaint;
end;

procedure TServerPanel.ShowDownloadPanel;
begin
  FContent.ServerPanel.BeginUpdate;
  FContent.ProgressBar.Visible := True;
  FContent.PauseButton.Visible := True;
  FContent.StopButton.Visible  := True;
  FContent.ServerPanel.EndUpdate;
  FContent.ServerPanel.Repaint;
end;



procedure TServerPanel.ShowPauseButton;
begin
  FContent.ServerPanel.BeginUpdate;
  FContent.PauseButton.Data.Data := PauseButtonSVG;
  FContent.PauseButton.Fill.Color := PauseColor;
  FContent.PauseButtonGlowEffect.GlowColor := PauseColor;
  FResumeState := False;
  FContent.ServerPanel.EndUpdate;
  FContent.ServerPanel.Repaint;
end;

procedure TServerPanel.ShowResumeButton;
begin
  FContent.ServerPanel.BeginUpdate;
  FContent.PauseButton.Data.Data := ResumeButtonSVG;
  FContent.PauseButton.Fill.Color := ResumeColor;
  FContent.PauseButtonGlowEffect.GlowColor := ResumeColor;
  FResumeState := True;
  FContent.ServerPanel.EndUpdate;
  FContent.ServerPanel.Repaint;
end;

end.
