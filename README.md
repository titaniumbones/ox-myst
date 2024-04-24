[![MELPA](http://melpa.org/packages/ox-myst-badge.svg)](http://melpa.org/#/ox-myst)
# Myst Markdown exporter for Org Mode

This is a small exporter based on the Markdown exporter already existing in
Org mode. It should support the features [listed here](https://mystmd.org/guide/quickstart-myst-markdown/).

**This is a "works for me" exporter.**  It supports a tiny subset of MyST-specific features, which I will expand as I learn more about MyST and make use of more of those features in my own work.  PRs are more than welcome, and I'd love to see this evolve into a more broadly useful project. 

Some basic features you may miss include:
- support for [MyST figures directives](https://mystmd.org/guide/figures#figure-directive)!
- support for [MyST citation](https://mystmd.org/guide/citations)!

It looks like support for both will be relatively straightforward to add, I just haven't taken the time to write the relevant functions yet.

There are plenty of other features you might want to use; features shared with gfm should be supported out of the box, while most others will need to be implemented _de novo_.

## Installation

<!-- # You can install `ox-myst` using elpa. It's available on [melpa](http://melpa.org/#/ox-myst): -->

<!-- # <kbd> M-x package-install ox-myst </kbd> -->

Not available anywhere yet -- you'll need to load manually for now. 

## Usage

This package adds an Org mode export backend for Myst Markdown. You
can read more about [Org mode exporting here.](http://orgmode.org/manual/Exporting.html)

Exporting to Myst Markdown is available through Org
mode's [export dispatcher](http://orgmode.org/manual/The-export-dispatcher.html#The-export-dispatcher)
once `ox-myst` is loaded. Alternatively, exporting can be triggered by calling the
(autoloaded) function `M-x org-myst-export-to-markdown`.

If you want to automatically load `ox-myst` along with Org mode, then you can
add this snippet to your Emacs configuration:

```emacs-lisp
(eval-after-load "org"
  '(require 'ox-myst nil t))
```
