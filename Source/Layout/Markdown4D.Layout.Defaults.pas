unit Markdown4D.Layout.Defaults;

{$SCOPEDENUMS ON}

interface

const
  // Shared viewer/editor defaults, framework-neutral: the VCL and FMX
  // implementations must stay in lockstep on these values.
  ReferencePixelsPerInch = 96;
  WheelLinesPerNotch = 3;
  MouseWheelDeltaPerNotch = 120;
  ScrollLineDips = 40;
  TextLeftPaddingDips = 6;
  GutterPaddingDips = 8;
  CaretWidthDips = 1;
  FlushTimerIntervalMilliseconds = 25;
  AutoScrollIntervalMilliseconds = 50;
  PreviewDebounceIntervalMilliseconds = 60;

  // Font family mapping shared by the VCL and FMX painters
  MonospaceFamilyName = 'monospace';
  SansSerifFamilyName = 'sans-serif';
  SerifFamilyName = 'serif';
  MonospaceFallbackFamilyName = 'Consolas';
  SerifFallbackFamilyName = 'Georgia';
  DefaultFallbackFamilyName = 'Segoe UI';

  ColorChannelMax = 255;

  UnbalancedRestoreMessage = 'RestoreState called without a matching SaveState';

implementation

end.
