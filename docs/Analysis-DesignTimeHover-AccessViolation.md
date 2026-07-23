# Access Violation on design-time hover over the Markdown viewer

_Analysis date: 2026-07-23 — branch `main`_

## Symptom

An `Access violation at address ... in module 'rtl370.bpl' ... Read of address 002E005D`
is raised inside the RAD Studio IDE (`bds.exe`) when the mouse hovers over rendered
markdown in the **VCL `TMarkdownViewer` at design time**.

Reported call stack (top frames, decoded):

```
System.@UStrAsg                                   (System.pas, string assignment)
Markdown4D.Vcl.Viewer.TMarkdownViewer.TryFindLinkUrl      (Viewer.pas:709)
Markdown4D.Vcl.Viewer.TMarkdownViewer.SetHoveredLinkUrl   (Viewer.pas:695)
Markdown4D.Vcl.Viewer.TMarkdownViewer.UpdateHoverCursor   (Viewer.pas:687)
Markdown4D.Vcl.Viewer.TMarkdownViewer.MouseMove           (Viewer.pas:517)
Vcl.Controls.TControl.WMMouseMove ...
```

The remaining frames are ordinary VCL message dispatch (`WndProc` → `ControlAtPos` →
`WMMouseMove`) plus `IDEVirtualTrees`/`TApplication.Run`, i.e. the IDE pumping a mouse
message into the live design-time control.

## Where it crashes

`Source/Vcl/Markdown4D.Vcl.Viewer.pas`:

```pascal
function TMarkdownViewer.TryFindLinkUrl(const Point: TLayoutPointF; out Url: string): Boolean;
begin
  Url := '';
  if FModel.DisplayList = nil then
    Exit(False);

  var Link: IMarkdownLink;
  Result := TMarkdownHitTester.TryFindLink(FModel.DisplayList, Point, Link);
  if Result then
    Url := Link.Destination;   // <-- AV here (line 709): @UStrAsg copies a dangling string
end;
```

`TMarkdownHitTester.TryFindLink` iterated the display list, found a display item whose
`Node.Kind = Link`, and did `Supports(Node, IMarkdownLink, Link)`. Reading
`Link.Destination` (`TMarkdownLinkNode.GetDestination` → `Result := FDestination`) then
dereferenced a **freed/garbage string pointer**. The low fault address (`002E005D`) and
the fact that the crash is the *string copy* (`@UStrAsg`) — not the interface call itself —
is the classic signature of a **use-after-free**: the node's early bytes (its `Kind`) still
read as a plausible value, but `FDestination` further inside the object already points at
released memory.

## Why this only shows up at design time

This path is design-time specific by construction:

1. `TMarkdownViewer.Paint` calls `EnsureDesignSample`
   (`Source/Vcl/Markdown4D.Vcl.Viewer.pas:405`), which — only when
   `csDesigning in ComponentState` — injects sample markdown:

   ```pascal
   FModel.Text := TMarkdownDesignSample.Markdown;
   ```

2. That sample (`Source/Layout/Markdown4D.DesignSample.pas`) **contains a link**:

   ```
   [GDK Software](https://github.com/GDKsoftware/Markdown4D).
   ```

   So at design time there is always a hyperlink under the cursor to hit-test.

3. `TMarkdownViewer.MouseMove` (`:495`) runs the **full** hover/hit-test pipeline
   (`UpdateCodeHover` → `PointOnCopyButton` → `UpdateHoverCursor` → `TryFindLinkUrl`)
   with **no `csDesigning` guard**. At runtime you only hit this if your own document
   contains a link and you hover it; at design time it is guaranteed as soon as you move
   the mouse across the injected sample.

So the trigger ("moved the mouse over the markdown in the designer") maps exactly onto
this call chain.

## Root cause (assessment)

The dereferenced `IMarkdownLink` is an AST node reached through
`FModel.DisplayList`. Every layer on the *reference-holding* side looks correct:

- Display items (`TDisplayItem`/`TDisplayTextRun`, `Source/Layout/Markdown4D.Layout.Primitives.pas`)
  hold `FNode: IMarkdownNode` as a **strong** interface reference.
- `TMarkdownViewerModel.GetDisplayList` returns the current `FDisplayList`, rebuilt
  synchronously on the main thread in `Relayout` (`Source/Layout/Markdown4D.Viewer.Model.pas:492`).

A strongly-referenced node reached from a freshly, synchronously built list should not
dangle — which means something is **freeing an AST node out from under a display item
that still references it**. The prime structural suspect is the hand-rolled node teardown:

`TMarkdownAstNode.ReleaseChildrenIteratively` (`Source/Core/Markdown4D.Ast.pas:150`):

```pascal
const Current = Pending.List[LastIndex] as TMarkdownAstNode;
const DiesOnRelease = (Current.RefCount = 1);
if DiesOnRelease then
begin
  Pending.AddRange(Current.FChildren);
  Current.FChildren.Clear;
end;
Pending.Delete(LastIndex);
```

This iterative destructor (written to avoid deep-recursion stack overflows) reasons about
lifetime via `RefCount`. It is correct for a strict tree, but it is fragile if the inline
parser ever produces a node instance that is referenced from **more than one place**
(shared/reparented inline nodes, or a node kept alive by a display item while its parent
subtree is being torn down): a node can then be visited/flattened along one path and freed
while another owner (a display item) still points at it. That is precisely the corruption
shape the crash exhibits. This is the leading hypothesis, not yet proven at the free site.

Contributing factor: the viewer performs full hit-testing and hover state changes at
design time. Even once the lifetime bug is fixed, running link hit-testing against
IDE-injected sample content is unnecessary risk surface.

## Reproduction

1. Open a form/frame that hosts a VCL `TMarkdownViewer` in the RAD Studio designer.
2. Let it paint (the design sample with the "GDK Software" link renders).
3. Move the mouse across the link text.
4. AV in `rtl370.bpl` via `TryFindLinkUrl` → `Link.Destination`.

## Recommended next steps

1. **Confirm the free site.** Build the design-time package / a test host with FastMM4 in
   `FullDebugMode`, hover to trigger, and read the "freed block" allocation/free stacks.
   This pins whether `ReleaseChildrenIteratively` (or a relayout replacing the list) is the
   actual free.
2. **Immediate mitigation — guard hover at design time.** Skip the hit-test pipeline when
   `csDesigning in ComponentState` in `MouseMove` (VCL and, for symmetry, FMX). The design
   sample never needs live link/copy-button hover.
3. **Structural fix — node lifetime.** Re-verify `ReleaseChildrenIteratively` against
   multiply-referenced inline nodes; add a DUnitX test that parses a document with links,
   holds the produced display list, releases the source `Document`, and then reads
   `Link.Destination` from the retained display item (this is exactly what hover does after
   a relayout). If that test AVs, the iterative teardown is confirmed as the cause.
4. **Regression guard.** Add a hit-test test that reproduces the design-sample hover
   (parse `TMarkdownDesignSample.Markdown`, hit-test over the link bounds, read the URL).

## Files referenced

- `Source/Vcl/Markdown4D.Vcl.Viewer.pas` — `MouseMove`, `UpdateHoverCursor`,
  `SetHoveredLinkUrl`, `TryFindLinkUrl`, `EnsureDesignSample`
- `Source/Layout/Markdown4D.Layout.HitTest.pas` — `TMarkdownHitTester.TryFindLink`
- `Source/Layout/Markdown4D.Layout.Primitives.pas` — display items hold `FNode` strongly
- `Source/Layout/Markdown4D.Viewer.Model.pas` — `Relayout`, `GetDisplayList`, `SetText`
- `Source/Core/Markdown4D.Ast.pas` — `TMarkdownAstNode.ReleaseChildrenIteratively`,
  `TMarkdownLinkNode.GetDestination`
- `Source/Layout/Markdown4D.DesignSample.pas` — sample markdown injected at design time
