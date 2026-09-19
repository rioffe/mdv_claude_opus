# mdv6 Help

mdv6 reads Markdown the way a good document viewer reads a PDF: typographically deliberate, fast to open, with the navigation aids a long technical document needs. It never edits your files.

## Opening files

- **File → Open…** (⌘O) opens a file into this window; **Open in New Window…** (⌘⇧O) opens a second window.
- Double-click a `.md`, `.markdown` or `.mdown` file in Finder, drag one onto the icon, or drop it onto the window (`.txt` and `.mkd` are accepted for drops).
- From the terminal: `mdv6 FILE…` opens each file (the last is displayed), `mdv6 DIR` opens a directory (`README.md` or the first Markdown file, the rest listed in history), `echo '# hi' | mdv6 -` opens standard input, `mdv6 --version` prints the version. Install the tool once with **mdv6 → Install Command Line Tool…**.
- A file that is not valid UTF-8 or cannot be read leaves the window unchanged.

## Moving around

- The **history sidebar** (⌃⌘S to show or hide, or the chevron on its divider) lists every file you opened, most recent first, up to 100. Swipe a row to remove it.
- The **inspector** (⌥⌘0, or the toolbar's right-sidebar button) shows the table of contents and the bookmarks. Click a heading to jump; the magnifier filters headings.
- **Back / Forward** (⌘← / ⌘→) walk the places you have been, including jumps within a document.
- Links to local Markdown files open in mdv6; every other link (web, other file types, missing files) goes to the system.
- Click a heading to copy its whole section as Markdown; the section flashes. Drag across a paragraph to select text and ⌘C to copy it.
- Zoom with ⌘= and ⌘-, reset with **View → Actual Size**.

## Find

- **⌘F** opens the in-document find bar: matches are counted as occurrences, ⌘G and ⇧⌘G step through them (wrapping), Esc closes. Code, math and table blocks are tinted as a whole; other blocks highlight each occurrence.
- **⌘⇧F** searches every file in history through the full-text index: type a few word prefixes, pick a result to open it. ⌘F while the history sidebar has focus does the same.

## Bookmarks

- **⌘D** bookmarks the paragraph under the pointer (or the topmost visible one), titled by the nearest heading; the new row is shown in the inspector's Bookmarks pane and marked current. The first five bookmarks answer to ⌘1…⌘5.
- Right-click a bookmark for **Go to Bookmark**, **Reveal in Finder**, the four **Move** items and **Remove Bookmark**; drag rows to reorder. A bookmark whose file has moved is marked and beeps when opened.
- **⌘⇧0** sets a temporary placeholder at the current spot (shown first in the bookmarks pane with a `⌘0` badge); **⌘0** returns to it, even from another file. Right-click it for **Clear Placeholder**. Placeholders do not survive a relaunch.

## Sidebars

- Section headers (**HISTORY**, **ON THIS PAGE**, **BOOKMARKS**) each carry a magnifier that reveals a search or filter field; Esc hides it again.
- The **BOOKMARKS** header collapses the pane; drag the divider above it to resize. Drag the sidebar's divider (180–400 pt) and the inspector's left edge (180–520 pt) to resize them; the inspector's width and visibility are remembered.

## Diagrams and math

- ` ```mermaid ` fences render natively (flowcharts, state, sequence, class, ER and XY charts). Hover a diagram for its style menu (Document, Light, Dark, Tokyo Night, Catppuccin), **Show Mermaid source**, **Export diagram as PNG** and copy; pinch to zoom. Diagram types the renderer lacks show their source with a note.
- LaTeX between `$…$` (inline) and `$$…$$` (display) is typeset natively in paragraphs, headings, lists, quotes and tables; display math on its own line is centred and offers **Copy LaTeX**. LaTeX the typesetter rejects is shown as source with the parser's message.
- Fenced code is highlighted for C, C++ (and Metal), Go, Rust, Bash, JavaScript, YAML, TOML, Python, Ruby, Swift, SQL, OpenCL, JSON, Lua, Perl and Markdown; hover a block to wrap long lines or copy it, and right-click a shell block for **Copy Without Prompts**.

## Editor integration

- **⌘E** opens the current file in your editor; choose it under **File → Edit → Choose Editor…** (and forget it there). Saves are picked up live: the page reloads and keeps your place.

## Appearance

- Pick a theme from the palette button in the toolbar: High Contrast, Sevilla, Charcoal, Solarium Daylight, Solarium Moonlight, Phosphor, Twilight, Standard Erin Light, Standard Erin Dark, or **System** (High Contrast in Light, Twilight in Dark).
- **View → Smart Typography** curls quotes and dashes in prose (some themes opt out). **View → Load Remote Images** allows `http(s)` images, which are otherwise shown as a placeholder.
