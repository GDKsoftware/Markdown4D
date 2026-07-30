unit Markdown4D.Image.Svg.Path.Tests;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TSvgPathParserTests = class
  private
    const
      Tolerance = 0.001;

  public
    [Test]
    procedure Parse_AbsoluteLines_FollowTheCoordinatesGiven;

    [Test]
    procedure Parse_RelativeLines_AreTakenFromTheCurrentPoint;

    [Test]
    procedure Parse_ClosePath_MarksTheSubPathClosed;

    [Test]
    procedure Parse_SecondPairAfterMoveTo_DrawsALine;

    [Test]
    procedure Parse_HorizontalAndVertical_KeepTheOtherAxis;

    [Test]
    procedure Parse_Cubic_StaysWithinItsControlPolygon;

    [Test]
    procedure Parse_Arc_EndsOnItsEndpoint;

    [Test]
    procedure Parse_SeparateMoveTos_ProduceSeparateSubPaths;

    [Test]
    procedure Parse_NumbersRunTogether_AreStillSeparated;

    [Test]
    procedure Parse_Empty_ProducesNothing;
  end;

implementation

uses
  System.SysUtils,
  System.Math,
  Markdown4D.Layout.Interfaces,
  Markdown4D.Image.Svg.Path;

procedure TSvgPathParserTests.Parse_AbsoluteLines_FollowTheCoordinatesGiven;
begin
  const Paths = TSvgPathParser.Parse('M 10 20 L 30 40');

  Assert.AreEqual(1, Length(Paths));
  Assert.AreEqual(2, Length(Paths[0].Points));
  Assert.AreEqual(10.0, Paths[0].Points[0].X, Tolerance);
  Assert.AreEqual(20.0, Paths[0].Points[0].Y, Tolerance);
  Assert.AreEqual(30.0, Paths[0].Points[1].X, Tolerance);
  Assert.AreEqual(40.0, Paths[0].Points[1].Y, Tolerance);
end;

procedure TSvgPathParserTests.Parse_RelativeLines_AreTakenFromTheCurrentPoint;
begin
  const Paths = TSvgPathParser.Parse('M 10 10 l 5 0 l 0 5');

  Assert.AreEqual(3, Length(Paths[0].Points));
  Assert.AreEqual(15.0, Paths[0].Points[1].X, Tolerance);
  Assert.AreEqual(10.0, Paths[0].Points[1].Y, Tolerance);
  Assert.AreEqual(15.0, Paths[0].Points[2].X, Tolerance);
  Assert.AreEqual(15.0, Paths[0].Points[2].Y, Tolerance);
end;

procedure TSvgPathParserTests.Parse_ClosePath_MarksTheSubPathClosed;
begin
  const Paths = TSvgPathParser.Parse('M 0 0 L 10 0 L 10 10 Z');

  Assert.AreEqual(1, Length(Paths));
  Assert.IsTrue(Paths[0].IsClosed, 'Z closes the sub-path');
end;

// Coordinates that follow a moveto without a command of their own draw lines.
procedure TSvgPathParserTests.Parse_SecondPairAfterMoveTo_DrawsALine;
begin
  const Paths = TSvgPathParser.Parse('M 0 0 10 0 10 10');

  Assert.AreEqual(1, Length(Paths));
  Assert.AreEqual(3, Length(Paths[0].Points));
  Assert.AreEqual(10.0, Paths[0].Points[2].Y, Tolerance);
end;

procedure TSvgPathParserTests.Parse_HorizontalAndVertical_KeepTheOtherAxis;
begin
  const Paths = TSvgPathParser.Parse('M 5 5 H 25 V 15');

  Assert.AreEqual(25.0, Paths[0].Points[1].X, Tolerance);
  Assert.AreEqual(5.0, Paths[0].Points[1].Y, Tolerance);
  Assert.AreEqual(25.0, Paths[0].Points[2].X, Tolerance);
  Assert.AreEqual(15.0, Paths[0].Points[2].Y, Tolerance);
end;

// A flattened curve has to stay inside the box its control points span, and it
// has to arrive exactly at its endpoint.
procedure TSvgPathParserTests.Parse_Cubic_StaysWithinItsControlPolygon;
begin
  const Paths = TSvgPathParser.Parse('M 0 0 C 0 50 100 50 100 0');

  Assert.IsTrue(Length(Paths[0].Points) > 4, 'A curve is flattened into several points');

  for var Point in Paths[0].Points do
  begin
    Assert.IsTrue((Point.X >= -Tolerance) and (Point.X <= 100 + Tolerance),
      Format('X %.3f left the control polygon', [Point.X]));
    Assert.IsTrue((Point.Y >= -Tolerance) and (Point.Y <= 50 + Tolerance),
      Format('Y %.3f left the control polygon', [Point.Y]));
  end;

  const Last = Paths[0].Points[High(Paths[0].Points)];
  Assert.AreEqual(100.0, Last.X, 0.01);
  Assert.AreEqual(0.0, Last.Y, 0.01);
end;

procedure TSvgPathParserTests.Parse_Arc_EndsOnItsEndpoint;
begin
  const Paths = TSvgPathParser.Parse('M 0 0 A 50 50 0 0 1 100 0');

  const Last = Paths[0].Points[High(Paths[0].Points)];
  Assert.AreEqual(100.0, Last.X, 0.05);
  Assert.AreEqual(0.0, Last.Y, 0.05);
  Assert.IsTrue(Length(Paths[0].Points) > 8, 'An arc is flattened into several points');
end;

procedure TSvgPathParserTests.Parse_SeparateMoveTos_ProduceSeparateSubPaths;
begin
  const Paths = TSvgPathParser.Parse('M 0 0 L 10 0 M 20 0 L 30 0');

  Assert.AreEqual(2, Length(Paths));
  Assert.AreEqual(20.0, Paths[1].Points[0].X, Tolerance);
end;

// A minus sign is a separator of its own, and so is a second decimal point.
procedure TSvgPathParserTests.Parse_NumbersRunTogether_AreStillSeparated;
begin
  const Paths = TSvgPathParser.Parse('M0 0L10-5');

  Assert.AreEqual(2, Length(Paths[0].Points));
  Assert.AreEqual(10.0, Paths[0].Points[1].X, Tolerance);
  Assert.AreEqual(-5.0, Paths[0].Points[1].Y, Tolerance);
end;

procedure TSvgPathParserTests.Parse_Empty_ProducesNothing;
begin
  Assert.AreEqual(0, Length(TSvgPathParser.Parse('')));
  Assert.AreEqual(0, Length(TSvgPathParser.Parse('   ')));
  Assert.AreEqual(0, Length(TSvgPathParser.Parse('M 10 10')));
end;

end.
