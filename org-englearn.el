;;; org-englearn.el --- English learning workflow with Org -*- lexical-binding: t -*-

;; Commentary:
;; This package provide an efficient English learning workflow, combining with org-mode, org-capture, org-roam.

(require 'hydra)
(require 'go-translate)
(require 'org-capture)

(defvar gts-kill-ring-only-translation-render-source-text nil
  "")


(defun org-englearn-trim-string (string)
  (replace-regexp-in-string "\\(^[[:space:]\n]*\\|[[:space:]\n]*$\\)" "" string))

(defclass gts-kill-ring-only-translation-render (gts-render) ())

(cl-defmethod gts-out ((_ gts-kill-ring-only-translation-render) task)
  (deactivate-mark)
  (with-slots (result ecode) task
    (unless ecode
      (kill-new (org-englearn-trim-string (replace-regexp-in-string (regexp-quote gts-kill-ring-only-translation-render-source-text) "" result))))
    (setq gts-kill-ring-only-translation-render-source-text nil)
    (message "Translation has saved to kill ring.")))

(defvar org-englearn-gts-translator
  (gts-translator
       :picker (gts-prompt-picker)
       :engines (list (gts-google-engine))
       :render (gts-kill-ring-only-translation-render))
  "")

(defun org-englearn-fill-heading ()
  (if (region-active-p)
      (atomic-change-group
        (let* ((sentence-begin (region-beginning))
               (sentence-end (region-end))
               last-mark
               (first-loop t))
          (goto-char sentence-begin)
          (while (progn
                   (when (not (eq (point) last-mark))
                     (set-mark (setq last-mark (point)))
                     (forward-sexp)
                     (let* ((phrase (buffer-substring-no-properties (region-beginning) (region-end)))
                            (element (pcase (car (read-multiple-choice "What's the form of this word in heading?"
                                                                  `((?s "n.(sth./sb./sp.)")
                                                                    (?n "n.(noun)")
                                                                    (?v "v.(verb)")
                                                                    (?p "prep.")
                                                                    (?k ,phrase)
                                                                    (?. "...")
                                                                    (?  "(empty)"))))
                                       (`?s (pcase (car (read-multiple-choice "Some?"
                                                                         '((?t "sth.")
                                                                           (?p "sp.")
                                                                           (?b "sb."))))
                                              (`?t "=sth.=")
                                              (`?p "=sp.=")
                                              (`?b "=sb.=")
                                              (x (error "Unknown element of s%s!" x))))
                                       (`?n "=n.=")
                                       (`?v "=v.=")
                                       (`?p "=prep.=")
                                       (`?k phrase)
                                       (`?. "=...=")
                                       (`?  "")
                                       (x (error "Unknown element of %s!" x))))
                            (insertion (concat (if (or (string-empty-p element) first-loop)
                                                   "" " ")
                                               element)))
                       (save-excursion
                         (org-back-to-heading)
                         (end-of-line)
                         (insert insertion)
                         (let ((inc (length insertion)))
                         (cl-incf sentence-begin inc)
                         (cl-incf sentence-end inc)
                         (cl-incf last-mark inc))))
                     (ignore-errors
                       (forward-sexp)
                       (backward-sexp))
                     (setq first-loop nil)
                     (and (< (point) sentence-end)))))
          (deactivate-mark)
          (goto-char sentence-end)
          (insert "_")
          (goto-char sentence-begin)
          (insert "_")))
    (error "No mark set!")))

(defun org-englearn-move-capture-timestamp ()
  (interactive)
  (org-back-to-heading)
  (next-line)
  (let ((beg (point))
        timestamp)
          (end-of-line)
          (setq timestamp (buffer-substring-no-properties beg (point)))
          (delete-region beg (point))
          (delete-forward-char 1)
          (end-of-buffer)
          (previous-line)
          (end-of-line)
          (insert " " timestamp)))

(defun org-englearn-capture-process-buffer (text context)
  (search-forward text)
  (set-mark (- (point) (length text)))
  (setq gts-kill-ring-only-translation-render-source-text context)
  (gts-translate org-englearn-gts-translator context "en" "zh")
  (activate-mark)
  (org-englearn-fill-heading)
  (org-englearn-move-capture-timestamp)
  (end-of-buffer)
  (previous-line 2)
  (end-of-line)
  (insert " \\\\")
  (next-line)
  (beginning-of-line)
  (open-line 1)
  (indent-for-tab-command)
  (yank)
  (org-back-to-heading)
  (next-line 1)
  (indent-for-tab-command)
  (insert "- ")
  (let ((beg (point)))
    (next-line)
    (beginning-of-line)
    (delete-forward-char 1)
    (insert "-")
    (org-indent-item)
    (goto-char beg)
    (setq-local org-roam-capture-templates `(("m" "Meaning"
                                              entry "* ${title}" :if-new (file ,(expand-file-name "org-roam/english-learning/meanings.org" org-directory)) :unnarrowed t :immediate-finish t)))
    (add-hook 'org-capture-after-finalize-hook #'org-englearn-capture-heading-by-id-hook -5 t)
    (org-roam-node-insert)
    (kill-local-variable 'org-roam-capture-templates)
    (remove-hook 'org-capture-after-finalize-hook #'org-englearn-capture-heading-by-id-hook t)
    (beginning-of-line)
    (re-search-forward "^[[:space:]]*- ")
    
    (pcase (completing-read "What's its part?" '("adj." "adv." "n." "v." "vt." "vi." "prep.")
                            nil nil nil nil nil)
      (`"adv." (insert "adv. ")
       (end-of-line)
       (insert "地"))
      (`"adj." (insert "adj. ")
       (end-of-line)
       (insert "的"))
      (x (insert x " ")))))

(defun org-englearn-get-org-roam-capture-template ())

(defun org-englearn-capture-process-region (&optional beg end)
  (interactive)
  (let* ((beg (or beg (if (region-active-p) (region-beginning) (mark))))
        (end (or end (if (region-active-p) (region-end) (point))))
        (cap (buffer-substring-no-properties beg end))
        (beg (save-excursion
               (unless (> (point) (mark)) (exchange-point-and-mark))
               (backward-sentence)
               (point)))
        (end (save-excursion
               (unless (< (point) (mark)) (exchange-point-and-mark))
               (forward-sentence)
               (point)))
        (sentence (buffer-substring-no-properties beg end)))
    (org-englearn-capture-process-buffer cap sentence)))

(defun org-englearn-capture-heading-by-id-hook ()
  (when-let* ((roam-capture (org-roam-capture-p))
              (roam-list (plist-get org-capture-plist :org-roam))
              (ins-link (eq (plist-get roam-list :finalize) 'insert-link)))
    (with-current-buffer (org-capture-get :buffer)
      (goto-char (point-min))
      (re-search-forward (concat "^* " (plist-get roam-list :link-description) ))
      (org-roam-capture--put :id (org-id-get-create)))))

(defun org-englearn-capture (&optional beg end)
  (interactive)
  (let* ((beg (or beg (if (region-active-p) (region-beginning) (mark))))
         (end (or end (if (region-active-p) (region-end) (point))))
         (cap (buffer-substring-no-properties beg end)))
    (if (string-match-p (regexp-quote ".") cap)
        (org-capture-string cap "e")
      (let* ((beg (save-excursion
                    (unless (> (point) (mark)) (exchange-point-and-mark))
                    (backward-sentence)
                    (point)))
             (end (save-excursion
                    (unless (< (point) (mark)) (exchange-point-and-mark))
                    (forward-sentence)
                    (point)))
             (sentence (buffer-substring-no-properties beg end)))
        (deactivate-mark)
        (org-capture-string sentence "e")
        (org-englearn-capture-process-buffer cap sentence)))))

(defun org-englearn-process-inbox ()
  (interactive)
  (find-file (expand-file-name "org-capture/english.org" org-directory))
  (org-map-entries
   (lambda ()
     (setq org-map-continue-from (org-element-property
                                  :begin
                                  (org-element-at-point)))
     (org-narrow-to-element)
     (org-show-subtree)

     (pcase (car (read-multiple-choice "Which category does it belong to?"
                                       '((?w "words")
                                         (?c "complex sentence"))))
       (`?w (org-cut-subtree)
            (with-current-buffer (find-file-noselect (expand-file-name "org-roam/english-learning/words.org" org-directory))
              (end-of-buffer)
              (yank)
              (org-englearn-process-new-heading)))
       (_ (error "Invalid input!")))
     (widen))))

(defun org-englearn-process-new-heading ()
  (interactive)
  (let ((words (org-map-entries (lambda () (nth 4 (org-heading-components)))))
        (word (nth 4 (org-heading-components)))
        item-title
        item)
    (when (-contains-p words word)
      (org-back-to-heading)
      (re-search-forward "^[[:space:]]*- ")
      (save-excursion (let ((beg (point)))
                        (end-of-line)
                        (setq item-title (org-englearn-trim-string (buffer-substring-no-properties beg (point))))))
      (backward-char 2)
      (er/expand-region 2)
      (setq item (buffer-substring-no-properties (mark) (point)))
      (deactivate-mark)
      (org-cut-subtree)
      (condition-case nil
          (progn (re-search-backward (concat (regexp-quote (concat "* " word)) "[[:space:]]*$"))
                 (save-restriction
                   (org-narrow-to-subtree)
                   (condition-case nil
                       (progn                              ; try
                         (re-search-forward (concat "^[[:space:]]*- " (regexp-quote item-title)))
                         (widen)
                         (org-end-of-item)
                         (let ((insert-point (point)))
                           (insert item)
                           (goto-char insert-point)
                           (next-line)
                           (beginning-of-line)
                           (delete-region insert-point (point))))
                     (error                                ; catch
                      (re-search-forward "^[[:space:]]*- ")
                      (widen)
                      (org-end-of-item-list)
                      (insert item)))))
        (error
         (yank)
         (org-id-get-create))))))

(provide 'org-englearn)
