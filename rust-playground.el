;;; rust-playground.el --- Local Rust playground for short code snippets.

;; Copyright (C) 2016-2017  Alexander I.Grafov (axel)

;; Author: Alexander I.Grafov <grafov@gmail.com>
;; URL: https://github.com/grafov/rust-playground
;; Version: 0.1
;; Keywords: tools, rust
;; Package-Requires: ((emacs "24.3") (rust-mode "0.3.0"))

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

;; Local playground for the Rust programs similar to play.rust-lang.org.
;; `M-x rust-playground` and type you rust code then make&run it with `C-Return`.

;; Playground works in conjunction with `rust-mode` and requires
;; preconfigured environment for Rust language.

;; It is port of github.com/grafov/go-playground for Go language.

;; You may push code to play.rust-lang.org with rust-mode' function `rust-playpen-buffer`.

;;

;;; Code:

(require 'rust-mode)
(require 'compile)
(require 'time-stamp)

; I think it should be defined in rust-mode.
(defcustom rust-playground-bin "rustc"
  "The ’rust’ command."
  :type 'string
  :group 'rust-mode)

(defgroup rust-playground nil
  "Options specific to Rust Playground."
  :group 'rust-mode)

(defcustom rust-playground-ask-file-name nil
  "Non-nil means we ask for a name for the snippet.

By default it will be created as snippet.go"
  :type 'boolean
  :group 'rust-playground)

(defcustom rust-playground-confirm-deletion t
  "Non-nil means you will be asked for confirmation on the snippet deletion with `rust-playground-rm'.

By default confirmation required."
  :type 'boolean
  :group 'rust-playground)

(defcustom rust-playground-basedir (locate-user-emacs-file "rust-playground")
  "Base directory for playground snippets."
  :type 'file
  :group 'rust-playground)

(defvar-local rust-playground-current-snippet-file "snippet.rs"
  "The current snippet file.")

(define-minor-mode rust-playground-mode
  "A place for playing with Rust code and export it in short snippets."
  :init-value nil
  :lighter "Play(Rust)"
  :keymap '(([C-return] . rust-playground-exec)))

;;; Unused
;; (defun rp-snippet-name (&optional snippet-name)
;;   "Generate the name of the snippet, or use SNIPPET-NAME."
;;   (cond (snippet-name)
;;         (rust-playground-ask-file-name
;;          (read-string "Rust Playground filename: ")) ("snippet")))

(defun rp-dir-name (&optional snippet-name)
  "Get the name of the directory where the snippet will exist, with SNIPPET-NAME as part of the directory name."
  (file-name-as-directory (concat (file-name-as-directory rust-playground-basedir)
                                  (time-stamp-string "at-%:y-%02m-%02d-%02H%02M%02S"))))

(defun rp-snippet-main-file-name (basedir)
  "Get the snippet main.rs file from BASEDIR."
  ;; FIXME use proper directory functions
  (concat basedir (file-name-as-directory "src") "main.rs"))

(defun rp-toml-file-name (basedir)
  "Get the cargo.toml filename from BASEDIR."
  (concat basedir "Cargo.toml"))

(defun rust-playground-exec ()
  "Save the buffer then run Rust compiler for executing the code."
  (interactive)
  (make-local-variable 'compile-command)
  (let ((snippet-file buffer-file-name))
    (save-buffer t)
    (compile "cargo run")))

;;;###autoload
(defun rust-playground ()
  "Run playground for Rust language in a new buffer."
  (interactive)
  ;; get the dir name
  (let* ((snippet-dir (rp-dir-name))
         (snippet-file-name (rp-snippet-main-file-name snippet-dir))
         (snippet-cargo-toml (rp-toml-file-name snippet-dir)))
    ;; (message "%s\n%s" snippet-file-name snippet-cargo-toml)
    ;; create a buffer for Cargo.toml and switch to it
    (make-directory snippet-dir)
    (set-buffer (create-file-buffer snippet-cargo-toml))
    (insert "[package]
name = \"foo\"
version = \"0.1.0\"
authors = [\"Rust Example <rust-snippet@example.com>\"]

[dependencies]
")
    (set-visited-file-name snippet-cargo-toml t)
    (save-buffer)
    (make-directory (concat snippet-dir "src"))
    ;; Cargo.toml doesnt need to stay open, kill the buffer
    ;; FIXME this buffer needs to have a unique name so I can kill it without causing trouble
    ;; (kill-buffer snippet-cargo-toml)
    (switch-to-buffer (create-file-buffer snippet-file-name))
    ;; (add-hook 'kill-buffer-hook 'rust-playground-on-buffer-kill nil t)
    (rust-playground-insert-template-head "snippet of code")
    (insert "fn main() {
    
    println!(\"Results:\")
}")
    (backward-char 3)
    (rust-mode)
    (rust-playground-mode)
    (set-visited-file-name snippet-file-name t)))

;; (defun rust-playground-switch-between-cargo-and-main ()
;;   "Change buffers between the main.rs and Cargo.toml files for the current snippet."
;;   (let ((basedir (rust-playground-get-snippet-basedir)))
    

;;;###autoload
(defun rust-playground-rm ()
  "Remove files of the current snippet together with directory of this snippet."
  (interactive)
  (let ((playground-basedir (rust-playground-get-snippet-basedir)))
    (message "%s" playground-basedir)
    (if playground-basedir
        (if (or (not rust-playground-confirm-deletion)
                (y-or-n-p (format "Do you want delete whole snippet dir %s? "
                                  playground-basedir)))
            (progn
              (save-buffer)
              (delete-directory playground-basedir t t)
              ;; (remove-hook 'kill-buffer-hook 'rust-playground-on-buffer-kill t)
              ;; FIXME need to kill the cargo.toml buffer too
              (kill-buffer)))
      (message "Won't delete this! Because %s is not under the path %s. Remove the snippet manually!"
               (buffer-file-name) rust-playground-basedir))))

;; ;;;###autoload
;; (defun rust-playground-download (url)
;;   "Download a paste from the play.golang.org and insert it in a new local playground buffer.
;; Tries to look for a URL at point."
;;   (interactive (list (read-from-minibuffer "Playground URL: " (ffap-url-p (ffap-string-at-point 'url)))))
;;   (with-current-buffer
;;       (let ((url-request-method "GET") url-request-data url-request-extra-headers)
;;         (url-retrieve-synchronously (concat url ".go")))
;;     (let* ((snippet-file-name (rust-playground-snippet-file-name)) (buffer (create-file-buffer snippet-file-name)))
;;       (goto-char (point-min))
;;       (re-search-forward "\n\n")
;;       (copy-to-buffer buffer (point) (point-max))
;;       (kill-buffer)
;;       (with-current-buffer buffer
;;              (goto-char (point-min))
;;              (rust-playground-insert-template-head (concat url " imported"))
;;              (rust-mode)
;;              (rust-playground-mode)
;;              (set-visited-file-name snippet-file-name t)
;;         (switch-to-buffer buffer)))))

;; (defun rust-playground-upload ()
;;   "Upload the current buffer to play.rust-lang.org and return the short URL of the playground."
;;   (interactive)
;;   (goto-char (point-min))
;;   (forward-line)
;;   (insert (rust-playpen-buffer)))

(defun rust-playground-get-snippet-basedir (&optional path)
  "Get the path of the dir containing this snippet, starting from PATH or the
path of the current buffer's file, or NIL of this is not a snippet."
  (if (not path)
      (setq path (buffer-file-name)))
  (if (not (string= path "/"))
      (let ((base "/home/jason/.emacs.d/rust-playground")
            (path-parent (file-name-directory (directory-file-name path))))
        ;; if
        (if (string= (file-name-as-directory base)
                     (file-name-as-directory path-parent))
            path
          (rust-playground-get-snippet-basedir path-parent)))
    nil))

(provide 'rust-playground)
;;; rust-playground.el ends here
