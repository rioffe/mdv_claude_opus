# mdv6 Help

mdv6 reads Markdown the way a good document viewer reads a PDF: typographically deliberate, fast to open, with the navigation aids a long technical document needs. It never edits your files.

## Opening files

- **File → Open…** (⌘O) opens a file into this window; **Open in New Window…** (⌘⇧O) opens a second window.
- Double-click a `.md`, `.markdown` or `.mdown` file in Finder, drag one onto the icon, or drop it onto the window (`.txt` and `.mkd` are accepted for drops).
- From the terminal: `mdv6 FILE…` opens each file (the last is displayed), `mdv6 DIR` opens a directory (`README.md` or the first Markdown file, the rest listed in history), `echo '# hi' | mdv6 -` opens standard input, `mdv6 --version` prints the version. Install the tool once with **mdv6 → Install Command Line Tool…**.
- A file that is not valid UTF-8 or cannot be read leaves the window unchanged.
- **⌘W** closes the current file — it leaves the history list and the next file takes its place. **⇧⌘W** closes the window (mdv6 keeps running; open a file and a window comes back). **⌥⌘W** closes everything and empties the history list after asking, because it also clears the search index; bookmarks stay.

## Moving around

- The **history sidebar** (⌃⌘S to show or hide, or the chevron on its divider) lists every file you opened, most recent first, up to 100. Swipe a row to remove it.
- The **inspector** (⌥⌘0, or the toolbar's right-sidebar button) shows the table of contents and the bookmarks. Click a heading to jump; the magnifier filters headings.
- **Back / Forward** (⌘← / ⌘→) walk the places you have been, including jumps within a document.
- Links to local Markdown files open in mdv6; every other link (web, other file types, missing files) goes to the system.
- Click a heading to copy its whole section as Markdown; the section flashes. Drag across a paragraph to select text and ⌘C to copy it.
- **⇧⌘]** / **⇧⌘[** step to the next and previous file down the history list, stopping at the ends; **⌃⇥** / **⌃⇧⇥** do the same.
- **↓** / **↑** scroll a few lines, **Page Down** / **Page Up** and **Space** / **⇧Space** a screen, **Home** / **End** to the top and bottom — without clicking into the text first.
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

## Frontmatter

- A YAML (`---`) or TOML (`+++`) metadata header at the very top of a file renders as a properties table above the document instead of as prose.
- **View → Show Frontmatter** hides it; the setting is remembered.

## Diagrams and math

- ` ```mermaid ` fences render natively for flowcharts, state, sequence, class, ER and XY charts: hover for the style menu (Document, Light, Dark, Tokyo Night, Catppuccin), **Show Mermaid source**, **Export diagram as PNG** and copy; pinch to zoom. Gantt, pie, timeline, journey, quadrant, requirement, mind-map and git-graph diagrams render through a bundled mermaid.js (a little slower the first time); hover for **Show Mermaid source** and copy. A diagram that fails shows its source with a note.
- LaTeX between `$…$` (inline) and `$$…$$` (display) is typeset natively in paragraphs, headings, lists, quotes and tables; display math on its own line is centred and offers **Copy LaTeX**. LaTeX the typesetter rejects is shown as source with the parser's message.
- Fenced code is highlighted for C, C++ (and Metal), Go, Rust, Bash, JavaScript, YAML, TOML, Python, Ruby, Swift, SQL, OpenCL, JSON, Lua, Perl and Markdown; `diff` and `patch` blocks tint added and removed lines. Hover a block to wrap long lines or copy it, and right-click a shell block for **Copy Without Prompts**.
- Raw `<img src=… width=…>` tags (the README header-image pattern) render as images at the size they ask for; remote ones follow **Load Remote Images**.

## Printing

- **⌘P** prints through the macOS print panel, whose **PDF** menu is also Save as PDF. Text, formulas and diagrams print as vector; page breaks fall between blocks; the page uses the High Contrast theme at a type size scaled to the paper, whatever the screen shows.

## Editor integration

- **⌘E** opens the current file in your editor; choose it under **File → Edit → Choose Editor…** (and forget it there). Saves are picked up live: the page reloads and keeps your place.

## Appearance

- Pick a theme from the palette button in the toolbar: High Contrast, Sevilla, Charcoal, Solarium Daylight, Solarium Moonlight, Phosphor, Twilight, Standard Erin Light, Standard Erin Dark, or **System** (High Contrast in Light, Twilight in Dark).
- **View → Smart Typography** curls quotes and dashes in prose (some themes opt out). **View → Load Remote Images** allows `http(s)` images, which are otherwise shown as a placeholder.
