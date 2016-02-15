;; Emacs options and keys for C++

;; Clear existing keys
(set 'c++-mode-map (make-sparse-keymap))

;; Set .h files to use c++ mode
(add-to-list 'auto-mode-alist '("\\.h\\'" . c++-mode))

(defun indent-buffer ()
  "Re-indent the whole buffer"
  (interactive)
  ;; (delete-trailing-whitespace)
  (indent-region (point-min) (point-max) nil))

;; Endings to look for with find other file. First entry will be used if we
;; are creating it.
(setq cc-other-file-alist
      (quote
       (("\\.cc\\'" (".hh" ".h"))
        ("\\.hh\\'" (".cc" ".C"))
        ("\\.c\\'" (".h"))
        ("\\.h\\'" (".cpp" ".cc" ".c" ".C" ".CC" ".cxx"))
        ("\\.C\\'" (".H" ".hh" ".h"))
        ("\\.H\\'" (".C" ".CC"))
        ("\\.CC\\'" (".HH" ".H" ".hh" ".h"))
        ("\\.HH\\'" (".CC"))
        ("\\.c\\+\\+\\'" (".h++" ".hh" ".h"))
        ("\\.h\\+\\+\\'" (".c++"))
        ("\\.cpp\\'" (".hpp" ".hh" ".h"))
        ("\\.hpp\\'" (".cpp"))
        ("\\.cxx\\'" (".hxx" ".hh" ".h"))
        ("\\.hxx\\'" (".cxx")))))

;; Don't try to open includes etc (it never works...)
(set 'ff-special-constructs nil)

;; Bind it
(define-key c++-mode-map (kbd "C-\\ o") #'ff-find-other-file)
(define-key c++-mode-map (kbd "C-\\ C-o") #'ff-find-other-file)


;; For use in snippets
(defun cpp-to-h-path (cpp-path)
  (replace-regexp-in-string "\\.cpp" ".h" cpp-path))


(defun cpp-access-function ()
  "Create set and get access functions for the selected member
variable. Cannot deal with keywords like static or const. These
access functions are BAD for class access (too much copying)."
  (let* ((var-string
          (replace-regexp-in-string ";" "" (buffer-substring (region-beginning)
                                                             (region-end))))
         (var-string-list (split-string var-string))
         (var-type (car var-string-list))
         (var-name (cadr var-string-list)))
    (concat
     (format "/// \\short Non-const access function for %s.\n" var-name)
     (format "%s& %s() {return %s;}\n\n" var-type (downcase var-name) var-name)
     (format "/// \\short Const access function for %s.\n" var-name)
     (format "%s %s() const {return %s;}\n\n" var-type (downcase var-name) var-name))))

(defun cpp-access-function-kill-ring ()
  "Add access functions for selected member variable to kill ring."
  (interactive)
  (kill-new (cpp-access-function)))

(defun auto-bracify ()
  "Find first if/for/... expression in region and make sure it has braces"
  (interactive)
  (save-excursion
    (goto-char (region-beginning))
    (when (search-forward-regexp
           "\\(^[ \t]*\\)\\(else if\\|if\\|else\\|for\\|while\\)[ \t]*(.*)"
           (region-end) t)
      (newline-and-indent)
      (insert "{")
      (newline-and-indent) (end-of-line) (newline-and-indent)
      (insert "}"))))


(require 'company)
(defun ds/set-up-completion ()
  (interactive)
  (set (make-local-variable 'company-backends)
       (list (list 'company-dabbrev-code 'company-files 'company-yasnippet 'company-keywords))))

(add-hook 'c++-mode-hook #'ds/set-up-completion)


;; Parse cppcheck output
(require 'compile)
(add-to-list 'compilation-error-regexp-alist-alist
             '(cppcheck "\\[\\([^]]*\\):\\([0-9]+\\)\\]:" 1 2))
(add-to-list 'compilation-error-regexp-alist 'cppcheck)


;; Parse boost test REQUIRE macro output
(require 'compile)
(add-to-list 'compilation-error-regexp-alist-alist
             '(boost-test-require "^\\(.*\\)(\\([0-9]*\\)): fatal error" 1 2))
(add-to-list 'compilation-error-regexp-alist 'boost-test-require)
