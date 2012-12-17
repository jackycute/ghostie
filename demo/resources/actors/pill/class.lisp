(in-package :ghostie-demo)

(defactor pill (actor)
  ((feet :accessor pill-feet :initform nil)))

(defmethod load-actor-physics-body- ((pill pill) actor-meta)
  (let ((mass (if (getf actor-meta :mass)
                  (getf actor-meta :mass)
                  50d0))
        (num-circles (if (getf actor-meta :num-circles)
                         (getf actor-meta :num-circles)
                         3))
        (bb (calculate-game-object-bb pill)))
    (let ((body (cpw:make-body (lambda () (cp:body-new mass 1d0))))
          (position (if (getf actor-meta :start-pos)
                        (getf actor-meta :start-pos)
                        '(0 0 0))))
      (let* ((max-vel (getf actor-meta :max-vel 200d0))
             (height (- (cadddr bb) (cadr bb)))
             (radius (/ (/ height num-circles) 2d0))
             (moment 0d0))
        (dotimes (i num-circles)
          (let ((x 0d0)
                (y (- (* i (* 2 radius)) (- (/ height 2) radius))))
            (incf moment (cp:moment-for-circle mass radius 0d0 x y))
            (let ((shape (cpw:make-shape :circle body (lambda (body) (cp:circle-shape-new (cpw:base-c body) radius x y)))))
              (when (zerop i) (setf (pill-feet pill) shape))
              (setf (cp-a:shape-u (cpw:base-c shape)) 0.9d0))))
        (let ((body-c (cpw:base-c body)))
          (cp:body-set-moment body-c moment)
          (cp:body-set-pos body-c
                           (coerce (car position) 'double-float)
                           (coerce (cadr position) 'double-float))
          (setf (cp-a:body-v-limit body-c) max-vel))
        (enqueue (lambda (world)
                   (let ((space (world-physics world)))
                     ;; fix the character's rotation
                     (let ((joint (cpw:make-joint (cpw:space-static-body space) body
                                                  (lambda (body1 body2)
                                                    (cp:damped-rotary-spring-new (cpw:base-c body1) (cpw:base-c body2)
                                                                                 0d0 (* mass 240000d0) (* mass 25000d0))))))
                       (cpw:space-add-joint space joint))
                     ;; add the body/shapes to the world
                     (cpw:space-add-body space body)
                     (dolist (shape (cpw:body-shapes body))
                       (cpw:space-add-shape space shape))))
                 :game)
        body))))

(defun get-object-under-pill (pill)
  (unless (pill-feet pill)
    (let ((body (game-object-physics-body pill)))
      (setf (pill-feet pill) (car (reverse (cpw:body-shapes body))))))
  (when (and pill (game-object-physics-body pill))
    (let ((feet-shape-c (cpw:base-c (pill-feet pill)))
          (space-c (cpw:base-c (cpw:shape-space (pill-feet pill)))))
      (cffi:with-foreign-object (query 'clipmunk:segment-query-info)
        (let ((body-x (cp-a:body-p-x (cp-a:shape-body feet-shape-c)))
              (body-y (cp-a:body-p-y (cp-a:shape-body feet-shape-c)))
              (shape-offset-x (cp-a:circle-shape-c-x feet-shape-c))
              (shape-offset-y (cp-a:circle-shape-c-y feet-shape-c))
              (shape-radius (cp-a:circle-shape-r feet-shape-c)))
          (let* ((x1 (+ body-x shape-offset-x))
                 (y1 (+ body-y shape-offset-y 2d0 (- shape-radius)))
                 (x2 x1)
                 (y2 (- y1 10)))
            (cp:space-segment-query-first space-c x1 y1 x2 y2 99 (cffi:null-pointer) query)
            (let* ((shape (cp-a:segment-query-info-shape query))
                   (body (unless (cffi:null-pointer-p shape)
                           (cpw:find-body-from-pointer (cp-a:shape-body shape)))))
              (when (and body (not (eql body (game-object-physics-body pill))))
                (let ((n-x (cp-a:segment-query-info-n-x query))
                      (n-y (cp-a:segment-query-info-n-y query)))
                  ;(dbg :debug "cn: ~s~%" (list n-x n-y))
                  (values shape (list n-x n-y)))))))))))

(defun pill-grounded-p (pill)
  (multiple-value-bind (shape contact-normal) (get-object-under-pill pill)
    (when shape
      (when (< (car contact-normal) (+ (cadr contact-normal) 0.3))
        t))))

(defun pill-stop (pill)
  (when (and pill (game-object-physics-body pill))
    (let ((shape-c (cpw:base-c (caddr (cpw:body-shapes (game-object-physics-body pill))))))
      (setf (cp-a:shape-surface_v-x shape-c) 0d0
            (cp-a:shape-surface_v-y shape-c) 0d0))))

(defun pill-impulse (pill x &key (max-speed-div 1))
  "Move the character on the HORizonal plane."
  (when (and pill (game-object-physics-body pill))
    (let ((body-c (cpw:base-c (game-object-physics-body pill))))
      (let ((vel (cp-a:body-v-x body-c))
            (y (* x 0)))
        (let ((*character-max-run* (if (pill-grounded-p pill)
                                       *character-max-run*
                                       (* *character-max-run* .2))))
          (when (< (abs vel) (/ *character-max-run* max-speed-div))
            (cp:body-apply-impulse body-c
                                   (* x (cp-a:body-m body-c))
                                   (* y (cp-a:body-m body-c))
                                   0d0 0d0)))))))

(defun pill-run (pill x)
  "Move the character on the HORizonal plane."
  (when (and pill (game-object-physics-body pill))
    (let ((body-c (cpw:base-c (game-object-physics-body pill))))
      (let ((vel (cp-a:body-v-x body-c))
            (y (/ (abs x) 3)))
        (when (< (abs vel) *character-max-run*)
          ;(setf (cp-a:shape-u shape-c) (if (zerop x) 0.4d0 0.1d0))
          (if (pill-grounded-p pill)
              (let ((shape-c (cpw:base-c (pill-feet pill))))
                (cp:body-activate body-c)
                (setf (cp-a:shape-surface_v-x shape-c) (coerce x 'double-float)
                      (cp-a:shape-surface_v-y shape-c) (coerce y 'double-float)))
              (cp:body-apply-impulse body-c
                                     (* 0.02d0 x (cp-a:body-m body-c))
                                     0d0
                                     0d0 0d0)))))))

(defun pill-jump (pill &key (x 0d0) (y 300d0))
  "Make the character jump."
  (when (and pill (game-object-physics-body pill))
    (let* ((body-c (cpw:base-c (game-object-physics-body pill))))
      ;(dbg :debug "v-y: ~s ~s~%" (cp-a:body-v-y body-c) (actor-vel-avg-y pill))
      (when (and (pill-grounded-p pill)
                 (< (abs (cp-a:body-v-y body-c)) 160)
                 (< (abs (actor-vel-avg-y pill)) 160))
        (let* ((vel-x (cp-a:body-v-x body-c))
               (x (* x (- 1 (/ (abs vel-x) *character-max-run*)))))
          (cp:body-apply-impulse body-c
                                 (* (cp-a:body-m body-c) (coerce x 'double-float))
                                 (* (cp-a:body-m body-c) (coerce y 'double-float))
                                 0d0 0d0))))))
