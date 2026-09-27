# Raw HTML images

GitHub sanitises HTML and renders `<img>` tags, so READMEs reach for them
for what Markdown cannot express — most often a sized header image. mdv has
no HTML renderer, so `RawHTMLImages` rewrites each `<img>` tag into an image
reference its own providers understand, carrying the size the tag asked for.
Everything else in the HTML is left alone and keeps printing as text.

## A sized header, the README pattern

<img src="../MDV6.png" alt="mdv" width="320">

## Width, height, and neither

Width only, so the height follows the aspect:

<img src="../MDV6.png" alt="width only" width="180">

Both, which fit inside the pair without stretching:

<img src="../MDV6.png" alt="bounded" width="240" height="80">

A lone height, deriving the width:

<img src="../MDV6.png" alt="height only" height="60">

No attributes at all: the image's own size, which the column may shrink.

<img src="../MDV6.png" alt="natural size">

## Inline, in the middle of a sentence

This paragraph has one in it — <img src="../MDV6.png" alt="inline" width="120">
— and the image sits on the text's baseline: its line grows to the image's
height, and no text wraps around it, both on screen and in print.

A plain Markdown image inline works the same way: ![small icon](assets/local.png)
sits in this sentence, and prints.

## Quotes

Single quotes work: <img src='../MDV6.png' alt='single' width="100">.

Bare attribute values work too: <img src=../MDV6.png alt=bare width=90>.

## Failures and non-images

As a block of its own, a missing file shows its alt text:

<img src="nope.png" alt="missing file" width="200">

Inline, a missing file is left out of the line, so these parentheses stay
empty: (<img src="nope.png" alt="missing inline" width="200">).

Remote sources go through the same gate as any other remote image. This one
is served locally — run `python3 -m http.server 8765` in `test-docs/assets/`
— so the test never depends on a third-party URL. With View → Load Remote
Images off it shows the blocked placeholder; with it on and the server
running it loads; with it on and the server stopped it shows the failure
placeholder:

<img src="http://127.0.0.1:8765/local.png" alt="served locally" width="120">

## What must stay literal

A fenced block keeps its HTML as HTML:

```
<img src="not-an-image.png" width="320">
```

Inline code keeps it too: `<img src="also-not-an-image.png">`.

An `<a>` tag is not an image tag and renders as text: <a href="#">a link</a>.

## Where this specification departs from the original

The cases below follow SPEC.md, not the original at `68aa008`, so the
reference image `reference/ORIGINAL-RAW-HTML-IMAGES.png` stops above this
section.

A `>` inside a quoted value does not end the tag (C-22.1):
<img src="../MDV6.png" alt="a > b" width="60">

An inline remote image, in the middle of this sentence, is gated like a block
one: <img src="http://127.0.0.1:8765/local.png" alt="inline remote" width="40">
shows the non-clickable inline *Remote image blocked* text while View → Load
Remote Images is off (R-16, C-22.2).

### Logo <img src="../MDV6.png" alt="logo" width="20">

The heading above renders its image, and its TOC row reads `Logo` (C-12 step 0).
