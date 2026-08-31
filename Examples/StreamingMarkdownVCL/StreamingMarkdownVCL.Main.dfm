object StreamingMarkdownVCLForm: TStreamingMarkdownVCLForm
  Left = 0
  Top = 0
  Caption = 'Markdown4D LLM Chat Demo'
  ClientHeight = 680
  ClientWidth = 760
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  Position = poScreenCenter
  TextHeight = 15
  object sbxMessages: TScrollBox
    Left = 0
    Top = 0
    Width = 760
    Height = 636
    VertScrollBar.Tracking = True
    Align = alClient
    BorderStyle = bsNone
    TabOrder = 0
  end
  object pnlInput: TPanel
    Left = 0
    Top = 636
    Width = 760
    Height = 44
    Align = alBottom
    BevelOuter = bvNone
    Caption = 'pnlInput'
    ShowCaption = False
    TabOrder = 1
    object edtPrompt: TEdit
      AlignWithMargins = True
      Left = 8
      Top = 8
      Width = 656
      Height = 28
      Margins.Left = 8
      Margins.Top = 8
      Margins.Right = 8
      Margins.Bottom = 8
      Align = alClient
      TabOrder = 0
      TextHint = 'Ask something...'
      OnKeyPress = HandlePromptKeyPress
    end
    object btnSend: TButton
      AlignWithMargins = True
      Left = 672
      Top = 8
      Width = 80
      Height = 28
      Margins.Left = 0
      Margins.Top = 8
      Margins.Right = 8
      Margins.Bottom = 8
      Align = alRight
      Caption = 'Send'
      TabOrder = 1
      OnClick = HandleSendClick
    end
  end
  object tmrStream: TTimer
    Enabled = False
    Interval = 30
    OnTimer = HandleStreamTimer
    Left = 44
    Top = 44
  end
  object tmrLayout: TTimer
    Interval = 100
    OnTimer = HandleLayoutTimer
    Left = 108
    Top = 44
  end
end
