# General guidelines

## LaTeX/KaTeX Math Formatting in Markdown - CRITICAL RULE

When generating markdown with inline math equations, you MUST follow this exact format:
- Correct: `$equation$` (no spaces)
- Incorrect: `$ equation $` (spaces present)

**NEVER add a space after the opening `$` or before the closing `$` when writing markdown.**

This applies to both inline math (`$...$`) and display math (`$$...$$`) in all markdown output.