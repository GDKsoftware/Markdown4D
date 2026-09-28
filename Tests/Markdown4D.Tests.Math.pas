unit Markdown4D.Tests.Math;

{$SCOPEDENUMS ON}

interface

type
  TNestedFormula = class
  public
    const
      // Opening and closing, comma separated, as a TestCase argument.
      Groups = '{,}';
      Fractions = '\frac{1}{,}';
      Primes = ',''';

    // Opening repeated Depth times, then x, then Closing repeated Depth
    // times: "{{x}}" for a depth of two groups.
    class function Build(const Opening, Closing: string; const Depth: Integer): string;
  end;

implementation

uses
  System.SysUtils,
  System.StrUtils;

class function TNestedFormula.Build(const Opening, Closing: string; const Depth: Integer): string;
begin
  const Openings = DupeString(Opening, Depth);
  const Closings = DupeString(Closing, Depth);

  Result := Format('%sx%s', [Openings, Closings]);
end;

end.
