object MainForm: TMainForm
  Left = 0
  Top = 0
  BorderIcons = [biSystemMenu]
  BorderStyle = bsSingle
  Caption = 'Mojang JSONs Parser for the FMXL Project'
  ClientHeight = 455
  ClientWidth = 426
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  OldCreateOrder = False
  PixelsPerInch = 96
  TextHeight = 13
  object Label1: TLabel
    Left = 15
    Top = 80
    Width = 73
    Height = 13
    Caption = '"arguments" : "'
  end
  object Label2: TLabel
    Left = 407
    Top = 80
    Width = 4
    Height = 13
    Caption = '"'
  end
  object Label3: TLabel
    Left = 15
    Top = 107
    Width = 73
    Height = 13
    Caption = '"main_class" : "'
  end
  object Label4: TLabel
    Left = 407
    Top = 107
    Width = 4
    Height = 13
    Caption = '"'
  end
  object Label5: TLabel
    Left = 15
    Top = 134
    Width = 57
    Height = 13
    Caption = '"version" : "'
  end
  object Label6: TLabel
    Left = 407
    Top = 134
    Width = 4
    Height = 13
    Caption = '"'
  end
  object Label7: TLabel
    Left = 15
    Top = 161
    Width = 80
    Height = 13
    Caption = '"asset_index" : "'
  end
  object Label8: TLabel
    Left = 407
    Top = 161
    Width = 4
    Height = 13
    Caption = '"'
  end
  object Label9: TLabel
    Left = 15
    Top = 197
    Width = 40
    Height = 13
    Caption = '"jars" : ['
  end
  object Label10: TLabel
    Left = 15
    Top = 431
    Width = 4
    Height = 13
    Caption = ']'
  end
  object MojangJSONPathEdit: TEdit
    Left = 13
    Top = 17
    Width = 373
    Height = 21
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clWindowText
    Font.Height = -11
    Font.Name = 'Calibri'
    Font.Style = []
    ParentFont = False
    TabOrder = 0
  end
  object SelectMojangJSONButton: TButton
    Left = 387
    Top = 15
    Width = 26
    Height = 25
    Caption = '...'
    TabOrder = 1
    OnClick = SelectMojangJSONButtonClick
  end
  object FullPathRadioButton: TRadioButton
    Left = 15
    Top = 48
    Width = 85
    Height = 17
    Caption = #1055#1086#1083#1085#1099#1077' '#1087#1091#1090#1080
    Checked = True
    TabOrder = 2
    TabStop = True
  end
  object NamesOnlyRadioButton: TRadioButton
    Left = 108
    Top = 48
    Width = 136
    Height = 17
    Caption = #1058#1086#1083#1100#1082#1086' '#1080#1084#1077#1085#1072' '#1092#1072#1081#1083#1086#1074
    TabOrder = 3
  end
  object ParseJSONButton: TButton
    Left = 249
    Top = 43
    Width = 164
    Height = 25
    Caption = #1056#1072#1079#1086#1073#1088#1072#1090#1100' JSON'
    TabOrder = 4
    OnClick = ParseJSONButtonClick
  end
  object FilesMemo: TMemo
    Left = 15
    Top = 216
    Width = 396
    Height = 209
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clWindowText
    Font.Height = -11
    Font.Name = 'Calibri'
    Font.Style = []
    ParentFont = False
    ScrollBars = ssBoth
    TabOrder = 5
  end
  object ArgumentsEdit: TEdit
    Left = 94
    Top = 77
    Width = 307
    Height = 21
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clWindowText
    Font.Height = -11
    Font.Name = 'Calibri'
    Font.Style = []
    ParentFont = False
    TabOrder = 6
  end
  object MainClassEdit: TEdit
    Left = 94
    Top = 104
    Width = 307
    Height = 21
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clWindowText
    Font.Height = -11
    Font.Name = 'Calibri'
    Font.Style = []
    ParentFont = False
    TabOrder = 7
  end
  object VersionEdit: TEdit
    Left = 78
    Top = 131
    Width = 323
    Height = 21
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clWindowText
    Font.Height = -11
    Font.Name = 'Calibri'
    Font.Style = []
    ParentFont = False
    TabOrder = 8
  end
  object AssetIndexEdit: TEdit
    Left = 101
    Top = 158
    Width = 300
    Height = 21
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clWindowText
    Font.Height = -11
    Font.Name = 'Calibri'
    Font.Style = []
    ParentFont = False
    TabOrder = 9
  end
end
