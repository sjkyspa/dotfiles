;; Generic emacs settings, other stuff is in individual files in ./lisp/

;; test with compile command: \emacs --debug-init --batch -u $USER

;; Use package instead of el-get?


;; Use C-\ p as prefix
(set 'projectile-keymap-prefix (kbd "C-\\ p"))


(defvar emacs244?
  (and (>= emacs-major-version 24) (>= emacs-minor-version 4))
  "Are we using emacs 24.4 or newer?")



;; Set up "package" package manager
;; ============================================================

(require 'package)
(add-to-list 'package-archives
             '("melpa-stable" . "http://melpa-stable.milkbox.net/packages/") t)
(add-to-list 'package-archives '("melpa" . "http://melpa.milkbox.net/packages/") t)
(package-initialize)



;; install + setup el-get
;; ============================================================

(add-to-list 'load-path "~/.emacs.d/el-get/el-get")

;; Install el-get if we don't have it
(unless (require 'el-get nil 'noerror)
  (with-current-buffer
      (url-retrieve-synchronously
       "https://raw.github.com/dimitri/el-get/master/el-get-install.el")
    (let (el-get-master-branch)
      (goto-char (point-max))
      (eval-print-last-sexp))))

(add-to-list 'el-get-recipe-path "~/.emacs.d/my-recipes")

(el-get 'sync)


;; Other things that need to go first for some reason
;; ============================================================

;; Load the use-package lib which adds a nice macro for keeping package
;; config all wrapped up together
(require 'ert) ; Need this for now...
(load-library "bind-key")
(load-library "use-package")


(use-package aggressive-indent
  :config
  (progn (global-aggressive-indent-mode)
         (define-key aggressive-indent-mode-map (kbd "C-c") nil)

         (add-hook 'c-mode-common-hook
                   (lambda () (define-key c-mode-map (kbd "C-d") nil)))
         ))


;; Some simple, one-line stuff
;; ============================================================
;; (server-start) ;; Start emacs as a server
(line-number-mode 1) ;; Line numbers in mode line
(column-number-mode 1) ;; Column numbers in mode line
(global-linum-mode t) ;; Line numbers on edge of screen
(set 'backup-directory-alist '(("." . ".~"))) ;; Keep backups in .~/
(set 'inhibit-startup-screen t) ;; No startup screen
(set-scroll-bar-mode 'right);; Scroll bar on the right
(global-visual-line-mode 1) ;; Wrap lines at nearest word
(global-subword-mode 1) ;; Treat CamelCase as separate words
(set 'truncate-partial-width-windows nil) ;; Make line wrapping work for
;; multiple frames
(tool-bar-mode -1) ;; Disable toolbar
(menu-bar-mode -1) ;; Disable menu bar
(defalias 'yes-or-no-p 'y-or-n-p) ;; y/n instead of yes/no
(show-paren-mode 1) ;; Highlight matching parenthesis
(setq-default fill-column 75) ;; not 80 because when things are later indented
;; by e.g. diff, git log we lose some columns and
;; it gets messy.
(set 'default-abbrev-mode t) ;; Use abbrev mode always
(set 'tags-revert-without-query 1) ;; Autorevert if the tags table has changed

;; Shut up and just open symbolic links
(set 'vc-follow-symlinks t)

;; Allow some disabled commands
(put 'narrow-to-region 'disabled nil)

;; Set the location for bookmarks
(set 'bookmark-default-file "~/.emacs.d/bookmarks")

;; save point in file
(setq-default save-place t)

;; Auto-newlines after { } etc.
;; (add-hook 'c-mode-common-hook '(lambda () (c-toggle-auto-newline 1)))

;; Use chrome not firefox to open urls
(set 'browse-url-browser-function 'browse-url-generic)
(set 'browse-url-generic-program "firefox")

;; Draw a line accross the screen instead of ^L for page breaks
(global-page-break-lines-mode t)

;; Show messages on startup, not the stupid scratch buffer
(switch-to-buffer "*Messages*")

;; Set the default font
(set-face-attribute 'default '()
                    :family "DejaVu Sans Mono"
                    :height 98)

;; Highlight long lines
(require 'whitespace)
(set 'whitespace-line-column 80) ;; limit line length
(set 'whitespace-style '(face lines-tail))

(add-hook 'prog-mode-hook 'whitespace-mode)

;; Don't create lockfiles (only safe on single user systems and in ~/ dir
;; technically, but I don't think I'll ever be messing with admin server
;; config files so it's probably fine). Stops emacs spamming up directories
;; with .# files.
(set 'create-lockfiles nil)

;; Show keystrokes in progress (eg show C-\ immediately)
(setq echo-keystrokes 0.1)

;; Allow recursive minibuffers
(setq enable-recursive-minibuffers t)

;; Don't be so stingy on the memory, we have lots now. It's the distant future.
(setq gc-cons-threshold 20000000)

;; Sentences do not need double spaces to end (so when moving by sentence
;; use "." to find ends).
(set-default 'sentence-end-double-space nil)


;; Always revert buffer to file
(global-auto-revert-mode)


;; Saving
;; ============================================================

;; makes scripts executable automatically
(add-hook 'after-save-hook 'executable-make-buffer-file-executable-if-script-p)

;; ;; auto-save in-place
;; (setq auto-save-visited-file-name t)

;; Add a new line at end of file on save if none exists (note: doesn't play
;; nice with scheme).
(setq-default require-final-newline 0)


;; Create non-existant directories automatically
(defun my-create-non-existent-directory ()
  (let ((parent-directory (file-name-directory buffer-file-name)))
    (when (and (not (file-exists-p parent-directory))
               (y-or-n-p (format "Directory `%s' does not exist! Create it?" parent-directory)))
      (make-directory parent-directory t))))
(add-to-list 'find-file-not-found-functions #'my-create-non-existent-directory)


;; Use frames instead of emacs "windows"
;; ============================================================
(load-file "~/.emacs.d/frames-only-mode/frames-only-mode.el")
(use-package frames-only-mode)

;; Copy/Paste interaction with other X11 applications
;; ============================================================

;; Stop selected regions always overwriting the X primary selection (for
;; example when we briefly select the emacs window and it happens to have
;; some text selected from earlier, without this setting the old text would
;; be put into the primary selection). With this setting only explicit
;; selection with the mouse puts things into the primary selection.
(set 'select-active-regions 'only)

;; after copy Ctrl+c in X11 apps, you can paste by 'yank' in emacs
(setq x-select-enable-clipboard t)

;; after mouse selection in X11, you can paste by 'yank' in emacs
(setq x-select-enable-primary t)

;; Middle click pastes at point not at click position (like in term)
(set 'mouse-yank-at-point 1)


;; Improving Auto complete in minibuffer
;; ============================================================


;; Use ido
(use-package
 ido

 :config
 (progn
   (ido-mode t)

   ;; (for all buffer/file name entry)
   (ido-everywhere)

   ;; Change some keys in ido
   (defun my-ido-keys ()
     (define-key ido-completion-map (kbd "C-j") 'ido-next-match)
     (define-key ido-completion-map (kbd "C-k") 'ido-prev-match)
     (define-key ido-completion-map (kbd "C-n") 'ido-select-text)
     (define-key ido-completion-map " " '())
     (define-key ido-completion-map (kbd "S-TAB") 'ido-prev-match)
     ;; Not sure why shift-tab = <backtab> but it works...
     (define-key ido-completion-map (kbd "<backtab>") 'ido-prev-match))

   (add-hook 'ido-setup-hook 'my-ido-keys t)

   ;; Display ido results vertically, rather than horizontally
   (set 'ido-decorations '("\n-> " "" "\n   " "\n   ..." "[" "]" " [No match]"
                           " [Matched]" " [Not readable]" " [Too big]"
                           " [Confirm]"))

   ;; Enable some fuzzy matching
   (set 'ido-enable-flex-matching t)

   ;; Allow completion (and opening) of buffers that are actually closed.
   (set 'ido-use-virtual-buffers t)

   ;; Not sure if this works yet, supposed to add dir info for duplicate
   ;; virtual buffers.
   (set 'ido-handle-duplicate-virtual-buffers 4)

   ;; increase number of buffers to rememeber
   (set 'recentf-max-saved-items 1000)

   ;; Cycle through commands with tab if we can't complete any further.
   (set 'ido-cannot-complete-command 'ido-next-match)

   ;; Use ido style completion everywhere (separate package)
   ;;(ido-ubiquitous-mode t)

   ;; Buffer selection even if already open elsewhere
   (set 'ido-default-buffer-method 'selected-window)

   ;; Create new buffers without prompting
   (set 'ido-create-new-buffer 'always)

   ;; ??ds Add ignore regex for useless files


   ;; smex: ido based completion for commands
   ;; ============================================================

   ;; Change the main keybinding
   (global-set-key [remap execute-extended-command] 'smex)

   ;; Another key: only list commands relevant to this major mode.
   (global-set-key (kbd "M-|") 'smex-major-mode-commands)

   ;; Tell the prompt that I changed the binding for running commands
   ;; (elsewhere)
   (set 'smex-prompt-string "M-\\: ")

   ;; Put its save file in .emacs.d
   (set 'smex-save-file "~/.emacs.d/smex-items")

   ;; Change some keys in smex itself
   (defun smex-prepare-ido-bindings ()
     (define-key ido-completion-map (kbd "<f1>") 'smex-describe-function)
     (define-key ido-completion-map (kbd "M-.") 'smex-find-function))


   ;; ;; ido for tags
   ;; ;; ============================================================
   ;; (defun my-ido-find-tag ()
   ;;   "Find a tag using ido"
   ;;   (interactive)
   ;;   (tags-completion-table)
   ;;   (let (tag-names)
   ;;     (mapc (lambda (x)
   ;;             (unless (integerp x)
   ;;               (push (prin1-to-string x t) tag-names)))
   ;;           tags-completion-table)
   ;;     (find-tag (ido-completing-read "Tag: " tag-names))))

   ;; ;; From
   ;; ;; http://stackoverflow.com/questions/476887/can-i-get-ido-mode-style-completion-for-searching-tags-in-emacs

   ;; (define-key global-map [remap find-tag] 'my-ido-find-tag)


   ;; ido for help functions
   ;; ============================================================

   ;; There's a whole bunch of code here that I don't really understand, I
   ;; took it from
   ;; https://github.com/tlh/emacs-config/blob/master/tlh-ido.el


   (defmacro aif (test then &rest else)
     `(let ((it ,test))
        (if it ,then ,@else)))

   (defmacro cif (&rest args)
     "Condish `if'"
     (cond ((null args) nil)
           ((null (cdr args)) `,(car args))
           (t `(if ,(car args)
                   ,(cadr args)
                 (cif ,@(cddr args))))))

   (defmacro aand (&rest args)
     (cif (null args)        t
          (null (cdr args))  (car args)
          `(aif ,(car args)  (aand ,@(cdr args)))))

   (defun ido-cache (pred &optional recalc)
     "Create a cache of symbols from `obarray' named after the
predicate PRED used to filter them."
     (let ((cache (intern (concat "ido-cache-" (symbol-name pred)))))
       (when (or recalc (not (boundp cache)))
         (set cache nil)
         (mapatoms (lambda (s)
                     (when (funcall pred s)
                       (push (symbol-name s) (symbol-value cache))))))
       (symbol-value cache)))

   (defun ido-describe-function (&optional at-point)
     "ido replacement for `describe-function'."
     (interactive "P")
     (describe-function
      (intern
       (ido-completing-read
        "Describe function: "
        (ido-cache 'functionp) nil nil
        (aand at-point (function-called-at-point)
             (symbol-name it))))))

   (defun ido-describe-variable (&optional at-point)
     "ido replacement for `describe-variable'."
     (interactive "P")
     (describe-variable
      (intern
       (ido-completing-read
        "Describe variable: "
        (ido-cache 'boundp) nil nil
        (aand at-point (thing-at-point 'symbol) (format "%s" it))))))

   (global-set-key (kbd "<f1> f") 'ido-describe-function)
   (global-set-key (kbd "<f1> v") 'ido-describe-variable)



   ;; Even better fuzzy search for ido
   ;; ============================================================
   (use-package flx-ido
     :config (progn (flx-ido-mode 1)
                    (setq ido-use-faces nil)))


   )
 )



;; Auto complete
;;================================================================
(require 'auto-complete-config)
(require 'fuzzy)
(require 'pos-tip)
(add-to-list 'ac-dictionary-directories "~/.emacs.d/ac-dict")

;; Options from
(ac-config-default)

(global-auto-complete-mode t)
(set 'ac-ignore-case nil)
(set 'ac-use-fuzzy t)
(set 'ac-fuzzy-enable t)
(ac-flyspell-workaround)

;; Show quick help (function info display in tooltip)
;; (set 'ac-use-quick-help t)
(set 'ac-delay 0.5) ;; show completions quickly

;; help is too annoying, press f1 to get it
;; ;; (set 'ac-show-menu-immediately-on-auto-complete 1)
;; (set 'ac-quick-help-delay my-ac-delay) ;; show help as soon as it shows
;;                                        ;; completions

;; let me search even while autocomplete is up!
(define-key ac-complete-mode-map (kbd "C-s") nil)

;; Use f1 to show help in a buffer! Handy :) Don't even need to bind
;; anything!


;; Undo tree
;;================================================================
(use-package
 undo-tree
 :config
 (progn
   ;; wipe it's keybinds
   (add-to-list 'minor-mode-map-alist '('undo-tree-mode (make-sparse-keymap)))

   ;; Use it everywhere
   (global-undo-tree-mode))

 )



;; Load my other config files
;; ============================================================

(add-to-list 'load-path "~/.emacs.d/lisp")

;; Load skeletons
(load-file "~/.emacs.d/skeletons.el")

;; Load configs from other files
(load-file "~/.emacs.d/lisp/cpp.el")
(load-file "~/.emacs.d/lisp/colours.el")
(load-file "~/.emacs.d/lisp/latex.el")
(load-file "~/.emacs.d/lisp/oomph-lib.el")
(load-file "~/.emacs.d/lisp/scheme.el")
(load-file "~/.emacs.d/lisp/octave.el")
(load-file "~/.emacs.d/lisp/my-matlab.el")
(load-file "~/.emacs.d/lisp/org.el")
(load-file "~/.emacs.d/lisp/my-python.el") ;; python-mode is in file called python.el
(load-file "~/.emacs.d/lisp/unicode-entry.el")
(load-file "~/.emacs.d/lisp/haskell.el")
(load-file "~/.emacs.d/lisp/elisp.el")
(load-file "~/.emacs.d/lisp/java.el")



;; Major changes to keybinds
;; Needs to after other file loads so that hooks are in scope
(load-file "~/.emacs.d/lisp/sensible-keys.el")


;; Save command history between sessions
;; ===============================================================

;; Save into a helpfully named file
(set 'savehist-file "~/.emacs.d/savehist")

;; Save other things as well
(set 'savehist-additional-variables '(kill-ring
                                      search-ring
                                      regexp-search-ring
                                      compile-command))

;; Enable save history (must be done after changing any variables).
(savehist-mode 1)


;; Compile mode settings
;; ===============================================================

;; Define + active modification to compile that locally sets
;; shell-command-switch to "-ic".
(defadvice compile (around use-bashrc activate)
  "Load .bashrc in any calls to bash (e.g. so we can use aliases)"
  (let ((shell-command-switch "-ic"))
    ad-do-it))

(defadvice recompile (around use-bashrc activate)
  "Load .bashrc in any calls to bash (e.g. so we can use aliases)"
  (let ((shell-command-switch "-ic"))
    ad-do-it))

(defun my-recompile ()
  "Recompile if possible, otherwise compile current buffer."
  (interactive)
  ;; If recompile exists do it, else compile
  (if (fboundp 'recompile) (recompile)
    (compile "make -k")))

(add-hook 'compilation-mode-hook 'my-compilation-mode-keys)
(add-hook 'compilation-shell-mode-hook 'my-compilation-mode-keys)

(defun my-compilation-mode-keys ()
  (local-set-key (kbd "<f5>") 'my-recompile)
  (local-set-key (kbd "<C-f5>") 'compile)
  (local-set-key (kbd "C-`") 'next-error)
  (local-set-key (kbd "C-¬") 'previous-error)
  (local-set-key (kbd "M-`") 'toggle-skip-compilation-warnings))

(defun toggle-skip-compilation-warnings ()
  (interactive)
  (if (equal compilation-skip-threshold 1)
      (set 'compilation-skip-threshold 2)
    (set 'compilation-skip-threshold 1)))

;; scroll compilation buffer to first error
(setq compilation-scroll-output 'first-error)

;; Autosave all modified buffers before compile
(set 'compilation-ask-about-save nil)

;; Handle colours in compile buffers
(require 'ansi-color)
(defun colorize-compilation-buffer ()
  (toggle-read-only)
  (ansi-color-apply-on-region (point-min) (point-max))
  (toggle-read-only))
(add-hook 'compilation-filter-hook 'colorize-compilation-buffer)


(global-set-key (kbd "<f5>") 'my-recompile)
(global-set-key (kbd "C-<f5>") 'compile)

(global-set-key (kbd "C-`") 'next-error)
(global-set-key (kbd "C-¬") 'previous-error)


;; My functions
;; ============================================================
(defun copy-file-name ()
  "Add `buffer-file-name' to the kill ring."
  (interactive)
  (if (not (stringp buffer-file-name))
      (error "Not visiting a file.")
    (kill-new (file-name-nondirectory buffer-file-name))
    ;; Give some visual feedback:
    (message "String \"%s\" saved to kill ring."
             (file-name-nondirectory buffer-file-name))
    buffer-file-name))


(defun copy-file-path ()
  "Add `buffer-file-name' to the kill ring."
  (interactive)
  (if (not (stringp buffer-file-name))
      (error "Not visiting a file.")
    (kill-new buffer-file-name)
    ;; Give some visual feedback:
    (message "String \"%s\" saved to kill ring." buffer-file-name)
    buffer-file-name))


(defun smart-beginning-of-line ()
  "Move point to first non-whitespace character or beginning-of-line.
Move point to the first non-whitespace character on this line.
If point was already at that position, move point to beginning of line."
  (interactive "^")
  (let ((oldpos (point)))
    (back-to-indentation)
    (and (= oldpos (point))
         (beginning-of-line))))


;; ;; what I would like here is something like:
;; (defun just-one-space-dwim
;;   "If there are spaces or tabs to delete then delete them,
;; otherwise delete and newlines AND spaces and tabs"
;;   (interactive)
;;   (if (no-spaces-or-tabs-nearby)
;;       (just-one-space -1)
;;     (just-one-space)))
;; (global-set-key (kbd "M-SPC") 'just-one-space-dwim)
;; ;; Similarly for (kbd "M-\") kill-all-whitespace-dwim
;; ;; instead (for now) just use M-^ : delete-indentation

(require 's)

(defun insert-comment-header ()
  "Insert a line of '=' on the following line and comment it."
  (interactive)
  (save-excursion

    ;; Comment the current line if necessary (not a comment, or empty)
    (when (or (not (comment-only-p (point-at-bol) (point-at-eol)))
              (string-match-p "^[ ]*$" (thing-at-point 'line)))
      (indent-for-tab-command)
      (back-to-indentation)
      (insert comment-start) (just-one-space)
      (end-of-line) (insert comment-end))

    ;; Add an underline and comment it
    (end-of-line)
    (newline-and-indent)
    (back-to-indentation) (insert comment-start)
    (just-one-space) ; Some "comment-start"s include a space
    (insert (s-repeat 60 "="))
    (end-of-line) (insert comment-end)
    (newline-and-indent))

  ;; Position point ready to type or continue typing the header
  (end-of-line))


(defun un-camelcase-string (s &optional sep start)
  "Convert CamelCase string S to lower case with word separator SEP.
Default for SEP is a hyphen \"-\".

If third argument START is non-nil, convert words after that
index in STRING."
  (let ((case-fold-search nil))
    (while (string-match "[A-Z]" s (or start 1))
      (setq s (replace-match (concat (or sep "_")
                                     (downcase (match-string 0 s)))
                             t nil s)))
    (downcase s)))


(defun un-camelcase-word ()
  (interactive)
  (let ((camel-word (buffer-substring (point)
				      (save-excursion (forward-word) (point)))))
    (kill-word 1)
    (insert-string (un-camelcase-string camel-word))))


(defun generate-org-buffer ()
  (interactive)
  (switch-to-buffer (make-temp-name "scratch"))
  (org-mode))


(defun clean-whitespace-and-save ()
  (interactive)
  (delete-trailing-whitespace)
  (save-buffer))


;; from https://code.google.com/p/ergoemacs/source/browse/packages/xfrp_find_replace_pairs.el
(defun replace-pairs-region (p1 p2 pairs)
  "Replace multiple PAIRS of find/replace strings in region P1 P2.

PAIRS should be a sequence of pairs [[findStr1 replaceStr1] [findStr2 replaceStr2] …] It can be list or vector, for the elements or the entire argument.

The find strings are not case sensitive. If you want case sensitive, set `case-fold-search' to nil. Like this: (let ((case-fold-search nil)) (replace-pairs-region …))

The replacement are literal and case sensitive.

Once a subsring in the input string is replaced, that part is not changed again.  For example, if the input string is “abcd”, and the pairs are a → c and c → d, then, result is “cbdd”, not “dbdd”. If you simply want repeated replacements, use `replace-pairs-in-string-recursive'.

Same as `replace-pairs-in-string' except does on a region.

Note: the region's text or any string in pairs is assumed to NOT contain any character from Unicode Private Use Area A. That is, U+F0000 to U+FFFFD. And, there are no more than 65534 pairs."
  (let (
        (unicodePriveUseA #xf0000)
        ξi (tempMapPoints '()))
    ;; generate a list of Unicode chars for intermediate replacement. These chars are in  Private Use Area.
    (setq ξi 0)
    (while (< ξi (length pairs))
      (setq tempMapPoints (cons (char-to-string (+ unicodePriveUseA ξi)) tempMapPoints ))
      (setq ξi (1+ ξi))
      )
    (save-excursion
      (save-restriction
        (narrow-to-region p1 p2)

        ;; replace each find string by corresponding item in tempMapPoints
        (setq ξi 0)
        (while (< ξi (length pairs))
          (goto-char (point-min))
          (while (search-forward (elt (elt pairs ξi) 0) nil t)
            (replace-match (elt tempMapPoints ξi) t t) )
          (setq ξi (1+ ξi))
          )

        ;; replace each tempMapPoints by corresponding replacement string
        (setq ξi 0)
        (while (< ξi (length pairs))
          (goto-char (point-min))
          (while (search-forward (elt tempMapPoints ξi) nil t)
            (replace-match (elt (elt pairs ξi) 1) t t) )
          (setq ξi (1+ ξi)) ) ) ) ) )


(defun change-bracket-pairs (fromType toType)
  "Change bracket pairs from one type to another on text selection or text block.
For example, change all parenthesis () to square brackets [].

When called in lisp program, fromType and toType is a string of a bracket pair. ⁖ \"()\", likewise for toType."
  (interactive
   (let (
         (bracketTypes '("[]" "()" "{}" "“”" "‘’" "〈〉" "《》" "「」" "『』" "【】" "〖〗"))
         )
     (list
      (ido-completing-read "Replace this:" bracketTypes )
      (ido-completing-read "To:" bracketTypes ) ) ) )

  (let* (
         (p1 (if (region-active-p) (region-beginning) (point-min)))
         (p2 (if (region-active-p) (region-end) (point-max)))
         (changePairs (vector
                       (vector (char-to-string (elt fromType 0)) (char-to-string (elt toType 0)))
                       (vector (char-to-string (elt fromType 1)) (char-to-string (elt toType 1)))
                       ))
         )
    (replace-pairs-region p1 p2 changePairs) ) )




(global-set-key [home] 'smart-beginning-of-line)
(global-set-key (kbd "C-b") 'smart-beginning-of-line)
(global-set-key (kbd "C-\\ ;") 'insert-comment-header)
(global-set-key (kbd "C-\\ k") 'generate-org-buffer)

;; from emacs wiki
(defun revert-all-buffers ()
  "Refreshes all open buffers from their respective files."
  (interactive)
  (dolist (buf (buffer-list))
    (with-current-buffer buf
      (when (and (buffer-file-name)
                 (file-exists-p (buffer-file-name))
                 (not (buffer-modified-p)))
        (revert-buffer t t t) )))
  (message "Refreshed open files.") )



;; Tramp
;; ============================================================

;; set to use ssh
(set 'tramp-default-method "ssh")

;; store backups on my computer
;; (set 'tramp-backup-directory-alist  ??ds


;; Transparency
;; ============================================================

;; Set transparency of emacs
(defun transparency (value)
  "Sets the transparency of the frame window. 0=transparent/100=opaque"
  (interactive "nTransparency Value 0 - 100 opaque:")
  (set-frame-parameter (selected-frame) 'alpha value))

;; No scroll bar is much prettier, lets see if we can live without it
(scroll-bar-mode -1)

;; Set default transparencies:
;;(set-frame-parameter (selected-frame) 'alpha '(<active> [<inactive>]))
(add-to-list 'default-frame-alist '(alpha 85 85))

(set 'edge-background-colour "greasy2")

;; Set all the areas around the edge to be slightly lighter
(set-face-background 'modeline-inactive edge-background-colour)
(set-face-background 'fringe edge-background-colour)
(set-face-background 'linum edge-background-colour)
(set-face-background 'menu edge-background-colour)

;; To get rid of the box around inactive modeline I used custom to set it
;; to the same colour... hacky :(

;; Nice dim line number font colour
(set-face-foreground 'linum "grey20")

;; Set the inactive frame modeline font: Remove the background and the box
;; around it.
(set-face-attribute 'mode-line-inactive nil
		    :background edge-background-colour
		    :box nil)





;; Auto indent pasted code in programming modes
;; ============================================================
(dolist (command '(yank yank-pop))
  (eval `(defadvice ,command (after indent-region activate)
	   (and (not current-prefix-arg)
		(member major-mode '(emacs-lisp-mode lisp-mode clojure-mode
						     scheme-mode ruby-mode rspec-mode
						     c-mode c++-mode objc-mode latex-mode
						     plain-tex-mode))
		(let ((mark-even-if-inactive transient-mark-mode))
		  (indent-region (region-beginning) (region-end) nil))))))


;; Git
;; ============================================================

;; Use org-mode for git commits
(set 'auto-mode-alist
     (append auto-mode-alist '(("COMMIT_EDITMSG" . markdown-mode))))

;; Show changes vs VC in sidebar
(set 'diff-hl-command-prefix (kbd "C-\\ v"))
(global-diff-hl-mode)


;; Markdown mode
;; ============================================================

(use-package markdown-mode
  :config
  (progn
    ;; run markdown-mode on files ending in .md
    (set 'auto-mode-alist
         (append auto-mode-alist '((".md" . markdown-mode)
                                   (".markdown" . markdown-mode))))
    (defun markdown-mode-keys ()
      (interactive)

      ;; get rid of C-c binds
      (local-set-key (kbd "C-c") nil)

      ;; Compile = preview
      (local-set-key [remap compile] 'markdown-preview)
      (local-set-key [remap my-recompile] 'markdown-preview)

      )


    (add-hook 'markdown-mode-hook 'markdown-mode-keys))
  )

;; Bind goto last change
;; ============================================================

(use-package goto-last-change
             :config
             (progn
               (global-set-key (kbd "C-\\ C-x") 'goto-last-change)))


;; Breadcrumbs
;; ============================================================

(use-package breadcrumb
             :config
             (progn

               ;; Bind some keys
               (global-set-key (kbd "M-b") 'bc-set)
               (global-set-key (kbd "M-B") 'bc-clear)
               (global-set-key [(meta up)] 'bc-previous)
               (global-set-key [(meta down)] 'bc-next)
               (global-set-key [(meta left)] 'bc-local-previous)
               (global-set-key [(meta right)] 'bc-local-next)

               ;; Auto bookmark before isearch
               (add-hook 'isearch-mode-hook 'bc-set)

               ;; Already auto bookmark before tag search and query replace
               ))



;; Registers
;; ============================================================

(use-package list-register)
(global-set-key (kbd "C-\\ r v") 'list-register)
(global-set-key (kbd "C-\\ r s") 'copy-to-register)
(global-set-key (kbd "C-\\ r i") 'insert-register)


;; Mode line
;; ============================================================

;; (defvar mode-line-cleaner-alist
;;   `((auto-complete-mode . "")
;;     (yas/minor-mode . "")
;;     (paredit-mode . "")
;;     (eldoc-mode . "")
;;     (abbrev-mode . "")
;;     (page-break-lines-mode . "")
;;     (visual-line-mode . "")
;;     (global-visual-line-mode . "")
;;     (whitespace-mode "")
;;     (undo-tree-mode "")

;;     ;; Major modes
;;     (lisp-interaction-mode . "λ ")
;;     (hi-lock-mode . "")
;;     (python-mode . "Py ")
;;     (emacs-lisp-mode . "EL ")
;;     (nxhtml-mode . "nx "))
;;   "Alist for `clean-mode-line'.

;; When you add a new element to the alist, keep in mind that you
;; must pass the correct minor/major mode symbol and a string you
;; want to use in the modeline *in lieu of* the original.")


;; (defun clean-mode-line ()
;;   (interactive)
;;   (loop for cleaner in mode-line-cleaner-alist
;;         do (let* ((mode (car cleaner))
;;                   (mode-str (cdr cleaner))
;;                   (old-mode-str (cdr (assq mode minor-mode-alist))))
;;              (when old-mode-str
;;                (setcar old-mode-str mode-str))
;;              ;; major mode
;;              (when (eq mode major-mode)
;;                (setq mode-name mode-str)))))

;; ;; (set 'minor-mode-alist '())
;; (add-hook 'after-change-major-mode-hook 'clean-mode-line)


;; Pretty modeline
(use-package
 smart-mode-line
 :config
 (progn (sml/setup)

        ;; Shorten some directories to useful stuff
        (add-to-list 'sml/replacer-regexp-list '("^~/oomph-lib/" ":OL:"))
        (add-to-list 'sml/replacer-regexp-list
                     '("^~/oomph-lib/user_drivers/micromagnetics" ":OLMM:"))
        (add-to-list 'sml/replacer-regexp-list '("^~/optoomph/" ":OPTOL:"))
        (add-to-list 'sml/replacer-regexp-list
                     '("^~/optoomph/user_drivers/micromagnetics" ":OPTOLMM:"))
        ))



;; ??ds new file?
;; Use double semi-colon for emacs lisp (default seems to be single).
(add-hook 'emacs-lisp-mode-hook (lambda () (setq comment-start ";;"
						 comment-end "")))



(global-set-key (kbd "C-\\") ctl-x-map)

;; Projectile
;; ============================================================
(use-package
  projectile
  :pre-load
  (progn
    ;; Use C-\ p as prefix
    (set 'projectile-keymap-prefix (kbd "C-\\ p")))

  :config
  (progn
    ;; Kill C-c keys just in case
    (define-key projectile-mode-map (kbd "C-c") nil)

    ;; Use projectile to open files by default, if available.
    (defun maybe-projectile-find-file ()
      (interactive)
      (if (projectile-project-p)
          (projectile-find-file)
        (ido-find-file)))
    (global-set-key (kbd "C-k") 'maybe-projectile-find-file)

    ;; Use everywhere
    (projectile-global-mode)
    ))



;; yasnippet?
;; ============================================================

(use-package
  yasnippet
  :config
  (progn

    ;; Load my oomph-lib snippets
    (add-to-list 'yas-snippet-dirs "~/.emacs.d/oomph-snippets" t)

    ;; kill C-c keys
    (add-hook 'yas-minor-mode-hook
              (lambda ()
                ;; (local-unset-key (kbd "C-c")
                ;; (message "Trying to unset")
                ;; (message (substitute-command-keys "\\{yas-minor-mode-map}"))
                (define-key yas-minor-mode-map (kbd "C-c & C-s") nil)
                (define-key yas-minor-mode-map (kbd "C-c & C-n") nil)
                (define-key yas-minor-mode-map (kbd "C-c & C-v") nil)
                (define-key yas-minor-mode-map (kbd "C-c &") nil)
                (define-key yas-minor-mode-map (kbd "C-c") nil)

                (define-key yas-minor-mode-map (kbd "C-i") nil)
                (define-key yas-minor-mode-map (kbd "TAB") nil)
                (define-key yas-minor-mode-map [tab] nil)


                (set 'yas-fallback-behavior nil)

                ;; (message (substitute-command-keys "\\{yas-minor-mode-map}"))

                ;; For some reason these don't work
                ;; (local-unset-key (kbd "C-c & C-s"))
                ;; (local-set-key (kbd "C-c & C-s") nil)

                ))

    ;; c-mode uses something else on tab, which seems to get messed with by
    ;; yasnippet, remove the extra bindings to prevent this
    (add-hook 'c-mode-common-hook
              (lambda ()
                (define-key c-mode-map [tab] nil)
                (define-key c++-mode-map [tab] nil)
                ;; might need to add more here?
                ))


    ;; Use everywhere
    (yas/global-mode)

    ;; Keys for snippet editing mode
    (add-hook 'snippet-mode-hook
              (lambda ()
                (interactive)
                (local-set-key (kbd "<f5>") 'yas-tryout-snippet)
                (local-set-key (kbd "C-c") nil)
                (local-set-key (kbd "<f6>") 'yas-load-snippet-buffer)
                ))

    (global-set-key (kbd "C-t") 'yas/expand)

    ;; Use minibuffer for yas prompts
    (setq yas-prompt-functions '(yas-ido-prompt))
    )
  )

;; Irony mode (fancy c/c++ autocomplete)
;; ============================================================
(use-package irony

  :disabled

  :config
  (progn
    ;; the ac plugin will be activated in each buffer using irony-mode
    (irony-enable 'ac)             ; hit C-RET to trigger completion

    ;; avoid enabling irony-mode in other modes that inherit from c-mode,
    ;; e.g: php-mode
    (defun irony-mode-if-safe ()
      (interactive)
      (when (member major-mode irony-known-modes)
        (irony-mode 1)))
    (add-hook 'c++-mode-hook 'irony-mode-if-safe)
    (add-hook 'c-mode-hook 'irony-mode-if-safe)

    ;; Kill C-c keys
    (define-key irony-mode-map (kbd "C-c") nil)

    ))


(defun external-shell-in-dir ()
  "Start urxvt in the current file's dir"
  (interactive)
  (start-process "urxvt" nil "urxvt" "-e" "zsh"))
(global-set-key (kbd "C-<f7>") 'external-shell-in-dir)


;; deft (note taking)
;; ============================================================
(use-package deft
  :config
  (progn
    (setq deft-directory "~/Dropbox/notes")
    (setq deft-extension "md")
    (setq deft-text-mode 'markdown-mode)
    (setq deft-use-filename-as-title t)

    ;; Kill C-c keys
    (define-key deft-mode-map (kbd "C-c") 'nil)

    ;; New binds for the useful ones
    (define-key deft-mode-map (kbd "M-RET") 'deft-new-file)

    ;; And move some other binds to fit with my config
    (define-key deft-mode-map (kbd "C-v") 'deft-filter-yank)
    (define-key deft-mode-map (kbd "C-y") 'deft-filter-decrement-word)

    ;; Make a new deft buffer (by killing the old one). Called from xmonad.
    (defun new-clean-deft ()
      (interactive)
      "Close old deft buffer and start a new one"
      (ignore-errors (kill-buffer "*Deft*"))
      (deft)
      )))

;; javascript
;; ============================================================

;; Add parsing of jshint output in compilation mode
(add-to-list 'compilation-error-regexp-alist-alist '(jshint "^\\(.*\\): line \\([0-9]+\\), col \\([0-9]+\\), " 1 2 3))
(add-to-list 'compilation-error-regexp-alist 'jshint)

;; always clean whitespace in javascript mode
(defun remap-save-clean-whitespace ()
  (interactive)
  (local-set-key [remap save-buffer] 'clean-whitespace-and-save))
(add-hook 'js-mode-hook 'remap-save-clean-whitespace)

;; set up tab key
(add-hook 'js-mode-hook 'set-tab)

;; indent by 2
(set 'js-indent-level 2)


;; Shell mode
;; ============================================================

(add-hook 'shell-mode-hook 'set-tab)
(add-hook 'shell-mode-hook (lambda ()
                             (set 'sh-basic-offset 2)
                             (set 'sh-indentation 2)))


;; Ace jump mode
;; ============================================================

(require 'ace-jump-mode)
(progn
  (set 'ace-jump-mode-case-fold t)

  ;; favour home row keys
  (let ((first-list  '(?a ?r ?s ?t ?n ?e ?i ?o ?d ?h)))
    (set 'ace-jump-mode-move-keys
	 (nconc first-list
		(-difference (loop for i from ?a to ?z collect i) first-list)
		(loop for i from ?A to ?Z collect i))))

  (set 'ace-jump-mode-scope 'window)
  (global-set-key (kbd "C-p") 'ace-jump-mode))


;; Ack support
(require 'ack)
(global-set-key (kbd "<f8>") 'projectile-ack)



;; Better help commands
;; ============================================================

;; Show source code for things
(define-key 'help-command (kbd "F") 'find-function)
(define-key 'help-command (kbd "K") 'find-function-on-key)
(define-key 'help-command (kbd "V") 'find-variable)


;; Clean up whitespace
;; ============================================================

;; has to go near the end because we need some project/language specific
;; functions.

(defun preserve-trailing-whitespace-p ()
  (interactive)
  (or
   ;; makefile mode doesn't play well with this
   (string= major-mode "makefile-mode")

   ;; oomph-lib doesn't stick to no trailing whitespace :(
   (is-oomph-code)

   ;; Don't do it in non-programming modes (just to be safe)
   (not (derived-mode-p 'prog-mode))))


(defun maybe-delete-trailing-whitespace ()
  (when (not (preserve-trailing-whitespace-p))
    (delete-trailing-whitespace)))

(add-hook 'before-save-hook 'maybe-delete-trailing-whitespace)


;; Automagically added by customise
;; ============================================================
(put 'downcase-region 'disabled nil)
(put 'upcase-region 'disabled nil)
(custom-set-variables
 ;; custom-set-variables was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 '(cc-other-file-alist
   (quote
    (("\\.cc\\'"
      (".hh" ".h"))
     ("\\.hh\\'"
      (".cc" ".C"))
     ("\\.c\\'"
      (".h"))
     ("\\.h\\'"
      (".cc" ".c" ".C" ".CC" ".cxx" ".cpp"))
     ("\\.C\\'"
      (".H" ".hh" ".h"))
     ("\\.H\\'"
      (".C" ".CC"))
     ("\\.CC\\'"
      (".HH" ".H" ".hh" ".h"))
     ("\\.HH\\'"
      (".CC"))
     ("\\.c\\+\\+\\'"
      (".h++" ".hh" ".h"))
     ("\\.h\\+\\+\\'"
      (".c++"))
     ("\\.cpp\\'"
      (".hpp" ".hh" ".h"))
     ("\\.hpp\\'"
      (".cpp"))
     ("\\.cxx\\'"
      (".hxx" ".hh" ".h"))
     ("\\.hxx\\'"
      (".cxx")))))
 '(column-number-mode t)
 '(ff-ignore-include t)
 '(gud-gdb-command-name "gdb -i=mi --args")
 '(htmlize-output-type (quote font))
 '(ido-ignore-buffers (quote ("optimised-oomph-lib" "\\` ")))
 '(indent-tabs-mode nil)
 '(markdown-bold-underscore nil)
 '(org-hide-block-startup t)
 '(org-startup-folded nil)
 '(safe-local-variable-values
   (quote
    ((TeX-master . "../poster")
     (TeX-master . "./main_poster")
     (TeX-master . "../main_poster")
     (TeX-master . t)
     (TeX-master . "main")
     (TeX-master . "./main"))))
 '(show-paren-mode t)
 '(tool-bar-mode nil)
 '(yas-wrap-around-region t))
(custom-set-faces
 ;; custom-set-faces was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 )
