object MarkdownPadVCLForm: TMarkdownPadVCLForm
  Left = 0
  Top = 0
  Caption = 'Markdown4D Pad'
  ClientHeight = 760
  ClientWidth = 1200
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  KeyPreview = True
  Position = poScreenCenter
  TextHeight = 15
  object splToc: TSplitter
    Left = 240
    Top = 96
    Width = 4
    Height = 642
  end
  object splMain: TSplitter
    Left = 724
    Top = 96
    Width = 4
    Height = 642
  end
  object pnlToolbar: TPanel
    Left = 0
    Top = 0
    Width = 1200
    Height = 36
    Align = alTop
    BevelOuter = bvNone
    Caption = 'pnlToolbar'
    ParentBackground = False
    ShowCaption = False
    TabOrder = 0
    ExplicitWidth = 1198
  end
  object pnlFind: TPanel
    Left = 0
    Top = 64
    Width = 1200
    Height = 32
    Align = alTop
    BevelOuter = bvNone
    Caption = 'pnlFind'
    ShowCaption = False
    TabOrder = 2
    Visible = False
    ExplicitWidth = 1198
    object lblFindCount: TLabel
      Left = 1131
      Top = 0
      Width = 69
      Height = 32
      Align = alRight
      Caption = 'lblFindCount'
      Layout = tlCenter
      ExplicitLeft = 1140
      ExplicitTop = 4
      ExplicitHeight = 15
    end
    object edtEditorFind: TEdit
      Left = 0
      Top = 0
      Width = 240
      Height = 32
      Align = alLeft
      TabOrder = 0
      Text = 'edtEditorFind'
      TextHint = 'Find in editor'
      ExplicitLeft = 4
      ExplicitTop = 4
      ExplicitHeight = 24
    end
  end
  object pnlStatus: TPanel
    Left = 0
    Top = 738
    Width = 1200
    Height = 22
    Align = alBottom
    BevelOuter = bvNone
    Caption = 'pnlStatus'
    ParentBackground = False
    ShowCaption = False
    TabOrder = 3
    ExplicitTop = 730
    ExplicitWidth = 1198
    object lblPos: TLabel
      Left = 0
      Top = 0
      Width = 32
      Height = 22
      Align = alLeft
      AutoSize = False
      Caption = 'lblPos'
      Transparent = True
      Layout = tlCenter
      ExplicitLeft = 8
      ExplicitTop = 4
      ExplicitHeight = 15
    end
    object lblWords: TLabel
      Left = 32
      Top = 0
      Width = 47
      Height = 22
      Align = alLeft
      AutoSize = False
      Caption = 'lblWords'
      Transparent = True
      Layout = tlCenter
      ExplicitLeft = 176
      ExplicitTop = 4
      ExplicitHeight = 15
    end
  end
  object pnlToc: TPanel
    Left = 0
    Top = 96
    Width = 240
    Height = 642
    Align = alLeft
    Alignment = taLeftJustify
    BevelOuter = bvNone
    Caption = 'Contents'
    ParentBackground = False
    TabOrder = 4
    VerticalAlignment = taAlignTop
    ExplicitHeight = 634
    object lstToc: TListBox
      Left = 0
      Top = 0
      Width = 240
      Height = 642
      Align = alClient
      BorderStyle = bsNone
      ItemHeight = 15
      TabOrder = 0
      ExplicitHeight = 634
    end
  end
  object mdEditor: TMarkdownEditor
    Left = 244
    Top = 96
    Width = 480
    Height = 642
    Align = alLeft
    TabOrder = 5
    TabStop = True
  end
  object mdPreview: TMarkdownViewer
    Left = 728
    Top = 96
    Width = 472
    Height = 642
    Align = alClient
    TabOrder = 6
    TabStop = True
  end
  object dlgOpen: TOpenDialog
    Left = 900
    Top = 120
  end
  object dlgSave: TSaveDialog
    Left = 960
    Top = 120
  end
  object dlgSaveHtml: TSaveDialog
    Left = 1020
    Top = 120
  end
  object tmrTick: TTimer
    Left = 900
    Top = 180
  end
  object popRecent: TPopupMenu
    Left = 960
    Top = 180
  end
end
