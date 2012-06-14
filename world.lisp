(in-package :game-level)

(defparameter *world-position* '(-17.19999 -24.00002 -36.000065))
(defparameter *perspective-matrix* nil)
(defparameter *ortho-matrix* nil)
(defparameter *view-matrix* nil)
(defvar *game-data* nil)

(defun create-world ()
  (setf *world-position* '(-17.19999 -24.00002 -36.000065)))

(defun step-world (world)
  (declare (ignore world)))

(defun load-assets ()
  (format t "Starting asset load.~%")
  (free-assets)
  (let ((assets '((:ground #P"resources/ground.ai" 0)
                  (:ground-background #P"resources/ground-background.ai" -9)
                  (:tree1 #P"resources/tree1.ai" -20.0)
                  (:tree2 #P"resources/tree2.ai" -14.0)
                  (:tree3 #P"resources/tree3.ai" -16.0)
                  (:tree4 #P"resources/tree4.ai" -32.0))))
    (loop for (key file z-offset) in assets do
          (format t "Loading ~a...~%" file)
          (setf (getf *game-data* key)
                (multiple-value-bind (vertices offset) (load-points-from-ai file :precision 2 :center t :scale '(.1 .1 .1))
                  (make-gl-object :data (cl-triangulation:triangulate (coerce vertices 'vector)) :scale '(1 1 1) :position (append (mapcar #'- offset) (list z-offset)))))))
  (setf (getf *game-data* :quad) (make-gl-object :data '(((-1 -1 0) (1 -1 0) (-1 1 0))
                                                         ((1 -1 0) (1 1 0) (-1 1 0)))
                                                 :uv-map #(0 0 1 0 0 1 1 1)))
  (setf (getf *game-data* :spike) (make-gl-object :data (load-triangles-from-ply #P"resources/spike.ply") :scale '(1 1 1) :position '(0 0 -10)))
  (create-test-primitives)
  (format t "Finished asset load.~%"))

(defun free-assets ()
  (loop for (nil obj) on *game-data* by #'cddr do
    (when (subtypep (type-of obj) 'gl-object)
      (free-gl-object obj))))

(defun draw-world (world)
  (declare (ignore world))
  (gl:bind-framebuffer-ext :framebuffer (getf *render-objs* :fbo1))
  (gl:clear :color-buffer-bit :depth-buffer-bit)
  (gl:use-program (getf *shaders* :main))
  (setf *view-matrix* (apply #'m-translate *world-position*))
  (set-shader-matrix "cameraToClipMatrix" *perspective-matrix*)
  (draw (getf *game-data* :spike))
  (draw (getf *game-data* :ground))
  (draw (getf *game-data* :ground-background))
  (draw (getf *game-data* :tree1))
  (draw (getf *game-data* :tree2))
  (draw (getf *game-data* :tree3))
  (draw (getf *game-data* :tree4))
  (gl:bind-framebuffer-ext :framebuffer 0)
  (gl:clear :color-buffer-bit :depth-buffer-bit)
  (gl:use-program (getf *shaders* :fov))
  (set-shader-matrix "cameraToClipMatrix" *ortho-matrix*)
  (gl:uniformi (get-shader-unif "tex") 0)
  (gl:active-texture :texture0)
  (gl:bind-texture :texture-2d (getf *render-objs* :fbo1-tex))
  (draw (getf *game-data* :quad))
  (gl:use-program 0))

(defun test-gl-funcs ()
  (format t "Running test func..~%")
  (format t "OpenGL version: ~a~%" (gl:get-string :version))
  (format t "Shader version: ~a~%" (gl:get-string :shading-language-version))
  ;(format t "Extensions: ~a~%" (gl:get-string :extensions))
  (format t "depth bits: ~a~%" (gl:get-integer :depth-bits)))

(defun create-test-primitives ()
  (setf (getf *game-data* :triangle) (make-gl-object :data '(((-1.0 -1.0  0.0) ( 1.0 -1.0  0.0) ( 0.0  1.0  0.0))) :position '(0 0 -1)))
  (setf (getf *game-data* :prism1) (make-gl-object :data '(((-1.0 -1.0  0.0) ( 1.0 -1.0  0.0) ( 0.0  1.0  0.0))
                                                           ((-1.0 -1.0  0.0) ( 0.0  0.0 -1.0) ( 1.0 -1.0  0.0))
                                                           ((-1.0 -1.0  0.0) ( 0.0  1.0  0.0) ( 0.0  0.0 -1.0))
                                                           (( 0.0  1.0  0.0) ( 1.0 -1.0  0.0) ( 0.0  0.0 -1.0))) :position '(3 6 -20)))
  (setf (getf *game-data* :prism2) (make-gl-object :data '(((-1.0 -1.0  0.0) ( 1.0 -1.0  0.0) ( 0.0  1.0  0.0))
                                                           ((-1.0 -1.0  0.0) ( 0.0  0.0 -1.0) ( 1.0 -1.0  0.0))
                                                           ((-1.0 -1.0  0.0) ( 0.0  1.0  0.0) ( 0.0  0.0 -1.0))
                                                           (( 0.0  1.0  0.0) ( 1.0 -1.0  0.0) ( 0.0  0.0 -1.0))) :position '(-3 4 -30)))
  (setf (getf *game-data* :prism3) (make-gl-object :data '(((-1.0 -1.0  0.0) ( 1.0 -1.0  0.0) ( 0.0  1.0  0.0))
                                                           ((-1.0 -1.0  0.0) ( 0.0  0.0 -1.0) ( 1.0 -1.0  0.0))
                                                           ((-1.0 -1.0  0.0) ( 0.0  1.0  0.0) ( 0.0  0.0 -1.0))
                                                           (( 0.0  1.0  0.0) ( 1.0 -1.0  0.0) ( 0.0  0.0 -1.0))) :position '(-1 -4 -25))))
