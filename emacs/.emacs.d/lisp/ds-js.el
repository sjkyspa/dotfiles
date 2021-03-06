;; -*- lexical-binding: t -*-

(require 'js)
(require 'simple)

(validate-setq js-switch-indent-offset js-indent-level)

(defun ds/js-electric-layout-rules ()
  (interactive)
  (add-to-list 'electric-layout-rules (cons ?\; nil))
  (add-to-list 'electric-layout-rules (cons ?{ nil))
  (electric-layout-mode 0))
(add-hook 'js-mode-hook #'ds/js-electric-layout-rules)

(add-hook 'js-mode-hook #'electric-operator-mode)
(add-hook 'js-mode-hook #'aggressive-indent-mode)

(require 'align)
(add-to-list 'align-sq-string-modes 'js-mode)

(require 'grep)
(add-to-list 'grep-find-ignored-files "*.min.js")
(add-to-list 'grep-find-ignored-files "*.min.js.map")

;; Don't really know what these are but they show up in the biosite repo
(add-to-list 'grep-find-ignored-files "*.bmml")

;; Show function as lambda. Append prettify-symbols-mode so that symbol for
;; function is added before the mode is enabled.
(defun ds/pretty-function ()
  (add-to-list 'prettify-symbols-alist '("function" . 955)))
(add-hook 'js-mode-hook #'ds/pretty-function)
(add-hook 'js-mode-hook #'prettify-symbols-mode t)

(defun js-extra-keywords (mode)
  (font-lock-add-keywords
   mode '(
          ;; Jasmine
          ("\\<\\(expect\\)\\>" 1 font-lock-keyword-face)
          ("\\<\\(it\\)\\>" 1 font-lock-keyword-face)
          ("\\<\\(describe\\)\\>" 1 font-lock-keyword-face)

          ;; Promises
          ("\\.\\<\\(then\\)\\>" 1 font-lock-keyword-face)

          ;; Angular
          ("\\.\\<\\(controller\\)\\>" 1 font-lock-keyword-face)
          ("\\.\\<\\(directive\\)\\>" 1 font-lock-keyword-face)
          ("\\.\\<\\(factory\\)\\>" 1 font-lock-keyword-face)
          ("\\.\\<\\(service\\)\\>" 1 font-lock-keyword-face)
          ("\\.\\<\\(component\\)\\>" 1 font-lock-keyword-face)
          ("[^_]\\.\\<\\(filter\\)\\>" 1 font-lock-keyword-face)

          ("^\\s-\\(\\.\\)" 1 font-lock-keyword-face)
          ))
  )

(js-extra-keywords 'js-mode)


(defun ds/switch-to-html ()
  (interactive)
  (if (s-contains? ".spec.js" (buffer-file-name))
      (ds/switch-to-related ".html" (file-name-sans-extension (buffer-file-name)))
    (ds/switch-to-related ".html")))
(define-key js-mode-map (kbd "C-\\ o") #'ds/switch-to-html)

(defun ds/js-switch-to-test ()
  (interactive)
  (cond ((s-contains? ".spec.js" (buffer-file-name))
         (ds/switch-to-related ".js" (file-name-sans-extension (buffer-file-name))))
        ((s-contains? ".spec.ts" (buffer-file-name))
         (ds/switch-to-related ".ts" (file-name-sans-extension (buffer-file-name))))
        ((s-contains? ".js" (buffer-file-name))
         (ds/switch-to-related ".spec.js"))
        ((s-contains? ".ts" (buffer-file-name))
         (ds/switch-to-related ".spec.ts"))))
(define-key js-mode-map (kbd "C-\\ n") #'ds/js-switch-to-test)

;; flycheck config
(require 'flycheck)

(validate-setq flycheck-javascript-eslint-executable "eslint-cli")

(defcustom ds/use-future-eslintrc t "use the eslintrc in boron web_applications?")

(defun ds/maybe-future-eslintrc ()
  (let ((future-eslint
         (-find #'f-file?
                (list (f-join (projectile-project-root) "boron" "web_applications" "future-eslintrc.json")
                      (f-join (projectile-project-root) "boron" "web_applications" "future-eslintrc-temp.json"))))
        (future-eslint-ts
         (f-join (projectile-project-root) "boron" "web_applications" "future-eslintrc-ts.json")))
    (if (and future-eslint ds/use-future-eslintrc)
        (if (derived-mode-p 'typescript-mode)
            future-eslint-ts
          future-eslint)
      nil)))

(defun ds/toggle-future-eslintrc ()
  (interactive)
  (flycheck-mode 0)
  (setq-local ds/use-future-eslintrc (not ds/use-future-eslintrc))
  (setq-local flycheck-eslintrc (ds/maybe-future-eslintrc))
  (flycheck-mode 1))

(defun ds/js-flycheck-setup ()
  (interactive)
  (setq-local flycheck-checker 'javascript-eslint)
  (setq-local flycheck-eslintrc (ds/maybe-future-eslintrc))
  (add-to-list 'flycheck-disabled-checkers 'javascript-jscs)
  (flycheck-mode))
(add-hook 'js-mode-hook #'ds/js-flycheck-setup)



(add-to-list 'auto-mode-alist '("\\.jshintrc\\'" . js-mode))



(use-package json-mode
  :ensure t
  :config

  (defun setup-json-indent ()
    (interactive)
    (setq-local indent-tabs-mode nil)
    (setq-local js-indent-level 2))
  (add-hook 'json-mode-hook #'setup-json-indent)

  (add-hook 'json-mode-hook (lambda () (biosite-mode 0)) t)
  (add-hook 'json-mode-hook (lambda () (flycheck-mode 0)) t)
  (add-hook 'json-mode-hook (lambda () (aggressive-fill-paragraph-mode 0)) t)

  (defun ds/set-json-mode (fname)
    (add-to-list 'auto-mode-alist (cons fname 'json-mode)))
  (-map #'ds/set-json-mode (list ".bowerrc" ".jscsrc"))
  )

(defun ds/search-return-point (string)
  (save-excursion
    (search-forward string)
    (point)))

(defun ds/assign-to-copy ()
  (interactive)
  (let ((start (point))
        (copy-target (buffer-substring (point) (ds/search-return-point "="))))
    (insert "angular.copy(")
    (delete-region (point) (ds/search-return-point "= "))
    (search-forward ";")
    (delete-char -1)
    (insert ", ")
    (insert copy-target)
    (delete-char -2) ;; assumes that the = is spaced correctly
    (insert ");")

    ;; Tidy up
    (forward-char -2)
    (fill-function-arguments-to-single-line)
    (fill-function-arguments-to-multi-line)
    (forward-char 2)
    (indent-region start (point))
    )
  )

(provide 'ds-js)
