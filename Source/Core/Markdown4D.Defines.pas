unit Markdown4D.Defines;

{$SCOPEDENUMS ON}

interface

uses
  System.SysUtils;

type
  TMarkdownDialect = (CommonMark, Gfm);

  EMarkdownError = class(Exception);

  EMarkdownNotImplemented = class(EMarkdownError);

implementation

end.
