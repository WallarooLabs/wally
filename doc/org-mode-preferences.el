;; org-mode setup
(setq load-path (cons "~/.emacs.dir/org-mode/lisp" load-path))
(setq load-path (cons "~/.emacs.dir/org-mode/contrib/lisp" load-path))
(require 'org-install)
(require 'org)
;;(require 'org-latex)
(require 'ox-latex)
(require 'ox-taskjuggler)
;; markdown
(require 'ox-md)
;; org-bullets
(setq load-path (cons "~/.emacs.dir/org-bullets" load-path))
(require 'org-bullets)
(add-hook 'org-mode-hook (lambda () (org-bullets-mode 1)))

;; org-mode customizations
;;(require 'org-exp-blocks) ;; needed for ditaa diagrams
;; The following lines are always needed.  Choose your own keys.
(add-to-list 'auto-mode-alist '("\\.org\\'" . org-mode))
(add-hook 'org-mode-hook 'turn-on-font-lock) ; not needed when global-font-lock-mode is on
(global-set-key "\C-cl" 'org-store-link)
(global-set-key "\C-ca" 'org-agenda)
(global-set-key "\C-cb" 'org-iswitchb)

;; Dropbox support for org-mode
;; Set to the location of your Org files on your local system
(setq org-directory "~/org")
;; Set to the name of the file where new notes will be stored
(setq org-mobile-inbox-for-pull "~/org/inbox.org")
;; Set to <your Dropbox root directory>/MobileOrg.
(setq org-mobile-directory "~/Dropbox/MobileOrg")
;; Setup capture mode
(setq org-default-notes-file (concat org-directory "/notes.org"))
     (define-key global-map "\C-cc" 'org-capture)

;; todo keywords
(setq org-todo-keywords
      '((type "TODO(t)" "STARTED(s)" "WAITING(w)" "APPT(a)" "|" "CANCELED(c)" "DEFERRED(e)" "DONE(d)")
	(sequence "PROJECT(p)" "|" "FINISHED(f)")
	(sequence "INVOICE(i)" "SENT(n)" "|" "RCVD(r)"))) 

;; XeTex setup or org-mode
;; 'elemica-com-report' for export org documents to the LaTex Koma-script 'report', using
;; XeTeX and some fancy fonts; requires XeTeX (see org-latex-to-pdf-process)
(add-to-list 'org-latex-classes
  '("sendence-com-article"
"\\documentclass[12pt,paper=a4,headings=normal]{scrreprt}
\\usepackage[english]{babel}
\\usepackage{fontspec}
\\usepackage{algorithmic}
\\usepackage{color}
\\usepackage[bookmarks=true]{hyperref}
\\hypersetup{linkcolor=blue,filecolor=red,urlcolor=cyan,colorlinks=true}
\\usepackage{epstopdf}
\\usepackage{graphicx} 
\\usepackage{longtable}
\\setromanfont{Gentium Basic}
\\setromanfont [BoldFont={Gentium Basic Bold},
                ItalicFont={Gentium Basic Italic}]{Gentium Basic}
\\setsansfont{Charis SIL}
\\setmonofont[Scale=0.7]{DejaVu Sans Mono}
\\usepackage{geometry}
\\geometry{a4paper, textwidth=6.5in, textheight=10in,
            marginparsep=7pt, marginparwidth=.6in}
\\pagestyle{plain}
\\setlength\\parindent{0pt}
\\title{}
      [NO-DEFAULT-PACKAGES]
      [NO-PACKAGES]"
     ("\\chapter{%s}" . "\\chapter*{%s}")
     ("\\section{%s}" . "\\section*{%s}")
     ("\\subsection{%s}" . "\\subsection*{%s}")
     ("\\subsubsection{%s}" . "\\subsubsection*{%s}")
     ("\\paragraph{%s}" . "\\paragraph*{%s}")
     ("\\subparagraph{%s}" . "\\subparagraph*{%s}")))

(add-to-list 'org-latex-classes
  '("sendence-com-article-2"
"\\documentclass{scrreprt}
\\usepackage[english]{babel}
\\usepackage{fontspec}
\\usepackage{algorithmic}
\\usepackage{color}
\\usepackage[bookmarks=true]{hyperref}
\\hypersetup{linkcolor=blue,filecolor=red,urlcolor=cyan,citecolor=red,colorlinks=true}
\\usepackage{epstopdf}
\\usepackage{graphicx} 
\\usepackage{longtable}
\\setromanfont{Gentium Basic}
\\setromanfont [BoldFont={Gentium Basic Bold},
                ItalicFont={Gentium Basic Italic}]{Gentium Basic}
\\setsansfont{Charis SIL}
\\setmonofont[Scale=0.7]{DejaVu Sans Mono}
\\usepackage{geometry}
\\geometry{a4paper, textwidth=130mm, textheight=240mm,
            marginparsep=5mm, marginparwidth=100mm}

\\usepackage[yyyymmdd,hhmmss]{datetime}
\\renewcommand{\\dateseparator}{-}

\\pagestyle{headings}

\\setlength\\parindent{10pt}

\\publishers{\\tiny\\ Compiled on \\today\\ at \\currenttime}

\\title{}
      [NO-DEFAULT-PACKAGES]
      [NO-PACKAGES]"
     ("\\chapter{%s}" . "\\chapter*{%s}")
     ("\\section{%s}" . "\\section*{%s}")
     ("\\subsection{%s}" . "\\subsection*{%s}")
     ("\\subsubsection{%s}" . "\\subsubsection*{%s}")
     ("\\paragraph{%s}" . "\\paragraph*{%s}")
     ("\\subparagraph{%s}" . "\\subparagraph*{%s}")))


(add-to-list 'org-latex-classes
  '("deeprecursion-com-report"
"\\documentclass{scrreprt}
\\usepackage[english]{babel}
\\usepackage{fontspec}
\\usepackage{algorithmic}
\\usepackage{color}
\\usepackage[bookmarks=true]{hyperref}
\\hypersetup{linkcolor=blue,filecolor=red,urlcolor=cyan,colorlinks=true}
\\usepackage{epstopdf}
\\usepackage{graphicx} 
\\usepackage{longtable}
\\setromanfont{Gentium Basic}
\\setromanfont [BoldFont={Gentium Basic Bold},
                ItalicFont={Gentium Basic Italic}]{Gentium Basic}
\\setsansfont{Charis SIL}
\\setmonofont[Scale=0.7]{DejaVu Sans Mono}
\\usepackage{geometry}
\\geometry{a4paper, textwidth=130mm, textheight=240mm,
            marginparsep=5mm, marginparwidth=100mm}

\\usepackage[yyyymmdd,hhmmss]{datetime}

\\pagestyle{headings}

\\setlength\\parindent{0pt}
\\publishers{\\tiny\\ Compiled on \\today\\ at \\currenttime}

\\title{}
      [NO-DEFAULT-PACKAGES]
      [NO-PACKAGES]"
     ("\\chapter{%s}" . "\\chapter*{%s}")
     ("\\section{%s}" . "\\section*{%s}")
     ("\\subsection{%s}" . "\\subsection*{%s}")
     ("\\subsubsection{%s}" . "\\subsubsection*{%s}")
     ("\\paragraph{%s}" . "\\paragraph*{%s}")
     ("\\subparagraph{%s}" . "\\subparagraph*{%s}")))

(add-to-list 'org-latex-classes
  '("deeprecursion-com-report-input"
"\\documentclass{scrreprt}
\\usepackage[english]{babel}
\\usepackage{fontspec}
\\usepackage{algorithmic}
\\usepackage{color}
\\usepackage[bookmarks=true]{hyperref}
\\hypersetup{linkcolor=blue,filecolor=red,urlcolor=cyan,colorlinks=true}
\\usepackage{epstopdf}
\\usepackage{graphicx} 
\\usepackage{longtable}
\\setromanfont{InputSerif-Regular}
\\setromanfont [BoldFont={InputSerif-Bold},
                ItalicFont={InputSerif-Italic}]{InputSerif}
\\setsansfont{InputSans-Regular}
\\setmonofont[Scale=0.7]{InputMono-Regular}
\\usepackage{geometry}
\\geometry{a4paper, textwidth=130mm, textheight=240mm,
            marginparsep=5mm, marginparwidth=100mm}

\\usepackage[yyyymmdd,hhmmss]{datetime}

\\pagestyle{headings}

\\setlength\\parindent{0pt}
\\publishers{\\tiny\\ Compiled on \\today\\ at \\currenttime}

\\title{}
      [NO-DEFAULT-PACKAGES]
      [NO-PACKAGES]"
     ("\\chapter{%s}" . "\\chapter*{%s}")
     ("\\section{%s}" . "\\section*{%s}")
     ("\\subsection{%s}" . "\\subsection*{%s}")
     ("\\subsubsection{%s}" . "\\subsubsection*{%s}")
     ("\\paragraph{%s}" . "\\paragraph*{%s}")
     ("\\subparagraph{%s}" . "\\subparagraph*{%s}")))


;; XeTeX setup
;; (setq org-latex-pdf-process
;;   '("xelatex -interaction nonstopmode %f"
;;      "xelatex -interaction nonstopmode %f")) ;; for multiple passes

;; org-mode babel setup
(setq org-ditaa-jar-path "~/bin/ditaa0_9.jar")
(setq org-plantuml-jar-path "~/bin/plantuml.jar")
(setq exec-path (append exec-path '("/usr/local/bin/mscgen")))
(setq exec-path (append exec-path '("/usr/local/bin/gnuplot")))
(setq exec-path (append exec-path '("/usr/local/bin/python")))
(add-hook 'org-babel-after-execute-hook 'org-display-inline-images 'append)
(org-babel-do-load-languages
 (quote org-babel-load-languages)
 (quote ((emacs-lisp . t)
         (dot . t)
         (ditaa . t)
         (mscgen . t)
         (R . t)
         (python . t)
         (ruby . t)
         (gnuplot . t)
         (clojure . t)
         (shell . t)
         (ledger . t)
         (org . t)
         (plantuml . t)
         (latex . t))))

; Do not prompt to confirm evaluation
; This may be dangerous - make sure you understand the consequences
; of setting this -- see the docstring for details
(setq org-confirm-babel-evaluate nil)

;; Switch on smart quotes in org-mode
;; (add-hook 'org-mode-hook 'my-org-init)
;;     (defun my-org-init ()
;;       (require 'typopunct)
;;       (typopunct-change-language 'english)
;;       (typopunct-mode 1))

;; org-ref setup (citation management) ---------------------------------------
;; first apply these patches:
;; touch /Applications/Aquamacs.app/Contents/Resources/etc/publicsuffix.txt
;; brew install Caskroom/cask/pdftotext


;; wrap lines
(global-visual-line-mode 1)

;; setup org-ref
(setq org-ref-bibliography-notes "~/Dropbox/bibliography/notes.org"
      org-ref-default-bibliography '("~/Dropbox/bibliography/references.bib")
      org-ref-pdf-directory "~/Dropbox/bibliography/bibtex-pdfs/")

(unless (file-exists-p org-ref-pdf-directory)
  (make-directory org-ref-pdf-directory t))

;; Some org-mode customization
(setq org-src-fontify-natively t
      org-confirm-babel-evaluate nil
      org-src-preserve-indentation t)

(org-babel-do-load-languages
 'org-babel-load-languages '((python . t)))

(setq org-latex-pdf-process
      '("xelatex -interaction nonstopmode -output-directory %o %f"
	"bibtex %b"
	"xelatex -interaction nonstopmode -output-directory %o %f"
	"xelatex -interaction nonstopmode -output-directory %o %f"))

(setq bibtex-autokey-year-length 4
      bibtex-autokey-name-year-separator "-"
      bibtex-autokey-year-title-separator "-"
      bibtex-autokey-titleword-separator "-"
      bibtex-autokey-titlewords 2
      bibtex-autokey-titlewords-stretch 1
      bibtex-autokey-titleword-length 5)

(require 'dash)
(setq org-latex-default-packages-alist
      (-remove-item
       '("" "hyperref" nil)
       org-latex-default-packages-alist))

