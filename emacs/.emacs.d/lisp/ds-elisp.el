
(when ds/emacs-up-to-date?
  (add-hook 'emacs-lisp-mode-hook 'prettify-symbols-mode))

;; Use double semi-colon for emacs lisp (default seems to be single).
(add-hook 'emacs-lisp-mode-hook (lambda () (setq comment-start ";;"
                                            comment-end "")))


(defun insert-key-as-kbd (key)
  (interactive "kKey: ")
  (insert (format "(kbd %S)" (key-description key))))

(define-key emacs-lisp-mode-map (kbd "C-,") #'insert-key-as-kbd)


(require 'evil-args)
(defun ds/lisp-evil-args-setup ()
  (setq-local evil-args-delimiters '(" ")))
(add-hook 'emacs-lisp-mode-hook #'ds/lisp-evil-args-setup)
