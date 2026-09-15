(setq confirm-kill-emacs 'y-or-n-p)
(scroll-bar-mode -1)
(tooltip-mode nil)
(menu-bar-mode -1)
(setq mouse-yank-at-point nil)

(when (eq system-type 'darwin)
  (setq mac-control-modifier 'control)
  (setq mac-command-modifier 'super)
  (setq mac-option-modifier 'meta)
)

(add-to-list 'warning-suppress-log-types '(lsp-mode))
(add-to-list 'warning-suppress-types '(lsp-mode))

(add-hook 'go-mode-hook (lambda ()
                          (setq tab-width 4)))
