# Code folding showcase

Click the triangles in the editor **gutter** (left) to fold. Nested headings
fold down to the next heading of equal or higher level; fenced code blocks fold
from the opening fence to the close. Folds survive typing and are revealed
automatically when a find match lands inside them.

## 1. Introduction

Some introductory text spanning a couple of lines so the section has content to
hide when it is collapsed. Try collapsing this whole section with the triangle
next to the heading above.

### 1.1 Background

Background details live here, nested one level deeper. Collapsing section 1 hides
this sub-section too.

### 1.2 Goals

- Fold heading sections
- Fold fenced code blocks
- Keep fold state across edits

## 2. Code examples

A Pascal snippet — fold it from its opening fence:

```pascal
procedure TDemo.Run;
begin
  for var Index := 0 to 9 do
  begin
    WriteLn('Line ', Index);
  end;
end;
```

A JSON snippet:

```json
{
  "name": "Markdown4D",
  "features": ["parser", "viewer", "editor"],
  "folding": true
}
```

## 3. Conclusion

Everything below a heading folds into it. Collapse sections 1, 2 and 3 to get a
one-line-per-section outline of the document.
