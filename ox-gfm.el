;;; ox-gfm.el --- Github Flavored Markdown Back-End for Org Export Engine

;; Copyright (C) 2014 Lars Tveito

;; Author: Lars Tveito
;; Keywords: org, wp, markdown, github

;; This file is not part of GNU Emacs.

;; GNU Emacs is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; GNU Emacs is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs.  If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:

;; This library implements a Markdown back-end (github flavor) for Org
;; exporter, based on the `md' back-end.

;;; Code:

(require 'ox-md)



;;; User-Configurable Variables

(defgroup org-export-gfm nil
  "Options specific to Markdown export back-end."
  :tag "Org Github Flavored Markdown"
  :group 'org-export
  :version "24.4"
  :package-version '(Org . "8.0"))


;;; Define Back-End

(org-export-define-derived-backend 'gfm 'md
  :export-block '("GFM" "GITHUB FLAVORED MARKDOWN")
  :filters-alist '((:filter-parse-tree . org-md-separate-elements))
  :menu-entry
  '(?g "Export to Github Flavored Markdown"
       ((?G "To temporary buffer"
            (lambda (a s v b) (org-gfm-export-as-markdown a s v)))
        (?g "To file" (lambda (a s v b) (org-gfm-export-to-markdown a s v)))
        (?o "To file and open"
            (lambda (a s v b)
              (if a (org-gfm-export-to-markdown t s v)
                (org-open-file (org-gfm-export-to-markdown nil s v)))))))
  :translate-alist '((inner-template . org-gfm-inner-template)
                     (strike-through . org-gfm-strike-through)
                     (src-block . org-gfm-src-block)
                     (table-cell . org-gfm-table-cell)
                     (table-row . org-gfm-table-row)
                     (table . org-gfm-table)))



;;; Transcode Functions

;;;; Src Block

(defun org-gfm-src-block (src-block contents info)
  "Transcode SRC-BLOCK element into Github Flavored Markdown
format. CONTENTS is nil.  INFO is a plist used as a communication
channel."
  (let* ((lang (org-element-property :language src-block))
         (code (org-export-format-code-default src-block info))
         (prefix (concat "```" lang "\n"))
         (suffix "```"))
    (concat prefix code suffix)))


;;;; Strike-Through

(defun org-gfm-strike-through (strike-through contents info)
  "Transcode STRIKE-THROUGH from Org to Markdown (GFM).
CONTENTS is the text with strike-through markup.  INFO is a plist
holding contextual information."
  (format "~~%s~~" contents))


;;;; Table-Cell

(defvar width-cookies nil)
(defvar width-cookies-table nil)

(defun org-gfm-table-col-width (table column info)
  "Return width of TABLE at given COLUMN. INFO is a plist used as
communication channel. Width of a column is determined either by
inquerying `width-cookies' in the column, or by the maximum cell with in
the column."
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
                            (elt ;(if specialp (car (org-element-contents row))
                                   (org-element-contents row);)
                                 column))
                           info))
                         max-width)))
            info)
          (puthash column max-width width-cookies))))))
          


(defun org-gfm-table-cell (table-cell contents info)
  "Transcode TABLE-CELL element from Org into GFM. CONTENTS is content
of the cell. INFO is a plist used as a communication channel."
  (let* ((table (org-export-get-parent-table table-cell))
         (column (cdr (org-export-table-cell-address table-cell info)))
         (width (org-gfm-table-col-width table column info))
         (left-border (if (org-export-table-cell-starts-colgroup-p table-cell info) "| " " "))
         (right-border " |")
         (data (or contents "")))
    (setq contents
          (concat data
                  (make-string (- width (string-width data))
                               ?\s)))
    (concat left-border contents right-border)))


;;;; Table-Row

(defun org-gfm-table-row (table-row contents info)
  "Transcode TABLE-ROW element from Org into GFM. CONTENTS is cell
contents of TABLE-ROW. INFO is a plist used as a communication
channel."
  (when (eq 'rule (org-element-property :type table-row))
    (let* ((table (org-export-get-parent-table table-row))
           (left-border "| ")
           (vertical " | ")
           (right-border " |")
           (build-rule
            (function
             (lambda (col)
               (let ((max-width (org-gfm-table-col-width table col info)))
                 (make-string max-width ?-)))))
           (cols (cdr (org-export-table-dimensions table info))))
      (setq contents
            (concat left-border
                    (mapconcat (lambda (col) (funcall build-rule col))
                               (number-sequence 0 (- cols 1))
                               vertical)
                    right-border))))
  contents)



;;;; Table

(defun org-gfm-table (table contents info)
  "Transcode TABLE element into Github Flavored Markdown table.
CONTENTS is the contents of the table. INFO is a plist holding
contextual information."
  (replace-regexp-in-string "\n\n" "\n" contents))


;;;; Table of contents

(defun org-gfm-format-toc (headline)
  "Return an appropriate table of contents entry for HEADLINE. INFO is a
plist used as a communication channel."
  (let* ((title (org-export-data
                 (org-export-get-alt-title headline info) info))
         (level (1- (org-element-property :level headline)))
         (indent (concat (make-string (* level 2) ? )))
         (anchor (or (org-element-property :custom_id headline)
                     (concat "sec-" (mapconcat 'number-to-string
                                               (org-export-get-headline-number
                                                headline info) "-")))))
    (concat indent "- [" title "]" "(#" anchor ")")))




;;;; Template

(defun org-gfm-inner-template (contents info)
  "Return body of document after converting it to Markdown syntax.
CONTENTS is the transcoded contents string.  INFO is a plist
holding export options."
  (let* ((depth (plist-get info :with-toc))
         (headlines (and depth (org-export-collect-headlines info depth)))
         (toc-string (or (mapconcat 'org-gfm-format-toc headlines "\n") ""))
         (toc-tail (if headlines "\n\n" "")))
    (concat toc-string toc-tail contents)))



;;; Interactive function

;;;###autoload
(defun org-gfm-export-as-markdown (&optional async subtreep visible-only)
  "Export current buffer to a Github Flavored Markdown buffer.

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

Export is done in a buffer named \"*Org GFM Export*\", which will
be displayed when `org-export-show-temporary-export-buffer' is
non-nil."
  (interactive)
  (org-export-to-buffer 'gfm "*Org GFM Export*"
    async subtreep visible-only nil nil (lambda () (text-mode))))


;;;###autoload
(defun org-gfm-convert-region-to-md ()
  "Assume the current region has org-mode syntax, and convert it
to Github Flavored Markdown.  This can be used in any buffer.
For example, you can write an itemized list in org-mode syntax in
a Markdown buffer and use this command to convert it."
  (interactive)
  (org-export-replace-region-by 'gfm))


;;;###autoload
(defun org-gfm-export-to-markdown (&optional async subtreep visible-only)
  "Export current buffer to a Github Flavored Markdown file.

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
    (org-export-to-file 'gfm outfile async subtreep visible-only)))

(provide 'ox-gfm)

;;; ox-gfm.el ends here
