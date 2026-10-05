unit Markdown4D.Editor.PreviewPacer;

{$SCOPEDENUMS ON}

interface

type
  // How long the editor waits after the last edit before it updates its
  // preview. A preview that updates quickly follows the typing closely; one
  // that takes long, for a large document, waits for a longer pause, so the
  // update does not land between two keystrokes and stall the typing.
  TMarkdownPreviewPacer = record
  public
    const
      ShortestDelayMilliseconds = 60;
      LongestDelayMilliseconds = 1500;
      DelayPerUpdateMillisecond = 4;

  private
    FLastUpdateMilliseconds: Int64;

  public
    procedure UpdateTook(const Milliseconds: Int64);
    function DelayMilliseconds: Integer;
  end;

implementation

uses
  System.Math;

procedure TMarkdownPreviewPacer.UpdateTook(const Milliseconds: Int64);
begin
  FLastUpdateMilliseconds := Milliseconds;
end;

function TMarkdownPreviewPacer.DelayMilliseconds: Integer;
begin
  const Scaled = FLastUpdateMilliseconds * DelayPerUpdateMillisecond;
  Result := EnsureRange(Scaled, ShortestDelayMilliseconds, LongestDelayMilliseconds);
end;

end.
