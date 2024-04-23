[![MELPA](http://melpa.org/packages/ox-myst-badge.svg)](http://melpa.org/#/ox-myst)
# Myst Markdown exporter for Org Mode

This is a small exporter based on the Markdown exporter already existing in
Org mode. It should support the features [listed here](https://help.github.com/articles/github-flavored-markdown/).

## Installation

# You can install `ox-myst` using elpa. It's available on [melpa](http://melpa.org/#/ox-myst):

# <kbd> M-x package-install ox-myst </kbd>

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
