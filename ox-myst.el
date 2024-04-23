;;; ox-myst.el --- Myst Markdown Back-End for Org Export Engine -*- lexical-binding: t; -*-

;; Copyright (C) 2014-2017 Lars Tveito, 2024 Matt Price

;; Author: Lars Tveito, Matt Price
;; Keywords: org, wp, markdown, myst

;; This file is not part of GNU Emacs.

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:

;; This library implements a Markdown back-end (myst flavor) for Org
;; exporter, based on the `md' back-end. Forked from the gfm backend.

;;; Code:

(require 'ox-md)
(require 'ox-publish)


;;; User-Configurable Variables

(defgroup org-export-myst nil
  "Options specific to Markdown export back-end."
  :tag "Org Myst Markdown"
  :group 'org-export
  :version "24.4"
  :package-version '(Org . "8.0"))


;;; Define Back-End

(org-export-define-derived-backend 'myst 'md
  :filters-alist '((:filter-parse-tree . org-md-separate-elements))
  :menu-entry
  '(?M "Export to Myst Markdown"
       ((?m "To temporary buffer"
            (lambda (a s v b) (org-myst-export-as-markdown a s v)))
        (?M "To file" (lambda (a s v b) (org-myst-export-to-markdown a s v)))
        (?O "To file and open"
            (lambda (a s v b)
              (if a (org-myst-export-to-markdown t s v)
                (org-open-file (org-myst-export-to-markdown nil s v)))))))
  :translate-alist '((inner-template . org-myst-inner-template)
                     (plain-text . org-myst-plain-text)
                     (paragraph . org-myst-paragraph)
                     (strike-through . org-myst-strike-through)
                     (example-block . org-myst-example-block)
                     (src-block . org-myst-src-block)
                     (special-block . org-myst-special-block)
                     (table-cell . org-myst-table-cell)
                     (table-row . org-myst-table-row)
                     (table . org-myst-table)))


;;; Transcode Functions

;;; front-matter

(defun org-myst-front-matter ()
  "Add FRONT MATTER YAML to document.
Currently this is not really a function, just passes the default
YAML as a static string"
  "---
jupytext:
  cell_metadata_filter: -all
  formats: md:myst,ipynb,py:percent
  text_representation:
    extension: .md
    format_name: myst
    format_version: 0.13
    jupytext_version: 1.16.1
kernelspec:
  display_name: Python 3 (ipykernel)
  language: python
  name: python3
---
")

;;;; Plain Text

(defun org-myst-plain-text (text info)
  "Transcode a TEXT string into Markdown format.
TEXT is the string to transcode.  INFO is a plist holding
contextual information. Don't use smart quotes here."
  ;; commenting this out is the reason this function exists
  ;; (when (plist-get info :with-smart-quotes)
  ;;   (setq text (org-export-activate-smart-quotes text :html info)))
  ;; The below series of replacements in `text' is order sensitive.
  ;; Protect `, *, _, and \
  (setq text (replace-regexp-in-string "[`*_\\]" "\\\\\\&" text))
  ;; Protect ambiguous #.  This will protect # at the beginning of
  ;; a line, but not at the beginning of a paragraph.  See
  ;; `org-md-paragraph'.
  (setq text (replace-regexp-in-string "\n#" "\n\\\\#" text))
  ;; Protect ambiguous !
  (setq text (replace-regexp-in-string "\\(!\\)\\[" "\\\\!" text nil nil 1))
  ;; Handle special strings, if required.
  (when (plist-get info :with-special-strings)
    (setq text (org-html-convert-special-strings text)))
  ;; Handle break preservation, if required.
  (when (plist-get info :preserve-breaks)
    (setq text (replace-regexp-in-string "[ \t]*\n" "  \n" text)))
  ;; Return value.
  text)

;;;; Paragraph

(defun org-myst-paragraph (paragraph contents info)
  "Transcode PARAGRAPH element into Github Flavoured Markdown format.
CONTENTS is the paragraph contents.  INFO is a plist used as a
communication channel."
  (unless (plist-get info :preserve-breaks)
    (setq contents (concat (mapconcat 'identity (split-string contents) " ") "\n")))
  (let ((first-object (car (org-element-contents paragraph))))
    ;; If paragraph starts with a #, protect it.
    (if (and (stringp first-object) (string-match "\\`#" first-object))
        (replace-regexp-in-string "\\`#" "\\#" contents nil t)
      contents)))

;;;; Src Block

(defun org-myst-src-block (src-block _contents info)
  "Transcode SRC-BLOCK element into Myst Markdown format.
_CONTENTS is nil.  INFO is a plist used as a communication
channel.  Temporarily setting notebook language statically"
  (let* ((lang (org-element-property :language src-block))
         (code (org-export-format-code-default src-block info))
         (lang-fix (if (or  (string-match-p "python" lang)
                            (string-match-p "{code-cell}" lang))
                       "{code-cell} ipython3"
                     lang))
         (prefix (concat "```" lang-fix "\n"))
         (suffix "```"))
    
    (concat prefix code suffix)))

;;;; Example Block

(defalias 'org-myst-example-block #'org-myst-src-block)

;;;; Strike-Through

(defun org-myst-strike-through (_strike-through contents _info)
  "Transcode _STRIKE-THROUGH from Org to Markdown (MYST).
CONTENTS is the text with strike-through markup.  _INFO is a plist
holding contextual information."
  (format "~~%s~~" contents))

;;;; Table-Common

(defvar width-cookies nil)
(defvar width-cookies-table nil)

(defconst myst-table-left-border "|")
(defconst myst-table-right-border " |")
(defconst myst-table-separator " |")

(defun org-myst-table-col-width (table column info)
  "Return width of TABLE at given COLUMN.
INFO is a plist used as communication channel.  Width of a column
is determined either by inquerying `width-cookies' in the column,
or by the maximum cell with in the column."
  (let ((cookie (when (hash-table-p width-cookies)
                  (gethash column width-cookies))))
    (if (and (eq table width-cookies-table)
             (not (eq nil cookie)))
        cookie
      (progn
        (unless (and (eq table width-cookies-table)
                     (hash-table-p width-cookies))
          (setq width-cookies (make-hash-table))
          (setq width-cookies-table table))
        (let ((max-width 0)
              (specialp (org-export-table-has-special-column-p table)))
          (org-element-map
              table
              'table-row
            (lambda (row)
              (setq max-width
                    (max (length
                          (org-export-data
                           (org-element-contents
                            (elt (if specialp (car (org-element-contents row))
                                   (org-element-contents row))
                                 column))
                           info))
                         max-width)))
            info)
          (puthash column max-width width-cookies))))))

(defun org-myst-make-hline-builder (table info char)
  "Return a function to build horizontal line in TABLE with given CHAR.
INFO is a plist used as a communication channel."
  (lambda (col)
    (let ((max-width (max 3 (org-myst-table-col-width table col info))))
      (when (< max-width 1)
        (setq max-width 1))
      (make-string max-width char))))

;;;; Table-Cell

(defun org-myst-table-cell (table-cell contents info)
  "Transcode TABLE-CELL element from Org into MYST.
CONTENTS is content of the cell.  INFO is a plist used as a
communication channel."
  (let* ((table (org-export-get-parent-table table-cell))
         (column (cdr (org-export-table-cell-address table-cell info)))
         (width (org-myst-table-col-width table column info))
         (left-border (if (org-export-table-cell-starts-colgroup-p table-cell info) "| " " "))
         (right-border " |")
         (data (or contents "")))
    (setq contents
          (concat data
                  (make-string (max 0 (- width (string-width data)))
                               ?\s)))
    (concat left-border contents right-border)))

;;;; Table-Row

(defun org-myst-table-row (table-row contents info)
  "Transcode TABLE-ROW element from Org into MYST.
CONTENTS is cell contents of TABLE-ROW.  INFO is a plist used as a
communication channel."
  (let ((table (org-export-get-parent-table table-row)))
    (when (and (eq 'rule (org-element-property :type table-row))
               ;; In MYST, rule is valid only at second row.
               (eq 1 (cl-position
                      table-row
                      (org-element-map table 'table-row 'identity info))))
      (let* ((table (org-export-get-parent-table table-row))
             (build-rule (org-myst-make-hline-builder table info ?-))
             (cols (cdr (org-export-table-dimensions table info))))
        (setq contents
              (concat myst-table-left-border
                      (mapconcat (lambda (col) (funcall build-rule col))
                                 (number-sequence 0 (- cols 1))
                                 myst-table-separator)
                      myst-table-right-border))))
    contents))

;;;; Special Block

(defun org-myst-special-block (special-block contents info)
  "Transcode a SPECIAL-BLOCK element from Org to Myst admonitions.
CONTENTS holds the contents of the block.  INFO is a plist
holding contextual information."
  (let* ((block-type (org-element-property :type special-block))
         (html5-fancy (and (org-html--html5-fancy-p info)
                           (member block-type org-html-html5-elements)))
         (attributes (org-export-read-attribute :attr_html special-block)))
    (unless html5-fancy
      (let ((admonition (plist-get attributes :admonition)))
        (setq attributes (plist-put attributes :admonition
                                    (if admonition (concat admonition " " block-type)
                                      block-type)))))
    (let* ((contents (or contents ""))
	   (reference (org-html--reference special-block info))
	   (a (org-html--make-attribute-string
	       (if (or (not reference) (plist-member attributes :id))
		   attributes
		 (plist-put attributes :id reference))))
	   (str (if (org-string-nw-p a) (concat " " a) "")))
      (format ":::{%s}\n%s:::\n" block-type contents block-type)
      ;; (if html5-fancy
      ;;     (format "<%s%s>\n%s</%s>" block-type str contents block-type)
      ;;   (format "<div%s>\n%s\n</div>" str contents))
      )))

;;;; Table

(defun org-myst-table (table contents info)
  "Transcode TABLE element into Myst Markdown table.
CONTENTS is the contents of the table.  INFO is a plist holding
contextual information."
  (let* ((rows (org-element-map table 'table-row 'identity info))
         (no-header (or (<= (length rows) 1)))
         (cols (cdr (org-export-table-dimensions table info)))
         (build-dummy-header
          (lambda ()
            (let ((build-empty-cell (org-myst-make-hline-builder table info ?\s))
                  (build-rule (org-myst-make-hline-builder table info ?-))
                  (columns (number-sequence 0 (- cols 1))))
              (concat myst-table-left-border
                      (mapconcat (lambda (col) (funcall build-empty-cell col))
                                 columns
                                 myst-table-separator)
                      myst-table-right-border "\n" myst-table-left-border
                      (mapconcat (lambda (col) (funcall build-rule col))
                                 columns
                                 myst-table-separator)
                      myst-table-right-border "\n")))))
    (concat (and no-header (funcall build-dummy-header))
            (replace-regexp-in-string "\n\n" "\n" contents))))

;;;; Table of contents

(defun org-myst-format-toc (headline info)
  "Return an appropriate table of contents entry for HEADLINE."
  (let* ((title (org-export-data
                 (org-export-get-alt-title headline info) info))
         (level (1- (org-element-property :level headline)))
         (indent (concat (make-string (* level 2) ? )))
         (anchor (or (org-element-property :CUSTOM_ID headline)
                     (org-export-get-reference headline info))))
    (concat indent "- [" title "]" "(#" anchor ")")))

;;;; Footnote section

(defun org-myst-footnote-section (info)
  "Format the footnote section.
INFO is a plist used as a communication channel."
  (and-let* ((fn-alist (org-export-collect-footnote-definitions info)))
    (format
     "## Footnotes\n\n%s\n"
     (mapconcat (pcase-lambda (`(,n ,_type ,def))
                  (format
                   "%s %s\n"
                   (format (plist-get info :html-footnote-format)
                           (org-html--anchor
                            (format "fn.%d" n)
                            n
                            (format " class=\"footnum\" href=\"#fnr.%d\"" n)
                            info))
                   (org-trim (org-export-data def info))))
                fn-alist "\n"))))

;;;; Template

(defun org-myst-inner-template (contents info)
  "Return body of document after converting it to Markdown syntax.
CONTENTS is the transcoded contents string.  INFO is a plist
holding export options."
  (let* ((depth (plist-get info :with-toc))
         (headlines (and depth (org-export-collect-headlines info depth)))
         (toc-string (or (mapconcat (lambda (headline)
                                      (org-myst-format-toc headline info))
                                    headlines "\n")
                         ""))
         (toc-tail (if headlines "\n\n" ""))
         (front-matter (org-myst-front-matter)))
    (org-trim (concat front-matter toc-string toc-tail contents "\n" (org-myst-footnote-section info)))))


;;; Interactive function

;;;###autoload
(defun org-myst-export-as-markdown (&optional async subtreep visible-only)
  "Export current buffer to a Myst Markdown buffer.

If narrowing is active in the current buffer, only export its
narrowed part.

If a region is active, export that region.

A non-nil optional argument ASYNC means the process should happen
asynchronously.  The resulting buffer should be accessible
through the `org-export-stack' interface.

When optional argument SUBTREEP is non-nil, export the sub-tree
at point, extracting information from the headline properties
first.

When optional argument VISIBLE-ONLY is non-nil, don't export
contents of hidden elements.

Export is done in a buffer named \"*Org MYST Export*\", which will
be displayed when `org-export-show-temporary-export-buffer' is
non-nil."
  (interactive)
  (org-export-to-buffer 'myst "*Org MYST Export*"
    async subtreep visible-only nil nil (lambda () (text-mode))))

;;;###autoload
(defun org-myst-convert-region-to-md ()
  "Convert the region to Myst Markdown.
This can be used in any buffer, this function assume that the
current region has org-mode syntax.  For example, you can write
an itemized list in org-mode syntax in a Markdown buffer and use
this command to convert it."
  (interactive)
  (org-export-replace-region-by 'myst))

;;;###autoload
(defun org-myst-export-to-markdown (&optional async subtreep visible-only)
  "Export current buffer to a Myst Markdown file.

If narrowing is active in the current buffer, only export its
narrowed part.

If a region is active, export that region.

A non-nil optional argument ASYNC means the process should happen
asynchronously.  The resulting file should be accessible through
the `org-export-stack' interface.

When optional argument SUBTREEP is non-nil, export the sub-tree
at point, extracting information from the headline properties
first.

When optional argument VISIBLE-ONLY is non-nil, don't export
contents of hidden elements.

Return output file's name."
  (interactive)
  (let ((outfile (org-export-output-file-name ".md" subtreep)))
    (org-export-to-file 'myst outfile async subtreep visible-only)))

;;;###autoload
(defun org-myst-publish-to-myst (plist filename pub-dir)
  "Publish an org file to Markdown.
FILENAME is the filename of the Org file to be published.  PLIST
is the property list for the given project.  PUB-DIR is the
publishing directory.
Return output file name."
  (org-publish-org-to 'myst filename ".md" plist pub-dir))

(provide 'ox-myst)

;;; ox-myst.el ends here
