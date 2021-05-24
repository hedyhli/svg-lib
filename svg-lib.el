;;; svg-lib.el --- SVG tags, bars & icons -*- lexical-binding: t -*-

;; Copyright (C) 2021 Nicolas P. Rougier

;; Author: Nicolas P. Rougier <Nicolas.Rougier@inria.fr>
;; Homepage: https://github.com/rougier/svg-lib
;; Keywords: convenience
;; Version: 0.1

;; Package-Requires: ((emacs "27.1"))

;; This file is not part of GNU Emacs.

;; This file is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 3, or (at your option)
;; any later version.

;; This file is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; For a full copy of the GNU General Public License
;; see <https://www.gnu.org/licenses/>.

;;; Commentary:
;;
;; Usage example:
;;
;; (insert-image (svg-lib-tag "TODO"))
;; (insert-image (svg-lib-progress-bar 0.33))
;; (insert-image (svg-lib-icon "material" "star"))
;;
;; Icons ares created by parsing remote collections whose license are
;; compatibles with GNU Emacs:
;;
;; - Boxicons (https://github.com/atisawd/boxicons), available under a
;;   Creative Commons 4.0 license.  As of version 2.07 (December 2020),
;;   this collection offers 1500 icons in two styles (regular & solid).
;;   Gallery is available at https://boxicons.com/
;;
;; - Octicons (https://github.com/primer/octicons), available under a
;;   MIT License with some usage restriction for the GitHub logo.  As of
;;   version 11.2.0 (December 2020), this collection offers 201 icons.
;;   Gallery available at https://primer.style/octicons/
;;
;; - Material (https://github.com/google/material-design-icons),
;;   available under an Apache 2.0 license.  As of version 4.0.0
;;   (December 2020), this collection offers 500+ icons in 4 styles
;;   (filled, outlined, rounded, sharp).  Gallery available at
;;   https://material.io/resources/icons/?style=baseline
;;
;; - Bootstrap (https://github.com/twbs/icons), available under an MIT
;;   license.  As of version 1.2.1 (December 2020), this collection
;;   offers 1200+ icons in 2 styles (regular & filled).  Gallery
;;   available at https://icons.getbootstrap.com/
;;
;; The default size of an icon is exactly 2x1 characters such that it
;; can be inserted inside a text without disturbing alignment.
;;
;; Note: Each icon is cached locally to speed-up loading the next time
;;       you use it.  If for some reason the cache is corrupted you can
;;       force reload using the svg-icon-get-data function.
;;
;; If you want to add new collections (i.e. URL), make sure the icons
;; are monochrome, their size is consistent.

;;; Code:
(require 'svg)

(defgroup svg-lib nil
  "SVG tags, bars & icons."
  :group 'convenience
  :prefix "svg-lib-")

;; Default icon collections
;; ---------------------------------------------------------------------
(defcustom  svg-lib-icon-collections
  '(("bootstrap" .
     "https://icons.getbootstrap.com/icons/%s.svg")
    ("material" .
     "https://raw.githubusercontent.com/Templarian/MaterialDesign/master/svg/%s.svg")
    ("octicons" .
     "https://raw.githubusercontent.com/primer/octicons/master/icons/%s-24.svg")
    ("boxicons" .
     "https://boxicons.com/static/img/svg/regular/bx-%s.svg"))
    
  "Various icons collections stored as (name . base-url).

The name of the collection is used as a pointer for the various
icon creation methods.  The base-url is a string containing a %s
such that is can be replaced with the name of a specific icon.
User is responsible for finding/giving proper names for a given
collection (there are way too many to store them)."

  :type '(alist :key-type (string :tag "Name")
                :value-type (string :tag "URL"))
  :group 'svg-lib)


;; Default style for all objects
;; ---------------------------------------------------------------------
(defcustom svg-lib-style-default
  '(:foreground "black" :background "white" :stroke "black"
    :thickness 2 :radius 3 :padding 1 :margin 1 :width 20 :scale 1.0
    :family "Roboto Mono" :height 12 :weight regular)
  "Default style"
  :group 'svg-lib)

;; Convert Emacs color to SVG color
;; ---------------------------------------------------------------------
(defun svg-lib-convert-color (color-name)
  "Convert Emacs COLOR-NAME to #rrggbb form.
If COLOR-NAME is unknown to Emacs, then return COLOR-NAME as-is."
  
  (let ((rgb-color (color-name-to-rgb color-name)))
    (if rgb-color
        (apply #'color-rgb-to-hex (append rgb-color '(2)))
      color-name)))


;; SVG Library style build from partial specification
;; ---------------------------------------------------------------------
(defun svg-lib-style (&optional base &rest args)
  "Build a news style using BASE and style elements ARGS."
  
  (let* ((default svg-lib-style-default)
         (base (or base default))
         (keys (cl-loop for (key value) on default by 'cddr
                        collect key))
         (style '()))

    (dolist (key keys)
      (setq style (if (plist-member args key)
                      (plist-put style key (plist-get args key))
                    (plist-put style key (plist-get base key)))))

    ;; Convert emacs colors to SVG colors
    (plist-put style :foreground
               (svg-lib-convert-color (plist-get style :foreground)))
    (plist-put style :background
               (svg-lib-convert-color (plist-get style :background)))
    (plist-put style :stroke
               (svg-lib-convert-color (plist-get style :stroke)))

    ;; Convert emacs font weights to SVG font weights
    (let ((weights
           '((thin       . 100) (ultralight . 200) (light      . 300)
             (regular    . 400) (medium     . 500) (semibold   . 600)
             (bold       . 700) (extrabold  . 800) (black      . 900))))
      (plist-put style :weight
                 (or (cdr (assoc (plist-get style :weight) weights))
                     (plist-get style :weight))))
    style))


;; Create an image displaying LABEL in a rounded box.
;; ---------------------------------------------------------------------
(defun svg-lib-tag (label &optional style &rest args)
  "Create an image displaying LABEL in a rounded box using given STYLE
and style elements ARGS."

  (let* ((default svg-lib-style-default)
         (style (if style (apply #'svg-lib-style nil style) default))
         (style (if args  (apply #'svg-lib-style style args) style))

         (foreground (plist-get style :foreground))
         (background (plist-get style :background))
         (stroke     (plist-get style :stroke))
         (size       (plist-get style :height))
         (family     (plist-get style :family))
         (weight     (plist-get style :weight))
         (radius     (plist-get style :radius))
         (margin     (plist-get style :margin))
         (padding    (plist-get style :padding))
         (thickness  (plist-get style :thickness))

         (txt-char-width  (window-font-width))
         (txt-char-height (window-font-height))
         (ascent          (aref (font-info (format "%s:%d" family size)) 8))
         (tag-char-width  (aref (font-info (format "%s:%d" family size)) 11))
         (tag-char-height (aref (font-info (format "%s:%d" family size)) 3))
         (tag-width       (* (+ (length label) padding) txt-char-width))
         (tag-height      (* txt-char-height 0.9))

         (svg-width       (+ tag-width (* margin txt-char-width)))
         (svg-height      tag-height)

         (tag-x (/ (- svg-width tag-width) 2))
         (text-x (+ tag-x (/ (- tag-width (* (length label) tag-char-width)) 2)))
         (text-y ascent)
         
         (svg (svg-create svg-width svg-height)))

    (if (>= thickness 0.25)
        (svg-rectangle svg tag-x 0 tag-width tag-height
                           :fill stroke :rx radius))
    (svg-rectangle svg (+ tag-x (/ thickness 2.0)) (/ thickness 2.0)
                       (- tag-width thickness) (- tag-height thickness)
                       :fill background :rx (- radius (/ thickness 2.0)))
    (svg-text svg label
              :font-family family :font-weight weight  :font-size size
              :fill foreground :x text-x :y  text-y)
    (svg-image svg :scale 1 :ascent 'center)))


;; Create a progress bar
;; ---------------------------------------------------------------------
(defun svg-lib-progress (value &optional style &rest args)
  "Create a progress bar image with value VALUE using given STYLE
and style elements ARGS."

  (let* ((default svg-lib-style-default)
         (style (if style (apply #'svg-lib-style nil style) default))
         (style (if args  (apply #'svg-lib-style style args) style))

         (width      (plist-get style :width))
         (foreground (plist-get style :foreground))
         (background (plist-get style :background))
         (stroke     (plist-get style :stroke))
         (size       (plist-get style :height))
         (family     (plist-get style :family))
         (weight     (plist-get style :weight))
         (radius     (plist-get style :radius))
         (margin     (plist-get style :margin))
         (padding    (plist-get style :padding))
         (thickness  (plist-get style :thickness))

         (txt-char-width  (window-font-width))
         (txt-char-height (window-font-height))
        
         (ascent          (aref (font-info (format "%s:%d" family size)) 8))
         (tag-char-width  (aref (font-info (format "%s:%d" family size)) 11))
         (tag-char-height (aref (font-info (format "%s:%d" family size)) 3))
         (tag-width       (* width txt-char-width))
         (tag-height      (* txt-char-height 0.9))

         (svg-width       (+ tag-width (* margin txt-char-width)))
         (svg-height      tag-height)

         (tag-x (/ (- svg-width tag-width) 2))
         (svg (svg-create svg-width svg-height)))

    (if (>= thickness 0.25)
        (svg-rectangle svg tag-x 0 tag-width tag-height
                       :fill stroke :rx radius))
    (svg-rectangle svg (+ tag-x (/ thickness 2.0))
                       (/ thickness 2.0)
                       (- tag-width thickness)
                       (- tag-height thickness)
                       :fill background :rx (- radius (/ thickness 2.0)))
    (svg-rectangle svg (+ tag-x (/ thickness 2.0) padding)
                       (+ (/ thickness 2.0) padding)
                       (- (* value tag-width) thickness (* 2 padding))
                       (- tag-height thickness (* 2 padding))
                       :fill foreground :rx (- radius (/ thickness 2.0)))
    
    (svg-image svg :scale 1 :ascent 'center)))



;; Create a rounded box icon
;; ---------------------------------------------------------------------
(defun svg-lib--icon-get-data (collection name &optional force-reload)
  "Retrieve icon NAME from COLLECTION.

Cached version is returned if it exists unless FORCE-RELOAD is t."
  
  ;; Build url from collection and name without checking for error
  (let ((url (format (cdr (assoc collection svg-lib-icon-collections)) name)))

    ;; Get data only if not cached or if explicitely requested
    (if (or force-reload (not (url-is-cached url)))
        (let ((url-automatic-caching t)
              (filename (url-cache-create-filename url)))
          (with-current-buffer (url-retrieve-synchronously url)
            (write-region (point-min) (point-max) filename))))

    ;; Get data from cache
    (let ((buffer (generate-new-buffer " *temp*")))
      (with-current-buffer buffer
        (url-cache-extract (url-cache-create-filename url)))
      (with-temp-buffer
        (url-insert-buffer-contents buffer url)
        (xml-parse-region (point-min) (point-max))))))


(defun svg-lib-icon (collection name &optional style &rest args)
  "Create a SVG image displaying icon NAME from COLLECTION using
given STYLE and style elements ARGS."
  
  (let* ((root (svg-lib--icon-get-data collection name))

         (default svg-lib-style-default)
         (style (if style (apply #'svg-lib-style nil style) default))
         (style (if args  (apply #'svg-lib-style style args) style))

         (foreground (plist-get style :foreground))
         (background (plist-get style :background))
         (stroke     (plist-get style :stroke))
         (size       (plist-get style :height))
         (family     (plist-get style :family))
         (weight     (plist-get style :weight))
         (radius     (plist-get style :radius))
         (margin     (plist-get style :margin))
         (padding    (plist-get style :padding))
         (thickness  (plist-get style :thickness))
         (scale      (plist-get style :scale))
         (width      (+ 2 padding))
         
         (txt-char-width  (window-font-width))
         (txt-char-height (window-font-height))
         (box-width       (* width txt-char-width))
         (box-height      (*  0.90 txt-char-height))
         (svg-width       (+ box-width (* margin txt-char-width)))
         (svg-height      box-height)
         (box-x           (/ (- svg-width box-width) 2))
         (box-y           0)

         ;; Read original viewbox
         (viewbox (cdr (assq 'viewBox (xml-node-attributes (car root)))))
         (viewbox (mapcar 'string-to-number (split-string viewbox)))
         (icon-x      (nth 0 viewbox))
         (icon-y      (nth 1 viewbox))
         (icon-width  (nth 2 viewbox))
         (icon-height (nth 3 viewbox))
         (scale       (* scale (/ (float box-height) (float icon-height))))
         (icon-transform
          (format "translate(%f,%f) scale(%f) translate(%f,%f)"
                  (- icon-x )
                  (- icon-y )
                  scale
                  (- (/ svg-width 2 scale) (/ icon-width 2))
                  (- (/ svg-height 2 scale) (/ icon-height 2))))

         (svg (svg-create svg-width svg-height)))

    (if (>= thickness 0.25)
        (svg-rectangle svg box-x box-y box-width box-height
                       :fill stroke :rx radius))
    (svg-rectangle svg (+ box-x (/ thickness 2.0))
                       (+ box-y (/ thickness 2.0))
                       (- box-width thickness)
                       (- box-height thickness)
                       :fill background :rx (- radius (/ thickness 2.0)))
    
    (dolist (item (xml-get-children (car root) 'path))
      (let* ((attrs (xml-node-attributes item))
             (path (cdr (assoc 'd attrs)))
             (fill (or (cdr (assoc 'fill attrs)) foreground)))
        (svg-node svg 'path :d path
                            :fill foreground
                            :transform icon-transform)))
    (svg-image svg :ascent 'center :scale 1)))


(provide 'svg-lib)
;;; svg-lib.el ends here
