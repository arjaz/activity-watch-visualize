;;; activity-watch-visualize --- Export and see ActivityWatch data -*- lexical-binding: t; -*-

;; Author: Eugene Rossokha <arjaz@protonmail.com>
;; Maintainer: Eugene Rossokha <arjaz@protonmail.com>
;; Website: https://activitywatch.net
;; Homepage: https://github.com/arjaz/activity-watch-visualize
;; Package-Requires ((emacs "27") (request "0") (json "0") (cl-lib "0") (activity-watch-mode "1.0.2") (org "9"))
;; Version: 0.0.1

;;; Commentary:
;; M-x activity-watch-visualize-as-org

(require 'request)
(require 'cl-lib)
(require 'json)
(require 'org)
(require 'activity-watch-mode)

;;; Code:

(defvar awv--last-data)

(defun awv--format-time (timestamp)
  "Format the given TIMESTAMP."
  (format-time-string "%Y/%m/%d %H:%M" (date-to-time timestamp)))

(defun awv--handle-unknown (v)
  "Change V to a - if it's unknown."
  (if (string= v "unknown")
      "-"
    v))

(defun awv--pulse-to-org-string (pulse)
  "Convert the given PULSE to a string."
  (let* ((data (alist-get 'data pulse))
         (timestamp (alist-get 'timestamp pulse))
         (project (alist-get 'project data))
         (branch (alist-get 'branch data))
         (file (alist-get 'file data)))
    (format "| %s | %s | %s | %s |"
            (awv--format-time timestamp)
            (awv--handle-unknown project)
            (awv--handle-unknown branch)
            (abbreviate-file-name (awv--handle-unknown file)))))

(defun awv--request-data ()
  "Request the ActivityWatch data and store it."
  (request (concat "http://localhost:5600/api/0/buckets/" (activity-watch--bucket-id) "/events")
    :parser #'json-read
    :sync t
    :success (cl-function
              (lambda (&key data &allow-other-keys)
                (setq awv--last-data data)))))

(defun awv--write-org-header ()
  "Write the list header."
  (princ "| time | project | branch | file |\n")
  (princ "|------+---------+--------+------|\n"))

(defun awv--write-org-footer ()
  "Write the list footer."
  (princ "|------+---------+--------+------|\n"))

(defun awv--today-p (pulse)
  "Check if the PULSE was made today."
  (let* ((p-time  (parse-time-string (alist-get 'timestamp pulse)))
         (p-day   (nth 3 p-time))
         (p-month (nth 4 p-time))
         (p-year  (nth 5 p-time))
         (time    (decode-time))
         (day     (nth 3 time))
         (month   (nth 4 time))
         (year    (nth 5 time)))
    (and (= p-day day) (= p-month month) (= p-year year))))

(defun awv--filtered-data (data filters)
  "Apply all FILTERS to the elements of the DATA sequence."
  (seq-reduce (lambda (data filter) (seq-filter filter data)) filters data))

(defun awv--write-org-data (filters)
  "Write the data filtered with FILTERS as an org file."
  (cl-loop for pulse in (awv--filtered-data awv--last-data filters)
           do (princ (concat (awv--pulse-to-org-string pulse) "\n"))))

;; TODO: fancy filters and customization
;;       maybe have transient?
;;       check https://github.com/alphapapa/taxy.el/
(defun activity-watch-visualize-as-org (&optional filters)
  "Present the ActivityWatch data in a new org buffer applying the FILTERS."
  (interactive)
  (let ((filters (or filters (list #'awv--today-p))))
    (awv--request-data)
    (with-output-to-temp-buffer "*activity-watch*"
      (awv--write-org-header)
      (awv--write-org-data filters)
      (awv--write-org-footer)
      (pop-to-buffer "*activity-watch*")
      (org-mode)
      (org-table-align)
      (read-only-mode))))

(provide 'activity-watch-visualize)
;;; activity-watch-visualize.el ends here
