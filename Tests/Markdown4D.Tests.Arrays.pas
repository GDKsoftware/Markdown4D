unit Markdown4D.Tests.Arrays;

{$SCOPEDENUMS ON}

interface

type
  TTestArray = class
  public
    // Length is a 64-bit value on a 64-bit target, so comparing it against an
    // Integer literal leaves Assert.AreEqual without an overload it can infer.
    class function CountOf<T>(const Values: array of T): Integer;
  end;

implementation

class function TTestArray.CountOf<T>(const Values: array of T): Integer;
begin
  Result := Integer(Length(Values));
end;

end.
