(require 'org-englearn)
(require 'pdf-view)

(defvar org-englearn-pdf-view-disable-org-pdftools-link nil)

(defun org-englearn-capture-pdf-view ()
  (interactive)
  (pcase-let ((`(,cap) (pdf-view-active-region-text))
              (org-pdftools-link-store))
    (when org-englearn-pdf-view-disable-org-pdftools-link
      (require 'org-pdftools)
      (setq org-pdftools-link-store (org-link-get-parameter org-pdftools-prefix :store))
      (org-link-set-parameters org-pdftools-prefix :store nil))
    (org-capture-string (replace-regexp-in-string "\n" " " cap) "e")
    (when (and org-englearn-pdf-view-disable-org-pdftools-link org-pdftools-link-store)
      (org-link-set-parameters org-pdftools-prefix :store org-pdftools-link-store))))

(provide 'org-englearn-pdf-view)
;;; org-englearn-pdf-view.el ends here
