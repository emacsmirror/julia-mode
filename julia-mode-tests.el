;;; julia-mode-tests.el --- Tests for julia-mode.el

;; Copyright (C) 2009-2024 Julia contributors
;; URL: https://github.com/JuliaLang/julia
;; Keywords: languages

;;; Usage:

;; From command line:
;;
;; emacs -batch -L . -l ert -l julia-mode-tests.el -f  ert-run-tests-batch-and-exit

;;; Commentary:
;; Contains ert tests for julia-mode.el

;;; License:
;; Permission is hereby granted, free of charge, to any person obtaining
;; a copy of this software and associated documentation files (the
;; "Software"), to deal in the Software without restriction, including
;; without limitation the rights to use, copy, modify, merge, publish,
;; distribute, sublicense, and/or sell copies of the Software, and to
;; permit persons to whom the Software is furnished to do so, subject to
;; the following conditions:
;;
;; The above copyright notice and this permission notice shall be
;; included in all copies or substantial portions of the Software.
;;
;; THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
;; EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
;; MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
;; NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
;; LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
;; OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
;; WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

;;; Code:

(require 'julia-mode)
(require 'ert)

(defmacro julia--should-indent (from to)
  "Assert that we indent text FROM producing text TO in `julia-mode'."
  `(with-temp-buffer
     (let ((julia-indent-offset 4))
       (julia-mode)
       (insert ,from)
       (indent-region (point-min) (point-max))
       (should (equal (buffer-substring-no-properties (point-min) (point-max))
                      ,to)))))

(defun julia--get-font-lock (text pos)
  "Get the face of `text' at `pos' when font-locked as Julia code in this mode."
  (with-temp-buffer
     (julia-mode)
     (insert text)
     (if (fboundp 'font-lock-ensure)
         (font-lock-ensure (point-min) (point-max))
       (with-no-warnings
         (font-lock-fontify-buffer)))
     (get-text-property pos 'face)))

(defmacro julia--should-font-lock (text pos face)
  "Assert that TEXT at position POS gets font-locked with FACE in `julia-mode'."
  `(should (eq ,face (julia--get-font-lock ,text ,pos))))

(defun julia--should-move-point-helper (text fun from to &optional end &rest args)
  "Takes the same arguments as `julia--should-move-point', returns a cons of the expected and the actual point."
  (with-temp-buffer
    (julia-mode)
    (insert text)
    (indent-region (point-min) (point-max))
    (goto-char (point-min))
    (if (stringp from)
        (re-search-forward from)
      (goto-char from))
    (apply fun args)
    (let ((actual-to (point))
          (expected-to
           (if (stringp to)
               (progn (goto-char (point-min))
                      (re-search-forward to)
                      (if end
                          (goto-char (match-end 0))
                        (goto-char (match-beginning 0))
                        (point-at-bol)))
             to)))
      (cons expected-to actual-to))))

(defmacro julia--should-move-point (text fun from to &optional end &rest args)
  "With TEXT in `julia-mode', after calling FUN, the point should move FROM\
to TO.  If FROM is a string, move the point to matching string before calling
function FUN.  If TO is a string, match resulting point to point a beginning of
matching line or end of match if END is non-nil.  Optional ARG is passed to FUN."
  (declare (indent defun))
  `(let ((positions (julia--should-move-point-helper ,text ,fun ,from ,to ,end ,@args)))
     (should (eq (car positions) (cdr positions)))))

;;; indent tests

(ert-deftest julia--test-indent-if ()
  "We should indent inside if bodies."
  (julia--should-indent
   "
if foo
bar
end"
   "
if foo
    bar
end"))

(ert-deftest julia--test-indent-else ()
  "We should indent inside else bodies."
  (julia--should-indent
   "
if foo
    bar
else
baz
end"
   "
if foo
    bar
else
    baz
end"))

(ert-deftest julia--test-indent-toplevel ()
  "We should not indent toplevel expressions. "
  (julia--should-indent
   "
foo()
bar()"
   "
foo()
bar()"))

(ert-deftest julia--test-indent-nested-if ()
  "We should indent for each level of indentation."
  (julia--should-indent
   "
if foo
    if bar
bar
    end
end"
   "
if foo
    if bar
        bar
    end
end"))

(ert-deftest julia--test-indent-module-keyword ()
  "Module should not increase indentation at any level."
  (julia--should-indent
   "
module
begin
    a = 1
end
end"
   "
module
begin
    a = 1
end
end")
  (julia--should-indent
   "
begin
module
foo
end
end"
   "
begin
    module
    foo
    end
end"))

(ert-deftest julia--test-indent-function ()
  "We should indent function bodies."
  (julia--should-indent
   "
function foo()
bar
end"
   "
function foo()
    bar
end"))

(ert-deftest julia--test-indent-begin ()
  "We should indent after a begin keyword."
  (julia--should-indent
   "
@async begin
bar
end"
   "
@async begin
    bar
end"))

(ert-deftest julia--test-indent-paren ()
  "We should indent to line up with the text after an open paren."
  (julia--should-indent
   "
foobar(bar,
baz)"
   "
foobar(bar,
       baz)"))

(ert-deftest julia--test-indent-paren-space ()
  "We should indent to line up with the text after an open
paren, even if there are additional spaces."
  (julia--should-indent
   "
foobar( bar,
baz )"
   "
foobar( bar,
        baz )"))

(ert-deftest julia--test-indent-paren-newline ()
  "python-mode-like indentation."
  (julia--should-indent
   "
foobar(
bar,
baz)"
   "
foobar(
    bar,
    baz)")
  (julia--should-indent
   "
foobar(
bar,
baz
)"
   "
foobar(
    bar,
    baz
)"))

(ert-deftest julia--test-indent-equals ()
  "We should increase indent on a trailing =."
  (julia--should-indent
   "
foo() =
bar"
   "
foo() =
    bar"))

(ert-deftest julia--test-indent-operator ()
  "We should increase indent after the first trailing operator
but not again after that."
  (julia--should-indent
   "
foo() |>
bar |>
baz
qux"
   "
foo() |>
    bar |>
    baz
qux")
  (julia--should-indent
   "x \\
y \\
z"
   "x \\
    y \\
    z"))

(ert-deftest julia--test-indent-ignores-blank-lines ()
  "Blank lines should not affect indentation of non-blank lines."
  (julia--should-indent
   "
if foo

bar
end"
   "
if foo

    bar
end"))

(ert-deftest julia--test-indent-comment-equal ()
  "`=` at the end of comment should not increase indent level."
  (julia--should-indent
   "
# a =
# b =
c"
   "
# a =
# b =
c"))

(ert-deftest julia--test-indent-leading-paren ()
  "`(` at the beginning of a line should not affect indentation."
  (julia--should-indent
   "
\(1)"
   "
\(1)"))

(ert-deftest julia--test-top-level-following-paren-indent ()
  "`At the top level, a previous line indented due to parens should not affect indentation."
  (julia--should-indent
   "y1 = f(x,
       z)
y2 = g(x)"
   "y1 = f(x,
       z)
y2 = g(x)"))

(ert-deftest julia--test-indentation-of-multi-line-strings ()
  "Indentation should only affect the first line of a multi-line string."
  (julia--should-indent
   "   a = \"\"\"
    description
begin
    foo
bar
end
\"\"\""
   "a = \"\"\"
    description
begin
    foo
bar
end
\"\"\""))

(ert-deftest julia--test-indent-of-end-in-brackets ()
  "Ignore end keyword in brackets for the purposes of indenting blocks."
  (julia--should-indent
   "begin
    begin
        arr[1: end - 1]
        end
end"
   "begin
    begin
        arr[1: end - 1]
    end
end"))

(ert-deftest julia--test-indent-after-commented-keyword ()
  "Ignore keywords in comments when indenting."
  (julia--should-indent
   "# if foo
a = 1"
   "# if foo
a = 1"))

(ert-deftest julia--test-indent-after-commented-end ()
  "Ignore `end` in comments when indenting."
  (julia--should-indent
   "if foo
a = 1
#end
b = 1
end"
   "if foo
    a = 1
    #end
    b = 1
end"))

(ert-deftest julia--test-indent-import-export-using ()
  "Toplevel using, export, and import."
  (julia--should-indent
   "export bar, baz,
quux"
   "export bar, baz,
    quux")
  (julia--should-indent
   "using Foo: bar ,
baz,
quux
notpartofit"
   "using Foo: bar ,
    baz,
    quux
notpartofit")
  (julia--should-indent
   "using Foo.Bar: bar ,
baz,
quux
notpartofit"
   "using Foo.Bar: bar ,
    baz,
    quux
notpartofit"))

(ert-deftest julia--test-indent-anonymous-function ()
  "indentation for function(args...)"
  (julia--should-indent
   "function f(x)
function(y)
x+y
end
end"
   "function f(x)
    function(y)
        x+y
    end
end"))

(ert-deftest julia--test-backslash-indent ()
  "indentation for function(args...)"
  (julia--should-indent
   "(\\)
   1
   (:\\)
       1"
   "(\\)
1
(:\\)
1"))

(ert-deftest julia--test-indent-keyword-paren ()
  "indentation for ( following keywords"
  "if( a>0 )
end

    function( i=1:2 )
        for( j=1:2 )
            for( k=1:2 )
            end
            end
        end"
  "if( a>0 )
end

function( i=1:2 )
    for( j=1:2 )
        for( k=1:2 )
        end
    end
end")

(ert-deftest julia--test-indent-ignore-:end-as-block-ending ()
  "Do not consider `:end` as a block ending."
  (julia--should-indent
   "if a == :end
r = 1
end"
   "if a == :end
    r = 1
end")

  (julia--should-indent
   "if a == a[end-4:end]
r = 1
end"
   "if a == a[end-4:end]
    r = 1
end")
  )

(ert-deftest julia--test-indent-hanging ()
  "Test indentation for line following a hanging operator."
  (julia--should-indent
   "
f(x) =
x*
x"
   "
f(x) =
    x*
    x")
  (julia--should-indent
   "
a = \"#\" |>
identity"
   "
a = \"#\" |>
    identity")
  ;; make sure we don't interpret a hanging operator in a comment as
  ;; an actual hanging operator for indentation
  (julia--should-indent
   "
a = \"#\" # |>
identity"
   "
a = \"#\" # |>
identity"))

(ert-deftest julia--test-indent-quoted-single-quote ()
  "We should indent after seeing a character constant containing a single quote character."
  (julia--should-indent "
if c in ('\'')
s = \"$c$c\"*string[startpos:pos]
end
" "
if c in ('\'')
    s = \"$c$c\"*string[startpos:pos]
end
"))

(ert-deftest julia--test-indent-block-inside-paren ()
  "We should indent a block inside of a parenthetical."
  (julia--should-indent "
variable = func(
arg1,
arg2,
if cond
statement()
arg3
else
arg3
end,
arg4
)" "
variable = func(
    arg1,
    arg2,
    if cond
        statement()
        arg3
    else
        arg3
    end,
    arg4
)"))

(ert-deftest julia--test-indent-block-inside-hanging-paren ()
  "We should indent a block inside of a hanging parenthetical."
  (julia--should-indent "
variable = func(arg1,
arg2,
if cond
statement()
arg3
else
arg3
end,
arg4
)" "
variable = func(arg1,
                arg2,
                if cond
                    statement()
                    arg3
                else
                    arg3
                end,
                arg4
                )"))

(ert-deftest julia--test-indent-nested-block-inside-paren ()
  "We should indent a nested block inside of a parenthetical."
  (julia--should-indent "
variable = func(
arg1,
if cond1
statement()
if cond2
statement()
end
arg3
end,
arg4
)" "
variable = func(
    arg1,
    if cond1
        statement()
        if cond2
            statement()
        end
        arg3
    end,
    arg4
)"))

(ert-deftest julia--test-indent-block-next-to-paren ()
  (julia--should-indent "
var = func(begin
test
end
)" "
var = func(begin
               test
           end
           )"))

;;; font-lock tests

(ert-deftest julia--test-symbol-font-locking-at-bol ()
  "Symbols get font-locked at beginning or line."
  (julia--should-font-lock
   ":a in keys(Dict(:a=>1))" 1 'julia-quoted-symbol-face))

(ert-deftest julia--test-symbol-font-locking-after-backslash ()
  "Even with a \ before the (, it is recognized as matching )."
  (let ((string "function \\(a, b)"))
    (julia--should-font-lock string (1- (length string)) nil)))

(ert-deftest julia--test-function-assignment-font-locking ()
  (julia--should-font-lock
   "f(x) = 1" 1 'font-lock-function-name-face)
  (julia--should-font-lock
   "Base.f(x) = 1" 6 'font-lock-function-name-face)
  (julia--should-font-lock
   "f(x) where T = 1" 1 'font-lock-function-name-face)
  (julia--should-font-lock
   "f(x) where{T} = 1" 1 'font-lock-function-name-face)
  (dolist (def '("f(x)::T = 1" "f(x) :: T = 1" "f(x::X)::T where X = x"))
    (julia--should-font-lock def 1 'font-lock-function-name-face)))

(ert-deftest julia--test-where-keyword-font-locking ()
  (julia--should-font-lock
   "f(x) where T = 1" 6 'font-lock-keyword-face)
  (dolist (pos '(22 30))
    (julia--should-font-lock
     "function f(::T, ::Z) where T where Z
          1
      end"
     pos 'font-lock-keyword-face)))

(ert-deftest julia--test-escaped-strings-dont-terminate-string ()
  "Symbols get font-locked at beginning or line."
  (let ((string "\"\\\"\"; function"))
    (dolist (pos '(1 2 3 4))
      (julia--should-font-lock string pos font-lock-string-face))
    (julia--should-font-lock string (length string) font-lock-keyword-face)))

(ert-deftest julia--test-ternary-font-lock ()
  "? and : in ternary expression font-locked as keywords"
  (let ((string "true ? 1 : 2"))
    (julia--should-font-lock string 6 font-lock-keyword-face)
    (julia--should-font-lock string 10 font-lock-keyword-face))
  (let ((string "true ?\n    1 :\n    2"))
    (julia--should-font-lock string 6 font-lock-keyword-face)
    (julia--should-font-lock string 14 font-lock-keyword-face)))

(ert-deftest julia--test-forloop-font-lock ()
  "for and in/=/∈ font-locked as keywords in loops and comprehensions"
  (let ((string "for i=1:10\nprintln(i)\nend"))
    (julia--should-font-lock string 1 font-lock-keyword-face)
    (julia--should-font-lock string 6 font-lock-keyword-face))
  (let ((string "for i in 1:10\nprintln(i)\nend"))
    (julia--should-font-lock string 3 font-lock-keyword-face)
    (julia--should-font-lock string 7 font-lock-keyword-face))
  (let ((string "for i∈1:10\nprintln(i)\nend"))
    (julia--should-font-lock string 2 font-lock-keyword-face)
    (julia--should-font-lock string 6 font-lock-keyword-face))
  (let ((string "[i for i in 1:10]"))
    (julia--should-font-lock string 4 font-lock-keyword-face)
    (julia--should-font-lock string 10 font-lock-keyword-face))
  (let ((string "(i for i in 1:10)"))
    (julia--should-font-lock string 4 font-lock-keyword-face)
    (julia--should-font-lock string 10 font-lock-keyword-face))
  (let ((string "[i for i ∈ 1:15 if w(i) == 15]"))
    (julia--should-font-lock string 4 font-lock-keyword-face)
    (julia--should-font-lock string 10 font-lock-keyword-face)
    (julia--should-font-lock string 17 font-lock-keyword-face)
    (julia--should-font-lock string 25 nil)
    (julia--should-font-lock string 26 nil)))

(ert-deftest julia--test-typeparams-font-lock ()
  (let ((string "@with_kw struct Foo{A <: AbstractThingy, B <: Tuple}\n    bar::A\n    baz::B\nend"))
    (julia--should-font-lock string 30 font-lock-type-face) ; AbstractThingy
    (julia--should-font-lock string 50 font-lock-type-face) ; Tuple
    (julia--should-font-lock string 63 font-lock-type-face) ; A
    (julia--should-font-lock string 74 font-lock-type-face) ; B
    ))

(ert-deftest julia--test-single-quote-string-font-lock ()
  "Test that single quoted strings are font-locked correctly even with escapes."
  ;; Issue #15
  (let ((s1 "\"a\\\"b\"c"))
    (julia--should-font-lock s1 2 font-lock-string-face)
    (julia--should-font-lock s1 5 font-lock-string-face)
    (julia--should-font-lock s1 7 nil)))

(ert-deftest julia--test-triple-quote-string-font-lock ()
  "Test that triple quoted strings are font-locked correctly even with escapes."
  ;; Issue #15
  (let ((s1 "\"\"\"a\\\"\\\"\"b\"\"\"d")
        (s2 "\"\"\"a\\\"\"\"b\"\"\"d")
        (s3 "\"\"\"a```b\"\"\"d")
        (s4 "\\\"\"\"a\\\"\"\"b\"\"\"d")
        (s5 "\"\"\"a\\\"\"\"\"b"))
    (julia--should-font-lock s1 4 font-lock-string-face)
    (julia--should-font-lock s1 10 font-lock-string-face)
    (julia--should-font-lock s1 14 nil)
    (julia--should-font-lock s2 4 font-lock-string-face)
    (julia--should-font-lock s2 9 font-lock-string-face)
    (julia--should-font-lock s2 13 nil)
    (julia--should-font-lock s3 4 font-lock-string-face)
    (julia--should-font-lock s3 8 font-lock-string-face)
    (julia--should-font-lock s3 12 nil)
    (julia--should-font-lock s4 5 font-lock-string-face)
    (julia--should-font-lock s4 10 font-lock-string-face)
    (julia--should-font-lock s4 14 nil)
    (julia--should-font-lock s5 4 font-lock-string-face)
    (julia--should-font-lock s5 10 nil)))

(ert-deftest julia--test-triple-quote-cmd-font-lock ()
  "Test that triple-quoted cmds are font-locked correctly even with escapes."
  (let ((s1 "```a\\`\\``b```d")
        (s2 "```a\\```b```d")
        (s3 "```a\"\"\"b```d")
        (s4 "\\```a\\```b```d"))
    (julia--should-font-lock s1 4 font-lock-string-face)
    (julia--should-font-lock s1 10 font-lock-string-face)
    (julia--should-font-lock s1 14 nil)
    (julia--should-font-lock s2 4 font-lock-string-face)
    (julia--should-font-lock s2 9 font-lock-string-face)
    (julia--should-font-lock s2 13 nil)
    (julia--should-font-lock s3 4 font-lock-string-face)
    (julia--should-font-lock s3 8 font-lock-string-face)
    (julia--should-font-lock s3 12 nil)
    (julia--should-font-lock s4 5 font-lock-string-face)
    (julia--should-font-lock s4 10 font-lock-string-face)
    (julia--should-font-lock s4 14 nil)))

(ert-deftest julia--test-ccall-font-lock ()
  (let ((s1 "t = ccall(:clock, Int32, ())"))
    (julia--should-font-lock s1 5 font-lock-builtin-face)
    (julia--should-font-lock s1 4 nil)
    (julia--should-font-lock s1 10 nil)))

(ert-deftest julia--test-char-const-font-lock ()
  (dolist (c '("'\\''"
               "'\\\"'"
               "'\\\\'"
               "'\\010'"
               "'\\xfe'"
               "'\\uabcd'"
               "'\\Uabcdef01'"
               "'\\n'"
               "'a'" "'z'" "'''"))
    (let ((c (format " %s " c)))
      (progn
        (julia--should-font-lock c 1 nil)
        (julia--should-font-lock c 2 font-lock-string-face)
        (julia--should-font-lock c (- (length c) 1) font-lock-string-face)
        (julia--should-font-lock c (length c) nil)))))

(ert-deftest julia--test-const-def-font-lock ()
  (let ((string "const foo = \"bar\""))
    (julia--should-font-lock string 1 font-lock-keyword-face) ; const
    (julia--should-font-lock string 5 font-lock-keyword-face) ; const
    (julia--should-font-lock string 7 font-lock-variable-name-face) ; foo
    (julia--should-font-lock string 9 font-lock-variable-name-face) ; foo
    (julia--should-font-lock string 11 nil) ; =
    ))

(ert-deftest julia--test-const-def-font-lock-underscores ()
  (let ((string "@macro const foo_bar = \"bar\""))
    (julia--should-font-lock string 8 font-lock-keyword-face) ; const
    (julia--should-font-lock string 12 font-lock-keyword-face) ; const
    (julia--should-font-lock string 14 font-lock-variable-name-face) ; foo
    (julia--should-font-lock string 17 font-lock-variable-name-face) ; _
    (julia--should-font-lock string 20 font-lock-variable-name-face) ; bar
    (julia--should-font-lock string 22 nil) ; =
    ))

(ert-deftest julia--test-!-font-lock ()
  (let ((string "!@macro foo()"))
    (julia--should-font-lock string 1 nil)
    (julia--should-font-lock string 2 'julia-macro-face)
    (julia--should-font-lock string 7 'julia-macro-face)
    (julia--should-font-lock string 8 nil)))

;;; Movement
(ert-deftest julia--test-beginning-of-defun-assn-1 ()
  "Point moves to beginning of single-line assignment function."
  (julia--should-move-point
    "f() = \"a + b\"" 'beginning-of-defun "a \\+" 1))

(ert-deftest julia--test-beginning-of-defun-assn-2 ()
  "Point moves to beginning of multi-line assignment function."
  (julia--should-move-point
    "f(x)=
    x*
    x" 'beginning-of-defun "x$" 1))

(ert-deftest julia--test-beginning-of-defun-assn-3 ()
  "Point moves to beginning of multi-line assignment function adjoining
another function."
  (julia--should-move-point
    "f( x 
)::Int16 = x / 2
f2(y)=
y*y" 'beginning-of-defun "2" 1))

(ert-deftest julia--test-beginning-of-defun-assn-4 ()
  "Point moves to beginning of 2nd multi-line assignment function adjoining
another function."
  (julia--should-move-point
    "f( x 
)::Int16 = 
x /
2
f2(y) =
y*y" 'beginning-of-defun "\\*y" "f2"))

(ert-deftest julia--test-beginning-of-defun-assn-5 ()
  "Point moves to beginning of 1st multi-line assignment function adjoining
another function with prefix arg."
  (julia--should-move-point
    "f( x 
)::Int16 = 
x /
2
f2(y) =
y*y" 'beginning-of-defun "y\\*y" 1 nil 2))

(ert-deftest julia--test-beginning-of-macro ()
  "Point moves to beginning of macro."
  (julia--should-move-point
    "macro current_module()
return VERSION >= v\"0.7-\" :(@__MODULE__) : :(current_module())))
end" 'beginning-of-defun "@" 1))

(ert-deftest julia--test-beginning-of-defun-1 ()
  "Point moves to beginning of defun in 'function's."
  (julia--should-move-point
    "function f(a, b)
a + b
end" 'beginning-of-defun "f(" 1))

(ert-deftest julia--test-beginning-of-defun-nested-1 ()
  "Point moves to beginning of nested function."
  (julia--should-move-point
    "function f(x)

function fact(n)
if n == 0
return 1
else
return n * fact(n-1)
end
end

return fact(x)
end" 'beginning-of-defun "fact(n" "function fact"))

(ert-deftest julia--test-beginning-of-defun-nested-2 ()
  "Point moves to beginning of outermost function with prefix arg."
  (julia--should-move-point
    "function f(x)

function fact(n)
if n == 0
return 1
else
return n * fact(n-1)
end
end

return fact(x)
end" 'beginning-of-defun "n \\*" 1 nil 2))

(ert-deftest julia--test-beginning-of-defun-no-move ()
  "Point shouldn't move if there is no previous function."
  (julia--should-move-point
    "1 + 1
f(x) = x + 1" 'beginning-of-defun "\\+" 4))

(ert-deftest julia--test-end-of-defun-assn-1 ()
  "Point should move to end of assignment function."
  (julia--should-move-point
    "f(x)::Int8 = 
x *x" 'end-of-defun "(" "*x" 'end))

(ert-deftest julia--test-end-of-defun-nested-1 ()
  "Point should move to end of inner function when called from inner."
  (julia--should-move-point
    "function f(x)
function fact(n)
if n == 0
return 1
else
return n * fact(n-1)
end
end
return fact(x)
end" 'julia-end-of-defun "function fact(n)" "end[ \n]+end" 'end))

(ert-deftest julia--test-end-of-defun-nested-2 ()
  "Point should move to end of outer function when called from outer."
  (julia--should-move-point
    "function f(x)
function fact(n)
if n == 0
return 1
else
return n * fact(n-1)
end
end
return fact(x)
end" 'julia-end-of-defun "function f(x)" "return fact(x)[ \n]+end" 'end))

;;;
;;; latex completion tests
;;;

(defun julia--find-latex (contents position)
  "Find bounds of LaTeX symbol in CONTENTS with point at POSITION, `'((start . end) string)'. Return NIL if no symbol is found."
  (with-temp-buffer
    (julia-mode)
    (insert contents)
    (goto-char position)
    (let ((beg (julia--latexsub-start-symbol)))
      (when beg
        (let ((end (julia-mode--latexsubs-longest-partial-end beg)))
          (list (cons beg end) (buffer-substring beg end)))))))

(ert-deftest julia--test-find-latex ()
  (should (equal (julia--find-latex "\\alpha " 7) '((1 . 7) "\\alpha")))
  (should (equal (julia--find-latex "\\alpha " 3) '((1 . 7) "\\alpha")))
  (should (equal (julia--find-latex "x\\alpha " 8) '((2 . 8) "\\alpha")))
  (should (equal (julia--find-latex "x\\alpha " 3) '((2 . 8) "\\alpha")))
  (should (equal (julia--find-latex "\\kappa\\alpha(" 13) '((7 . 13) "\\alpha")))
  (should (equal (julia--find-latex "\\kappa\\alpha(" 4) '((1 . 7) "\\kappa")))
  (should (equal (julia--find-latex "α\\hat_mean" 3) '((2 . 6) "\\hat")))
  (should (not (julia--find-latex "   later" 1))))

;;;
;;; abbrev tests
;;;

(defun julia--abbrev (contents position)
  "Call `expand-abbrev' in buffer with CONTENTS at POSITION."
  (with-temp-buffer
    (julia-mode)
    (insert contents)
    (goto-char position)
    (expand-abbrev)
    (buffer-string)))

(ert-deftest julia--test-latex-abbrev ()
  (should (equal (julia--abbrev "\\alpha " 7) "α "))
  (should (equal (julia--abbrev "x\\alpha " 8)  "xα "))
  (should (equal (julia--abbrev "\\kappa\\alpha(" 13)  "\\kappaα("))
  ; (should (equal (julia--abbrev "\\alpha(" 6)  "α")) ; BROKEN
  )

(defun julia--call-latexsub-exit-function (contents beg position name auto-abbrev)
  "Return buffer produced by `julia--latexsub-exit-function'."
  (with-temp-buffer
    (insert contents)
    (goto-char position)
    (setq-local julia-automatic-latexsub auto-abbrev)
    (funcall (julia--latexsub-exit-function beg) name 'finished)
    (buffer-string)))

(ert-deftest julia--test-latexsub-exit-function ()
  (should (equal (julia--call-latexsub-exit-function "\\alpha" 1 7 "\\alpha" t) "α"))
  (should (equal (julia--call-latexsub-exit-function "x\\alpha " 2 8 "\\alpha" t)  "xα "))
  (should (equal (julia--call-latexsub-exit-function
                  "\\kappa\\alpha(" 7 13 "\\alpha" t)
                 "\\kappaα("))
  ;; Test that whitespace is stripped from `:exit-function' NAME for compatibility with helm
  (should (equal (julia--call-latexsub-exit-function "x\\alpha " 2 8 "\\alpha " t)  "xα "))
  ;; test that LaTeX not expanded when `julia-automatic-latexsub' is nil
  (should (equal (julia--call-latexsub-exit-function "\\alpha" 1 7 "\\alpha" nil) "\\alpha"))
  (should (equal (julia--call-latexsub-exit-function "x\\alpha " 2 8 "\\alpha" nil)  "x\\alpha "))
  (should (equal (julia--call-latexsub-exit-function
                  "\\kappa\\alpha(" 7 13 "\\alpha" nil)
                 "\\kappa\\alpha(")))

;;; syntax-propertize-function tests

(ert-deftest julia--test-triple-quoted-string-syntax ()
  (with-temp-buffer
    (julia-mode)
    (insert "\"\"\"
hello world
\"\"\"")
    ;; If triple-quoted strings improperly syntax-propertized as 3
    ;; single-quoted strings, this will show string starting at pos 3
    ;; instead of 1.
    (should (= 1 (nth 8 (syntax-ppss 5))))))

(ert-deftest julia--test-triple-quoted-cmd-syntax ()
  (with-temp-buffer
    (julia-mode)
    (insert "```
hello world
```")
    (should (= 1 (nth 8 (syntax-ppss 5))))))

(ert-deftest julia--test-backslash-syntax ()
  (with-temp-buffer
    (julia-mode)
    (insert "1 \\ 2
\"hello\\nthere\"")
    (syntax-propertize 20)
    (should (equal
             (string-to-syntax ".")
             (syntax-after 3)))
    (should (equal
             (string-to-syntax "\\")
             (syntax-after 13)))))

;;; testing julia-latexsub-or-indent

(cl-defun julia-test-latexsub-or-indent (from &key (position (1+ (length from))) (greedy t))
  "Utility function to test `julia-latexsub-or-indent'.

This is how it works:

1. FROM is inserted in a buffer.

2. The point is moved to POSITION.

3. `julia-latexsub-or-indent' is called on the buffer.

If `julia-latexsub-selector' is called, it selects the first replacement, which is also placed in SELECTION (otherwise it is NIL).

Return a cons of the

1. buffer contents

2. the replacement of SELECTION when not nil.

The latter can be used to construct test comparisons."
  (let* ((selection)
         (julia-latexsub-selector
          (lambda (replacements)
            (setf selection (car replacements))
            selection))
         (julia-latexsub-greedy greedy))
    (cons (with-temp-buffer
            (insert from)
            (goto-char position)
            (julia-latexsub-or-indent t)
            (buffer-string))
          (gethash selection julia-mode-latexsubs))))

(ert-deftest julia--test-latexsub-or-indent ()
  (should (equal (julia-test-latexsub-or-indent "\\circ") '("∘")))
  (let ((result (julia-test-latexsub-or-indent "\\circXX" :position 5)))
    (should (equal (car result) (concat (cdr result) "cXX"))))
  (let ((result (julia-test-latexsub-or-indent "\\circ" :greedy nil)))
    (should (equal (car result) (cdr result))))
  (should (equal (julia-test-latexsub-or-indent "\\alpha") '("α"))))

;;;
;;; run all tests
;;;

(defun julia--run-tests ()
  (interactive)
  (if (featurep 'ert)
      (ert-run-tests-interactively "julia--test")
    (message "Can't run julia-mode-tests because ert is not available.")))

(provide 'julia-mode-tests)
;; Local Variables:
;; coding: utf-8
;; byte-compile-warnings: (not obsolete)
;; End:
;;; julia-mode-tests.el ends here
