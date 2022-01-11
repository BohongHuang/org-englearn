(require 'org-englearn)
(require 'pdf-view)

(defvar org-englearn-pdf-view-capture-annot t
  "If nil set, org-englearn-capture will deactivatethe region before org-capture is called, avoiding org-pdftools creating a new annotation on region.")

(defun org-englearn-capture-pdf-view ()
  (interactive)
  (pcase-let ((`(,cap) (pdf-view-active-region-text)))
    (unless org-englearn-pdf-view-capture-annot
      (pdf-view-deactivate-region))
    (org-capture-string (replace-regexp-in-string "\n" " " cap) "e")))

(provide 'org-englearn-pdf-view)
;;; org-englearn-pdf-view.el ends here
