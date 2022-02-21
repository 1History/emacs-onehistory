;;; onehistory.el --- History solution for emacs  -*- lexical-binding: t -*-

;; Copyright (C) 2022 Jiacai Liu

;; Author: Jiacai Liu <jiacai2050@gmail.com>
;; Version: 0.1.0
;; Package-Requires: ((emacs "25.1"))
;; Keywords: eww, elfeed, history
;; URL: https://github.com/1History/emacs-onehistory

;;; Code:

(require 'onehistory-dyn)
(require 'tabulated-list)
(require 'seq)

(defcustom onehistory-db-file (expand-file-name "onehistory.db" user-emacs-directory)
  "File where onehistory will store its database."
  :group 'onehistory
  :type 'file)

(defcustom onehistory-latest-history-limit 1000
  "Limit how many histories return when call query-latest"
  :group 'onehistory
  :type 'integer)

(defcustom onehistory-eww-integration t
  "Whether save eww history to onehistory"
  :group 'onehistory
  :type 'boolean)

(defcustom onehistory-elfeed-integration nil
  "Whether save elfeed history to onehistory"
  :group 'onehistory
  :type 'boolean)

(defvar onehistory-db nil
  "The core database for elfeed.")

(defvar onehistory-mode-map
  (let ((map (make-sparse-keymap)))
    (set-keymap-parent map tabulated-list-mode-map)
    (define-key map (kbd "RET") 'onehistory-browse-history)
    (define-key map (kbd "w") 'onehistory-copy-history-url)
    map)
  "Local keymap for onehistory mode buffers.")

(defun onehistory-db-ensure ()
  (when (null onehistory-db)
    (setf onehistory-db (onehistory-dyn--open-db onehistory-db-file))))

(defun onehistory-save-history (url title)
  (onehistory-db-ensure)
  (onehistory-dyn--save-history onehistory-db
                                url
                                title))

(defun onehistory-query-by-range (start-time end-time &optional keyword)
  (onehistory-db-ensure)
  (onehistory-dyn--query-histories-by-range onehistory-db
                                            (string-to-number (format-time-string "%s" start-time))
                                            (string-to-number (format-time-string "%s" end-time))
                                            keyword))

(defun onehistory-query-latest (&optional limit keyword)
  (onehistory-db-ensure)
  (onehistory-dyn--query-latest-histories onehistory-db
                                          (or limit onehistory-latest-history-limit)
                                          keyword))

(defun onehistory-eww-hook ()
  (let ((title (plist-get eww-data :title))
        (url (plist-get eww-data :url)))
    (if (null url)
        (message "Can't find url in %s" major-mode)
      (onehistory-save-history url title))))

(defun onehistory-save-elfeed-entry (entry)
  (let ((title (elfeed-entry-title entry))
        (url (elfeed-entry-link entry)))
    (if (null url)
        (message "Can't find url in %s" major-mode)
      (onehistory-save-history url title))))

(defun onehistory-elfeed-search-show-entry-around (orign-func entry)
  (onehistory-save-elfeed-entry entry)
  (funcall orign-func entry))

;;;###autoload
(defun onehistory-enable ()
  "Enable onehistory to save history"
  (interactive)
  (when onehistory-eww-integration
    (advice-add 'elfeed-search-show-entry :around
                'onehistory-elfeed-search-show-entry-around))

  (when onehistory-elfeed-integration
    (add-hook 'eww-after-render-hook 'onehistory-eww-hook)))

;;;###autoload
(defun onehistory-disable ()
  "Disable onehistory to save history"
  (interactive)
  (when onehistory-eww-integration
    (remove-hook 'eww-after-render-hook 'onehistory-eww-hook))

  (when onehistory-elfeed-integration
    (advice-remove 'elfeed-search-show-entry
                   'onehistory-elfeed-search-show-entry-around)))

(defun onehistory--get-url ()
  (when-let ((entry (tabulated-list-get-entry)))
     (aref entry 2)))

(defun onehistory-browse-history ()
  "Browse history at point."
  (interactive)
  (if-let ((url (onehistory--get-url)))
      (browse-url url)
    (user-error "There is no history at point")))

(defun onehistory-copy-history-url ()
  "Copy history URL at point."
  (interactive)
  (if-let ((url (onehistory--get-url)))
      (progn
        (message "%s copied" url)
        (kill-new url))
    (user-error "There is no history at point")))

(define-derived-mode onehistory-mode tabulated-list-mode "onehistory" "History solution for Emacs"
  (setq tabulated-list-format [("Time" 20 t)
                               ("Title" 50 nil)
                               ("Location" 100 nil)])
  (setq tabulated-list-padding 2)
  (setq tabulated-list-sort-key (cons "Time" t))
  (tabulated-list-init-header))

;;;###autoload
(defun onehistory-list ()
  "Display histories as table list"
  (interactive)
  (with-current-buffer (get-buffer-create "*onehistory*")
    (onehistory-mode)
    (setq tabulated-list-entries
          (lambda ()
            (seq-into
             (onehistory-query-latest)
             'list)))
    (tabulated-list-print)
    (switch-to-buffer (current-buffer))))

(provide 'onehistory)

;; Local Variables:
;; coding: utf-8
;; End:

;;; onehistory.el ends here
