(require 'tumblesocks-user)
(require 'tumblesocks-api)
(require 'htmlize)
(require 'markdown-mode)
(provide 'tumblesocks-compose)

;; Tumblr compose mode ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defvar tumblesocks-compose-finish-action
  '(lambda () (call-interactively 'tumblesocks-text-post-from-buffer))
  "The action to run when finishing posting")
(defvar tumblesocks-compose-continuation
  nil "Optional action to run when finishing editing or posting")
(defvar tumblesocks-compose-editing-id nil
  "If editing, the ID of the post that we are editing")
(defvar tumblesocks-compose-editing-args nil
  "If editing, which args to use while we're editing")

(defun tumblesocks-compose-finish ()
  (interactive)
  (funcall tumblesocks-compose-finish-action)
  (let ((cc tumblesocks-compose-continuation))
    (quit-window)
    (when cc
      (funcall cc))))

(defvar tumblesocks-compose-mode-map
  (let ((tumblesocks-compose-mode-map (make-keymap)))
    ;; Element insertion
    (define-key tumblesocks-compose-mode-map "\C-c\C-c" 'tumblesocks-compose-finish)
    tumblesocks-compose-mode-map))

(define-derived-mode tumblesocks-compose-mode markdown-mode "Tumblr/C"
  "Major mode for composing a new Tumblr post."
  (make-local-variable 'tumblesocks-compose-finish-action)
  (setq tumblesocks-compose-finish-action
          '(lambda () (call-interactively 'tumblesocks-text-post-from-buffer)))
  (make-local-variable 'tumblesocks-compose-editing-args)
  (make-local-variable 'tumblesocks-compose-editing-id)
  (make-local-variable 'tumblesocks-compose-continuation))



(defun tumblesocks-compose-new-post (&optional continuation)
  "Open a new buffer containing a fresh post to begin authoring."
  (interactive)
  (pop-to-buffer "*Tumblr: New post*")
  (erase-buffer)
  (tumblesocks-compose-mode)
  (setq header-line-format "New tumblr post")
  (setq tumblesocks-compose-continuation continuation))

(defun tumblesocks-compose-new-from-region (begin end &optional continuation)
  "Open a new buffer containing a fresh post, but initially
populate it with the contents of the region."
  (interactive "r")
  (let ((initial-body (buffer-substring begin end)))
    (tumblesocks-compose-new-post)
    (insert "\n \n")
    (insert initial-body)
    (goto-char (point-min)))
  (setq tumblesocks-compose-continuation continuation))

(defun tumblesocks-compose-new-from-highlighted-region (begin end &optional continuation)
  "Open a new buffer containing a fresh post, but initially
populate it with the contents of the region. The region is
syntax-highlighted using Emacs' htmlize library."
  (interactive "r")
  (deactivate-mark)
  (let ((initial-body (htmlize-region-for-paste begin end)))
    (tumblesocks-compose-new-post)
    (insert "\n \n")
    (insert initial-body)
    (goto-char (point-min)))
  (setq tumblesocks-compose-continuation continuation))

(defun tumblesocks-compose-insert-highlighted-region (beg end)
  "Add new syntax-highlighted text from the region into the tumblr
post buffer"
  (interactive "r")
  (deactivate-mark)
  (let ((htmlstring (htmlize-region-for-paste beg end)))
    (pop-to-buffer "*Tumblr: New post")
    (goto-char (point-max))
    (insert "\n\n")
    (insert htmlstring)))



(defun tumblesocks-compose-edit-post (post-id &optional continuation)
  "Open a new buffer containing a fresh post to begin authoring."
  (interactive "sPost ID: ")
  (let* ((returned-posts
          (cdr-safe (assq 'posts
                     (tumblesocks-api-blog-posts nil post-id nil "1"
                                            nil nil nil "raw"))))
         (the-post (elt returned-posts 0))
         (type (cdr-safe (assq 'type the-post)))
         (title (cdr-safe (assq 'title the-post)))
         (id (format "%d" (cdr-safe (assq 'id the-post))))
         (body (cdr-safe (assq 'body the-post))))
    (unless (string= type "text")
      (error "We can only edit text posts."))
    (pop-to-buffer (concat "*Tumblr: Ediitng " title "*"))
    (erase-buffer)
    (tumblesocks-compose-mode)
    (setq header-line-format (concat "Editing: " title))
    (setq tumblesocks-compose-editing-args the-post)
    (setq tumblesocks-compose-editing-id id)
    (aput 'tumblesocks-compose-editing-args
          'tags
          (mapconcat 'identity (cdr (assq 'tags tumblesocks-compose-editing-args)) ","))
    (delq (assq 'format tumblesocks-compose-editing-args)
          tumblesocks-compose-editing-args)
    (delq (assq 'id tumblesocks-compose-editing-args)
          tumblesocks-compose-editing-args)
    (setq tumblesocks-compose-finish-action 'tumblesocks-compose-edit-finish)
    (insert body)
    (goto-char (point-min))
    (setq tumblesocks-compose-continuation continuation)))

(defun tumblesocks-compose-edit-finish ()
  "Finish editing the given post"
  ;; Optionally prompt for title
  (let ((new-title (read-string "New title: " (cdr (assq 'title tumblesocks-compose-editing-args))))
        (new-tags (read-string "New tags: " (cdr (assq 'tags tumblesocks-compose-editing-args)))))
    ;; Set tags
    (when (and new-tags (string= new-tags "")) (setq new-tags nil))
    (when (string= new-title "") (error "You must provide a title."))
    (aput 'tumblesocks-compose-editing-args 'title new-title)
    (if (string= "" new-tags)
        (delq (assq 'tags tumblesocks-compose-editing-args) tumblesocks-compose-editing-args)
      (aput 'tumblesocks-compose-editing-args 'tags new-tags))
    (aput 'tumblesocks-compose-editing-args
          'body
          (buffer-string))
    (tumblesocks-api-edit-post tumblesocks-compose-editing-id tumblesocks-compose-editing-args)
    (message "Post edited.")))
