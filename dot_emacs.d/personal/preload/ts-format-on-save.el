(setq prelude-format-on-save nil)

(defun js-format-file ()
  (interactive)
  (message (concat "Formatting " (buffer-file-name) " with prettier"))
  (call-process-shell-command (concat "yarn prettier --write " (buffer-file-name))))

(defun js-lint-file ()
  (interactive)
  (message (concat "Linting " (buffer-file-name) " with eslint"))
  (call-process-shell-command (concat "yarn eslint --ext js,jsx,ts,tsx --fix " (buffer-file-name))))

(defun js-autoformat-buffer ()
  (interactive)
  (js-format-file)
  (js-lint-file)
  (revert-buffer t t))

(add-hook 'js2-mode-hook
          (lambda ()
            (add-hook 'after-save-hook #'js-autoformat-buffer)))

(add-hook 'typescript-mode-hook
          (lambda ()
            (add-hook 'after-save-hook #'js-autoformat-buffer)))
