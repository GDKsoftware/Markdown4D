object Markdown4DStudioVCLForm: TMarkdown4DStudioVCLForm
  Left = 0
  Top = 0
  Caption = 'Markdown4D Studio'
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
  OnCloseQuery = HandleCloseQuery
  OnKeyDown = HandleFormKeyDown
  OnResize = HandleResize
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
    object edtFind: TEdit
      AlignWithMargins = True
      Left = 1036
      Top = 4
      Width = 160
      Height = 28
      Align = alRight
      TabOrder = 0
      TextHint = 'Find'
      OnChange = HandlePreviewFindChange
      OnKeyPress = HandleFindEditKeyPress
    end
    object lblPreviewFindCount: TLabel
      AlignWithMargins = True
      Left = 1020
      Top = 3
      Width = 10
      Height = 30
      Margins.Right = 6
      Align = alRight
      Caption = 'lblPreviewFindCount'
      Layout = tlCenter
    end
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
      TextHint = 'Find in editor'
      OnChange = HandleEditorFindChange
      ExplicitLeft = 4
      ExplicitTop = 4
      ExplicitHeight = 24
    end
    object edtEditorReplace: TEdit
      Left = 240
      Top = 0
      Width = 240
      Height = 32
      Align = alLeft
      TabOrder = 1
      TextHint = 'Replace with'
    end
    object btnReplace: TButton
      Left = 480
      Top = 0
      Width = 90
      Height = 32
      Align = alLeft
      Caption = 'Replace'
      TabOrder = 2
      OnClick = HandleReplaceClick
    end
    object btnReplaceAll: TButton
      Left = 570
      Top = 0
      Width = 110
      Height = 32
      Align = alLeft
      Caption = 'Replace All'
      TabOrder = 3
      OnClick = HandleReplaceAllClick
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
      AlignWithMargins = True
      Left = 8
      Top = 0
      Width = 160
      Height = 22
      Margins.Left = 8
      Margins.Top = 0
      Margins.Right = 0
      Margins.Bottom = 0
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
      AlignWithMargins = True
      Left = 176
      Top = 0
      Width = 160
      Height = 22
      Margins.Left = 8
      Margins.Top = 0
      Margins.Right = 0
      Margins.Bottom = 0
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
      AlignWithMargins = True
      Left = 4
      Top = 20
      Width = 232
      Height = 618
      Margins.Left = 4
      Margins.Top = 20
      Margins.Right = 4
      Margins.Bottom = 4
      Align = alClient
      BorderStyle = bsNone
      ItemHeight = 15
      TabOrder = 0
      OnClick = HandleTocListClick
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
    ShowLineNumbers = True
    Preview = mdPreview
    OnChange = HandleEditorChange
    OnSyncScroll = HandleSyncScroll
  end
  object mdPreview: TMarkdownViewer
    Left = 728
    Top = 96
    Width = 472
    Height = 642
    Align = alClient
    TabOrder = 6
    TabStop = True
    OnLinkClick = HandlePreviewLinkClick
  end
  object pnlPalette: TPanel
    Left = 320
    Top = 80
    Width = 560
    Height = 243
    BevelKind = bkFlat
    BevelOuter = bvNone
    ShowCaption = False
    TabOrder = 7
    Visible = False
    object edtPalette: TEdit
      Left = 0
      Top = 0
      Width = 556
      Height = 23
      Align = alTop
      TabOrder = 0
      TextHint = 'Type a command'
      OnChange = HandlePaletteChange
    end
    object lstPalette: TListBox
      Left = 0
      Top = 23
      Width = 556
      Height = 216
      Style = lbOwnerDrawFixed
      Align = alClient
      BorderStyle = bsNone
      ItemHeight = 22
      TabOrder = 1
      OnDblClick = HandlePaletteDblClick
      OnDrawItem = HandlePaletteDrawItem
    end
  end
  object dlgOpen: TOpenDialog
    Filter = 'Markdown files (*.md)|*.md|All files (*.*)|*.*'
    Left = 900
    Top = 120
  end
  object dlgSave: TSaveDialog
    DefaultExt = 'md'
    Filter = 'Markdown files (*.md)|*.md|All files (*.*)|*.*'
    Left = 960
    Top = 120
  end
  object dlgSaveHtml: TSaveDialog
    DefaultExt = 'html'
    Filter = 'HTML files (*.html)|*.html|All files (*.*)|*.*'
    Left = 1020
    Top = 120
  end
  object tmrTick: TTimer
    Enabled = False
    Interval = 100
    OnTimer = HandleTick
    Left = 900
    Top = 180
  end
  object popRecent: TPopupMenu
    AutoHotkeys = maManual
    Left = 960
    Top = 180
  end
end
