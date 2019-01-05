;; See https://github.com/bbatsov/prelude/issues/674#issuecomment-255596298

(add-to-list 'package-archives
             '("melpa" . "https://melpa.org/packages/") t)
(add-to-list 'package-archives
             '("melpa-stable" . "https://stable.melpa.org/packages/") t)
(setq package-archive-priorities
      '(("melpa-stable" .  10)
        ("melpa" . 9)
        ))
