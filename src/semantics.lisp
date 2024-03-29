#| Copyright 2008 Google Inc. All Rights Reserved.

Licensed under the Apache License, Version 2.0 (the "License")
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an AS IS BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

Author: madscience@google.com (Moshe Looks) 

This defines various basic semantic operations for the language used to
represent evolved programs. |#
(in-package :plop)(plop-opt-set)

;;; for convenice - the language uses these instead of t and nil
(define-constant true 'true)
(define-constant false 'false)
;;; for convenience - used as not-a-number
(define-constant nan 'nan)

;; total-cmp is a total ordering on all plop expressions
;; returns less, nil, or greater, with the important property that (not symbol)
;; is always ordered immediately after symbol
;; markup is ignored
(defun args-total-cmp (l r) ; l and r are argument lists
  (mapl (lambda (l r)
	  (aif (total-cmp (car l) (car r))
	       (return-from args-total-cmp it)
	       (let ((x (consp (cdr l))) (y (consp (cdr r))))
		 (unless (eq x y)
		   (return-from args-total-cmp (if x 'greater 'less))))))
	l r)
  nil)
(flet ((cmp (l r) (if (< l r) 'less (when (> l r) 'greater))))
  (defun num-cmp (l r)
    (case (signum l)
      ((1.0 1 1.0f0 1L0) (case (signum r)
			     ((1.0 1 1.0f0 1L0) (cmp l r))
			     ((0.0 0 0.0f0 0L0) 'greater)
			     (t (or (cmp l (- r)) 'greater))))
      ((0.0 0 0.0f0 0L0) (case r ((0.0 0 0.0f0 0L0) nil) (t 'less)))
      (t (case (signum r)
	   ((-1.0 -1 -1.0f0 -1L0) (cmp r l))
	   ((0.0 0 0.0f0 0L0) 'less)
	   (t (or (cmp (- l) r) 'less)))))))
;; number < vector < lambda-list < let-bindings < symbol
(defun atom-cmp (l r)
  (cond ((eql l r) nil)
	((numberp l) (if (numberp r) (num-cmp l r) 'less))
	((numberp r) 'greater)
	((vectorp l) (if (vectorp r) (some #'total-cmp l r) 'less))
	((vectorp r) 'greater)
	((lambda-list-p l) (if (lambda-list-p r) 
			       (atom-cmp (lambda-list-argnames l)
					 (lambda-list-argnames l))
			       'less))
	((lambda-list-p r) 'greater)
	((let-bindings-p l) 
	 (if (let-bindings-p r)
	     (or (args-total-cmp (let-bindings-names l) (let-bindings-names r))
		 (args-total-cmp (let-bindings-names l) (let-bindings-names r)))
	     'less))
	((let-bindings-p r) 'greater)
	(t (if (string< l r) 'less 'greater))))
(defun total-cmp (l r)
  (if (consp l)
      (if (eq (fn l) 'not)
	  (if (eqfn r 'not)
	      (total-cmp (arg0 l) (arg0 r))
	      (or (total-cmp (arg0 l) r) 'greater))
	  (if (consp r)
	      (if (eq (fn r) 'not)
		  (or (total-cmp l (arg0 r)) 'less)
		  (or (atom-cmp (fn l) (fn r)) 
		      (args-total-cmp (args l) (args r))))
	      'greater))
      (if (consp r)
	  (if (eq (fn r) 'not) 
	      (or (total-cmp l (arg0 r)) 'less)
	      'less)
	  (atom-cmp l r))))
(defun args-total-order (l r)
  (eq (args-total-cmp l r) 'less))
(defun total-order (l r)
  (eq (total-cmp l r) 'less))
(setf aa-order #'total-order)
(define-test total-order
   (assert-equal '(1 2 3) (sort-copy '(3 1 2) #'total-order))

   (assert-equal `(,%(a 1) ,%(a 1 1) ,%(a 2))
		 (sort-copy `(,%(a 2) ,%(a 1) ,%(a 1 1)) #'total-order))
   (assert-equal 
    `(1 2 a b c nil ,%(a 1) ,%(a 2) ,%(b b) ,%(b b b))
    (sort-copy `(2 b 1 a c ,%(a 2) ,%(a 1) ,%(b b) ,%(b b b) nil)
	       #'total-order))
   (assert-equal
    `(,%(a (a (b c))) ,%(a (a (b c)) b) ,%(a (a (b c d))))
    (sort-copy `(,%(a (a (b c))) ,%(a (a (b c)) b) ,%(a (a (b c d))))
	       #'total-order))
   (assert-equal `(a ,%(not a) b ,%(not b) c)
		 (sort-copy `(,%(not a) ,%(not b) c b a) #'total-order)))

(defun args-sexpr-total-cmp (l r) ; l and r are argument lists
  (mapl (lambda (l r)
	  (aif (sexpr-total-cmp (car l) (car r))
	       (return-from args-sexpr-total-cmp it)
	       (let ((x (consp (cdr l))) (y (consp (cdr r))))
		 (unless (eq x y)
		   (return-from args-sexpr-total-cmp (if x 'greater 'less))))))
	l r)
  nil)
(defun sexpr-total-cmp (l r)
  (if (consp l)
      (if (eq (car l) 'not)
	  (if (and (consp r) (eq (car r) 'not))
	      (sexpr-total-cmp (arg0 l) (arg0 r))
	      (or (sexpr-total-cmp (arg0 l) r) 'greater))
	  (if (consp r)
	      (if (eq (car r) 'not)
		  (or (sexpr-total-cmp l (arg0 r)) 'less)
		  (or (atom-cmp (car l) (car r)) 
		      (args-sexpr-total-cmp (args l) (args r))))
	      'greater))
      (if (consp r)
	  (if (eq (car r) 'not) 
	      (or (sexpr-total-cmp l (arg0 r)) 'less)
	      'less)
	  (atom-cmp l r))))
(defun sexpr-total-order (l r)
  (eq (sexpr-total-cmp l r) 'less))

;;; properties of functions
(defun commutativep (x)
  (matches x (and or * +)))
(defun associativep (x)
  (matches x (and or * +)))
(macrolet ((build-identity-functions (items)
	     `(progn
		(defun identityp (x)
		  (matches x ,(mapcar #'car items)))
		(defun identity-elem (x)
		  (ecase x ,@items)))))
  (build-identity-functions
   ((and true) (or false) (* 1) (+ 0) (append nil))))
(defun short-circuits-p (x fn)
  (case fn 
    (and (matches x (nan false)))
    (or (matches x (nan true)))
    (+ (eq x nan))
    (* (or (eq x nan) (and (numberp x) (= x 0))))))
(defun purep (x) ; for now no side-effects - these will be introduced soon
  (declare (ignore x))
  t)
(define-constant +monotypic-fns+ 
    '((and bool bool) (or bool bool) (not bool bool) (0< num bool) (< num bool)
      (<= num bool) (>= num bool) (> num bool) (+ num num) (- num num) 
      (* num num) (/ num num) (exp num num) (log num num) (sin num num)
      (abs num num) (impulse bool num) (order num num) (sqr num num) 
      (sqrt num num) (cos num num)))
(defun closurep (x) ; gp closure - all args are of same type as the output
  (aand (assoc x +monotypic-fns+) (equal (cadr it) (caddr it))))
(defun anti-symmetric-p (x)
  (matches x (sin)))
(defun scale-invariant-p (x)
  (matches x (0< order)))
(defun translation-invariant-p (x)
  (matches x (order)))

;;; properties of expressions
(defun num-junctor-p (expr) (matches (ifn expr) (* +)))
(defun junctorp (expr) 
  (if (listp expr)
      (or (eq (fn expr) 'and) (eq (fn expr) 'or))
      (or (eq expr 'and) (eq expr 'or))))
(defun ring-op-p (expr) ;true if rooted in + or * or and or or
  (matches (ifn expr) (+ * and or)))
(defun literalp (expr)
  (if (listp expr)
      (and (eq (fn expr) 'not) (not (listp (arg0 expr))))
      (and (not (eq expr true)) (not (eq expr false)))))
(defun pequal (expr1 expr2) ;;; tests equality sans markup
  (if (atom expr1) 
      (equalp expr1 expr2)
      (and (consp expr2)
	   (eq (fn expr1) (fn expr2))
	   (let ((a1 (args expr1)) (a2 (args expr2)))
	     (and (eql (length a1) (length a2))
		  (every #'pequal a1 a2))))))
(defun approx-pequal (expr1 expr2) ;;; tests equality sans markup
  (if (atom expr1)
      (if (numberp expr1)
	  (and (numberp expr2) (approx= expr1 expr2))
	  (equalp expr1 expr2))
      (and (consp expr2)
	   (eq (fn expr1) (fn expr2))
	   (let ((a1 (args expr1)) (a2 (args expr2)))
	     (and (eql (length a1) (length a2))
		  (every #'approx-pequal a1 a2))))))
(defun expr-size (expr)
  (if (atom expr) 1 
      (reduce #'+ (args expr) :key #'expr-size :initial-value 1)))
(defun arity (expr) (length (args expr)))
(defun expr-uses-var-p (expr varname)
  (typecase expr 
    (vector (some (bind #'expr-uses-var-p /1 varname) expr))
    (cons (some (bind #'expr-uses-var-p /1 varname) (args expr)))
    (t (eq expr varname))))
(defun free-variables (expr &optional (context *empty-context*))
  (cond ((atom expr) (unless (const-expr-p expr context) (list expr)))
	((lambdap expr) (with-bound-value context (fn-args expr) nil
			  (free-variables (fn-body expr) context)))
	(t (reduce (lambda (x y) (delete-duplicates (nconc x y)))
		   (args expr) :key #'free-variables))))
(define-test free-variables
  (assert-equal '(x y z)
		(sort (free-variables %(and (or x y) (or (not x) z) y))
		      #'string<))
  (assert-equal nil (free-variables %(lambda (x y) (* x y))))
  (assert-equal '(x q) (free-variables %(cons x (lambda (x y) (* x y q))))))
(defun lambdap (value) 
  (and (consp value) (consp (car value)) (eq (caar value) 'lambda)))
(defun tuple-value-p (expr) (arrayp expr))
(defun tuple-args (expr) 
  (if (arrayp expr)
      (coerce expr 'list)
      (progn (assert (eqfn expr 'tuple)) (args expr))))

(defun fold-args (fold) (lambda-list-argnames (arg0 (arg0 fold))))
(defun fold-body (fold) (fn-body (arg0 fold)))

(defun pe-fold (argnames fn-body list initial leftp &aux (i (impulse leftp)))
  (reduce (lambda (expr value)
	    (expr-substitute fn-body 
			     (elt argnames i) expr
			     (elt argnames (- 1 i)) value))
	  list :initial-value initial :from-end (not leftp)))

;;; constness
(defun const-atom-value-p (x)
  (or (numberp x) (matches x (true false nan nil and or not + - * /  log exp sin
			      fold cons car cdr if impulse 0< nand nor tuple 
			      order list append))))
(defun const-value-p (x)
  (cond ((atom x) (const-atom-value-p x))
	((lambdap x) (with-bound-value *empty-context* (fn-args x) nil
		       (const-expr-p (fn-body x) *empty-context*)))
	(t (every #'const-value-p x))))

;;; fixme pure
;;  ((eq (fn expr) 'lambda) (with-bound-value context (fn-args expr) nil
;;	      (const-expr-p (fn-body expr) context)))
;;  ((purep (fn expr)) (every (bind #'const-value-p /1 context) (args expr)))))
(defun const-expr-p (expr &optional (context *empty-context*))
  (cond ((atom expr) (or (const-atom-value-p expr) (valuedp expr context)))
	((eq (fn expr) 'lambda) (with-bound-value context (fn-args expr) nil
				  (const-expr-p (fn-body expr) context)))
	((eq (fn expr) 'let) (and (every (bind #'const-expr-p /1 context)
					 (let-bindings-values (arg0 expr)))
				  (with-bound-value context 
				      (let-bindings-names (arg0 expr)) nil
				      (const-expr-p (arg1 expr)))))
	(t (and (const-expr-p (fn expr))
		(every (bind #'const-expr-p /1 context) (args expr))))))
(define-test const-expr-p
  (assert-false (const-expr-p 'x))
  (assert-true (const-expr-p 42))
  (assert-true (const-expr-p %(lambda (x) (+ x 1))))
  (assert-false (const-expr-p %(lambda (x) (+ x y))))
  (assert-true (const-expr-p %(list 1 2 3)))
  (assert-false (const-expr-p %(list 1 2 x 3))))

;;; converting values to expressions (like quote)
(defun value-to-expr (value)
  (cond ((and (consp value) (not (lambdap value))) (pcons 'list value))
	((tuple-value-p value) (pcons 'tuple (coerce value 'list)))
	(t value)))

;;; breaking apart expressions
(defmacro dexpr (expr-name (fn args markup) &body body) ;;; destructure expr
  `(let ((,fn (fn ,expr-name))
	 (,args (args ,expr-name))
	 (,markup (markup ,expr-name)))
     ,@body))
(macrolet ;;; decompositions of expressions by contents
    ((mkdecomposer (name &body conditions)
       `(defmacro ,name (expr &body clauses)
	  `(cond ,@(mapcar (lambda (clause)
			     (dbind (pred &body body) clause
			       (let ((condition 
				      (case pred
					((t) 't)
					,@conditions
					(t (if (consp pred)
					       `(matches (ifn ,expr) ,pred)
					       `(eq (ifn ,expr) ',pred))))))
				 `(,condition ,@body))))
			   clauses)))))
  (mkdecomposer decompose-num
		(const `(numberp ,expr)))
  (mkdecomposer decompose-bool
		(literal `(literalp ,expr))
		(const `(matches ,expr (true false)))
		(junctor `(junctorp ,expr)))
  (mkdecomposer decompose-tuple)
  (mkdecomposer decompose-function)
  (mkdecomposer decompose-list))
(define-test decompose-num
  (assert-equal 
   '(cond ((numberp expr) foo) 
     ((eq (ifn expr) '/) goo)
     ((matches (ifn expr) (* +)) loo)
     (t moo))
   (macroexpand-1 '(decompose-num 
		    expr (const foo) (/ goo) ((* +) loo) (t moo)))))
(define-test decompose-bool
  (flet ((dectest (expr)
	   (decompose-bool expr
	     (junctor 'junctor)
	     (literal 'literal)
	     (t 'other))))
    (assert-equal 'literal (dectest 'x))
    (assert-equal 'literal (dectest %(not x)))
    (assert-equal 'junctor (dectest %(and x y)))
    (assert-equal 'other (dectest %(foo bar baz))))
  (assert-equal 42 (decompose-bool true (true 42) (false 3) (t 99))))

(defun split-by-coefficients (exprs &key (op '*) (identity 1))
  (with-collectors (coefficient term)
    (mapc (lambda (expr)
	    (dbind (coefficient term)
		(if (and (consp expr) (eq (fn expr) op) (numberp (arg0 expr)))
		    `(,(arg0 expr) ,(if (cddr (args expr))
					(pcons op (cdr (args expr))
					       (markup expr))
					(arg1 expr)))
		    `(,identity ,expr))
	      (coefficient coefficient)
	      (term term)))
	  exprs)))
(defun dual-decompose (expr op op-identity dual dual-identity)
  (flet ((mksplit (offset exprs)
	   (mvbind (weights terms) 
	       (split-by-coefficients exprs :op dual :identity dual-identity)
	     (values offset weights terms))))
    (cond ((numberp expr) (values expr nil nil))
	  ((not (consp expr)) (values op-identity `(,dual-identity) `(,expr)))
	  ((eq (fn expr) op) (if (numberp (arg0 expr))
				 (mksplit (arg0 expr) (cdr (args expr)))
				 (mksplit op-identity (args expr))))
	  (t (mksplit op-identity `(,expr))))))

(defun split-sum-of-products (expr) (dual-decompose expr '+ 0 '* 1))
(defun split-product-of-sums (expr) (dual-decompose expr '* 1 '+ 0))
(defun split-by-op (expr) 
  (funcall (ecase (fn expr) 
	     (+ #'split-sum-of-products)
	     (* #'split-product-of-sums))
	   expr))

(define-test dual-decompose
  (flet ((ldass (expr o1 ws1 ts1 o2 ws2 ts2)
	   (mvbind (o ws ts) (split-sum-of-products expr)
	     (assert-equal o1 o)
	     (assert-equal ws1 ws)
	     (assert-equal ts1 ts))
	   (mvbind (o ws ts) (split-product-of-sums expr)
	     (assert-equal o2 o)
	     (assert-equal ws2 ws)
	     (assert-equal ts2 ts))))
    (ldass %(+ 1 (* 2 x) (* 3 y z))
	   1 '(2 3) `(x ,%(* y z))
	   1 '(1) `(,%(+ (* 2 x) (* 3 y z))))
    (ldass 42 
	   42 nil nil
	   42 nil nil)
    (ldass %(+ 1 x)
	   1 '(1) '(x)
	   1 '(1) '(x))
    (ldass %(+ x (* y z))
	   0 '(1 1) `(x ,%(* y z))
	   1 '(0) `(,%(+ x (* y z))))
    (ldass 'x 
	   0 '(1) '(x)
	   1 '(0) '(x))
    (ldass %(sin x)
	   0 '(1) `(,%(sin x))
	   1 '(0) `(,%(sin x)))
    (ldass %(* 2 (+ x y) (+ 3 x) (+ x y z))
	   0 '(2) `(,%(* (+ x y) (+ 3 x) (+ x y z)))
	   2 '(0 3 0) `(,%(+ x y) x ,%(+ x y z)))
    (ldass 0
	   0 nil nil
	   0 nil nil)))

;;; macro-writing macro for defining functions as sets of toplevel forms,
;;; each one acting on a different type
(defmacro defdefbytype (defname name &key (args '(expr context)))
  (assert (not (find 'type args)))
  `(progn 
     (defvar ,name nil)
     (defun ,name (,@args type)
       (if (consp type)
	   (funcall (cdr (assoc (car type) ,name)) ,@args type)
	   (funcall (cdr (assoc type ,name)) ,@args)))
     (defmacro ,defname (typematch args &body body)
       `(let ((fn (lambda ,args ,@body)))
	  (aif (assoc ',typematch ,',name)
	       (rplacd it fn)
	       (push (cons ',typematch fn) ,',name))))))

;;; a deep copy for values and expressions
;;; note - copies markup too, but assumes it to be all symbols
(defun pclone (expr)
  (assert (not (canonp expr)))
  (if (consp expr)
      (pcons (fn expr) (mapcar #'pclone (args expr)) (copy-list (markup expr)))
      (etypecase expr 
	(vector (map 'vector #'pclone expr))
	(lambda-list expr)
	(let-bindings (copy-let-bindings expr))
	(number expr)
	(symbol expr))))

;;; returns a predicate that checks for the validity (non-nan etc.) of a value
;;; of the given type
(defun make-validator (type)
  (ecase (icar type)
    (bool (lambda (x) (not (eq x nan))))
    (num #'finitep)
    (tuple (let ((subs (mapcar #'make-validator (cdr type))))
	     (lambda (array)
	       (and (not (eq array nan))
		    (every #'funcall subs array)))))
    (list (let ((sub (make-validator (cadr type))))
	    (lambda (list) (every sub list))))))

;;; note: strips markup
(defun expr-substitute (expr &rest values)
  (labels ((sub (x &aux (match (getf values x +no-value+)))
	     (if (eq match +no-value+)
		 (typecase x
		   (vector (map 'vector #'sub x))
		   (cons (pcons (fn x) (mapcar #'sub (args x))))
		   (t x))
		 (pclone match))))
    (sub expr)))
