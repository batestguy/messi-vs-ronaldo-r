---
name: simple-explanation-docs
description: Create or revise matching Microsoft Word (.docx) and PDF explanations that make technical, statistical, analytical, scientific, or project material easy for a curious beginner to understand without losing factual accuracy. Use this skill whenever the user asks for a simple explanation, study guide, teaching document, plain-language report, handout, explainer, or paired Word/PDF deliverables, including when they only mention one format but clearly need a polished shareable document.
---

# Simple Explanation Documents

Create one clear, accurate document in Word, convert it to PDF, retain both
formats, and verify that they communicate the same content.

Use Python 3 with python-docx and pypdf. Prefer LibreOffice for Word-to-PDF
conversion and Poppler's pdftoppm for visual PDF rendering when available.

## 1. Establish the evidence

1. Read the user's source material and repository instructions before drafting.
2. Prefer verified local files, computed results, and primary sources. Browse
   only when current or externally sourced facts are needed.
3. Separate verified facts, calculations or inferences, assumptions, and
   limitations or unknowns.
4. Reuse an existing generator, template, or brand system when one is already
   authoritative. In the Messi-vs-Ronaldo repository, inspect
   'scripts/build_statistics_guide.py', the active phase handoff, and the
   verified analysis artifacts before changing or rebuilding the guide.
5. Do not invent examples that look like observed data. Label hypothetical
   examples clearly.

## 2. Choose the explanation depth

Default to a curious beginner unless the user specifies another audience.

Write in layers:

1. a 30-60 second overview;
2. why the subject matters;
3. the main ideas in a logical sequence;
4. worked examples or interpretations;
5. what the evidence supports;
6. what it does not support;
7. a short glossary or recap.

For each difficult idea, use this pattern:

- **Plain meaning:** one sentence without jargon.
- **Analogy or intuition:** a familiar comparison when it genuinely helps.
- **Exact version:** the formal definition, formula, or rule.
- **Worked example:** substitute real verified values when available.
- **Caution:** explain the easiest likely misinterpretation.

Keep paragraphs short. Define specialist terms on first use. Prefer concrete
verbs and active voice. Never replace accuracy with confidence or a catchy
analogy.

Read 'references/content-patterns.md' before drafting a document longer than
three pages or one containing formulas, statistics, tables, or uncertainty.

## 3. Build Word as the source document

Create the editable .docx first, normally with python-docx.

- Use a descriptive title, subtitle, date or scope, and audience note.
- Apply real Word heading styles in order; do not simulate headings with bold
  body text.
- Use a restrained visual system: one dark neutral, one primary accent, one
  secondary accent, and pale callout backgrounds.
- Keep body text at least 10.5 pt and use generous line spacing and margins.
- Use tables only for exact comparisons or mappings. Repeat header rows and
  avoid splitting short tables across pages.
- Add page numbers and consistent headers or footers for documents longer than
  two pages.
- Give charts and images meaningful captions and alt text where the toolchain
  permits it.
- State formulas in notation and ordinary language. Define every symbol.
- Put caveats beside the result they qualify, not only in a final disclaimer.
- Add human-readable citations or a source note when external material is used.

Write the retained Word file to:

    output/word/<descriptive-name>.docx

unless the user or repository defines another output path.

## 4. Produce the matching PDF

Convert the final Word file to PDF with LibreOffice in headless mode when it is
available. Treat the PDF as the distribution copy of the Word source, not as a
separately rewritten document.

Write the retained PDF to:

    output/pdf/<descriptive-name>.pdf

using the same filename stem as the Word document.

If Word-to-PDF conversion is unavailable:

1. do not silently deliver only one format;
2. use an approved deterministic PDF generator only when it can reproduce the
   same structure and content;
3. compare extracted text from both files;
4. disclose the fallback in the handoff.

## 5. Verify both deliverables

Run the bundled checker:

    python scripts/validate_outputs.py --docx <word-path> --pdf <pdf-path>

Add one or more '--required "exact phrase"' arguments for critical values,
conclusions, caveats, or section titles.

Then complete the checks the script cannot judge:

1. Reopen the Word file and confirm headings, tables, page numbers, and document
   properties are intact.
2. Render every PDF page to PNG with pdftoppm.
3. Inspect every rendered page for clipped text, overlap, awkward page breaks,
   broken glyphs, empty pages, illegible tables, and inconsistent spacing.
4. Extract PDF text with pypdf or pdfplumber; confirm key facts and formulas
   survived conversion.
5. Confirm the Word and PDF use the same stem, both remain on disk, and no
   temporary render files remain in the deliverable folders.

Do not claim visual verification from successful file creation or text
extraction alone.

## 6. Handoff

Report:

- clickable paths to both retained files;
- the intended audience and scope;
- the source material used;
- important verified values;
- any conversion fallback or missing dependency;
- the number of Word/PDF pages;
- the visual and text checks performed.

Do not delete the Word file after creating the PDF. Do not leave a PDF as the
only editable source.
