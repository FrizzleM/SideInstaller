# Design — SideInstaller

## Genre
Modern-minimal device utility: calm, explicit, and high-trust.

## Macrostructure family
- Marketing/install: Guided Utility — asymmetric utility masthead, sequential setup, certificate workbench.
- Legal/content: Long Document — restrained reading column and anchored contents.

## Theme
- Paper: deep blue-black (`--color-paper`)
- Accent: electric blue (`--color-accent`), used only for action and state
- Type: system-rounded display with system UI body and a mono utility register

## Motion
Short translate/colour transitions only. Reduced motion uses a 150ms opacity-safe fallback.

## CTA voice
Filled electric-blue rounded rectangle; label stays single line. Secondary controls are quiet outlines.

## What pages must share
The SideInstaller icon, deep-blue paper, electric-blue action colour, utility masthead, and focus treatment.

## Exports
`tokens.css` is the canonical CSS export. The project does not use Tailwind or shadcn; DTCG export is intentionally omitted until a consuming tool is introduced.
