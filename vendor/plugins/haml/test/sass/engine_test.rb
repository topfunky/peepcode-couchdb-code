#!/usr/bin/env ruby
require File.dirname(__FILE__) + '/../test_helper'
require 'sass/engine'

class SassEngineTest < Test::Unit::TestCase
  # A map of erroneous Sass documents to the error messages they should produce.
  # The error messages may be arrays;
  # if so, the second element should be the line number that should be reported for the error.
  # If this isn't provided, the tests will assume the line number should be the last line of the document.
  EXCEPTION_MAP = {
    "!a = 1 + " => 'Constant arithmetic error: "1 +".',
    "!a = 1 + 2 +" => 'Constant arithmetic error: "1 + 2 +".',
    "!a = \"b" => 'Unterminated string: "\\"b".',
    "!a = #aaa - a" => 'Undefined operation: "#aaaaaa minus a".',
    "!a = #aaa / a" => 'Undefined operation: "#aaaaaa div a".',
    "!a = #aaa * a" => 'Undefined operation: "#aaaaaa times a".',
    "!a = #aaa % a" => 'Undefined operation: "#aaaaaa mod a".',
    "!a = 1 - a" => 'Undefined operation: "1 minus a".',
    "!a = 1 * a" => 'Undefined operation: "1 times a".',
    "!a = 1 / a" => 'Undefined operation: "1 div a".',
    "!a = 1 % a" => 'Undefined operation: "1 mod a".',
    ":" => 'Invalid attribute: ":".',
    ": a" => 'Invalid attribute: ": a".',
    ":= a" => 'Invalid attribute: ":= a".',
    "a\n  :b" => 'Invalid attribute: ":b ".',
    "a\n  :b: c" => 'Invalid attribute: ":b: c".',
    "a\n  :b:c d" => 'Invalid attribute: ":b:c d".',
    "a\n  :b=c d" => 'Invalid attribute: ":b=c d".',
    "a\n  :b c;" => 'Invalid attribute: ":b c;" (This isn\'t CSS!).',
    "a\n  b : c" => 'Invalid attribute: "b : c".',
    "a\n  b=c: d" => 'Invalid attribute: "b=c: d".',
    ":a" => 'Attributes aren\'t allowed at the root of a document.',
    "!" => 'Invalid constant: "!".',
    "!a" => 'Invalid constant: "!a".',
    "! a" => 'Invalid constant: "! a".',
    "!a b" => 'Invalid constant: "!a b".',
    "a\n  :b c\n  !d = 3" => "Constants may only be declared at the root of a document.",
    "!a = 1b + 2c" => "Incompatible units: b and c.",
    "& a\n  :b c" => ["Base-level rules cannot contain the parent-selector-referencing character '&'.", 1],
    "a\n  :b\n    c" => "Illegal nesting: Only attributes may be nested beneath attributes.",
    "a,\n  :b c" => ["Rules can\'t end in commas.", 1],
    "a," => "Rules can\'t end in commas.",
    "a,\n!b = c" => ["Rules can\'t end in commas.", 1],
    "!a = b\n  :c d\n" => "Illegal nesting: Nothing may be nested beneath constants.",
    "@import foo.sass" => "File to import not found or unreadable: foo.sass.",
    "@import templates/basic\n  foo" => "Illegal nesting: Nothing may be nested beneath import directives.",
    "foo\n  @import templates/basic" => "Import directives may only be used at the root of a document.",
    "!foo = bar baz !" => "Unterminated constant.",
    "=foo\n  :color red\n.bar\n  +bang" => "Undefined mixin 'bang'.",
    ".bar\n  =foo\n    :color red\n" => ["Mixins may only be defined at the root of a document.", 2],
    "=foo\n  :color red\n.bar\n  +foo\n    :color red" => "Illegal nesting: Nothing may be nested beneath mixin directives.",
    "    a\n  b: c" => ["Indenting at the beginning of the document is illegal.", 1],
    " \n   \n\t\n  a\n  b: c" => ["Indenting at the beginning of the document is illegal.", 4],
    "a\n  b: c\n b: c" => ["Inconsistent indentation: 1 space was used for indentation, but the rest of the document was indented using 2 spaces.", 3],
    "a\n  b: c\na\n b: c" => ["Inconsistent indentation: 1 space was used for indentation, but the rest of the document was indented using 2 spaces.", 4],
    "a\n\t\tb: c\n\tb: c" => ["Inconsistent indentation: 1 tab was used for indentation, but the rest of the document was indented using 2 tabs.", 3],
    "a\n  b: c\n   b: c" => ["Inconsistent indentation: 3 spaces were used for indentation, but the rest of the document was indented using 2 spaces.", 3],
    "a\n  b: c\n  a\n   d: e" => ["Inconsistent indentation: 3 spaces were used for indentation, but the rest of the document was indented using 2 spaces.", 4],
    "a\n  b: c\na\n    d: e" => ["The line was indented 2 levels deeper than the previous line.", 4],
    "a\n  b: c\n  a\n        d: e" => ["The line was indented 3 levels deeper than the previous line.", 4],
    "a\n \tb: c" => ["Indentation can't use both tabs and spaces.", 2],
    "=a(" => 'Invalid mixin "a(".',
    "=a(b)" => 'Mixin argument "b" must begin with an exclamation point (!).',
    "=a(,)" => "Mixin arguments can't be empty.",
    "=a(!)" => "Mixin arguments can't be empty.",
    "=a(!foo bar)" => "Invalid constant \"!foo bar\".",
    "=foo\n  bar: baz\n+foo" => ["Attributes aren't allowed at the root of a document.", 2],
    "a-\#{!b\n  c: d" => ["Unbalanced brackets.", 1],
    "!a = 1 & 2" => "SassScript doesn't support a single-& operator.",
    "!a = 1 | 2" => "SassScript doesn't support a single-| operator.",
    "=a(!b = 1, !c)" => "Required arguments must not follow optional arguments \"!c\".",
    "=a(!b = 1)\n  :a= !b\ndiv\n  +a(1,2)" => "Mixin a takes 1 argument but 2 were passed.",
    "=a(!b)\n  :a= !b\ndiv\n  +a" => "Mixin a is missing parameter #1 (b).",

    # Regression tests
    "a\n  b:\n    c\n    d" => ["Illegal nesting: Only attributes may be nested beneath attributes.", 3],
    "& foo\n  bar: baz\n  blat: bang" => ["Base-level rules cannot contain the parent-selector-referencing character '&'.", 1],
    "a\n  b: c\n& foo\n  bar: baz\n  blat: bang" => ["Base-level rules cannot contain the parent-selector-referencing character '&'.", 3],
  }
  
  def test_basic_render
    renders_correctly "basic", { :style => :compact }
  end

  def test_multiple_calls_to_render
    sass = Sass::Engine.new("a\n  b: c")
    assert_equal sass.render, sass.render
  end

  def test_alternate_styles
    renders_correctly "expanded", { :style => :expanded }
    renders_correctly "compact", { :style => :compact }
    renders_correctly "nested", { :style => :nested }
    renders_correctly "compressed", { :style => :compressed }
  end
  
  def test_flexible_tabulation
    assert_equal("p {\n  a: b; }\n  p q {\n    c: d; }\n",
                 render("p\n a: b\n q\n  c: d\n"))
    assert_equal("p {\n  a: b; }\n  p q {\n    c: d; }\n",
                 render("p\n\ta: b\n\tq\n\t\tc: d\n"))
  end
  
  def test_exceptions
    EXCEPTION_MAP.each do |key, value|
      begin
        Sass::Engine.new(key).render
      rescue Sass::SyntaxError => err
        value = [value] unless value.is_a?(Array)

        assert_equal(value.first, err.message, "Line: #{key}")
        assert_equal(value[1] || key.split("\n").length, err.sass_line, "Line: #{key}")
        assert_match(/\(sass\):[0-9]+/, err.backtrace[0], "Line: #{key}")
      else
        assert(false, "Exception not raised for\n#{key}")
      end
    end
  end

  def test_exception_line
    to_render = "rule\n  :attr val\n// comment!\n\n  :broken\n"
    begin
      Sass::Engine.new(to_render).render
    rescue Sass::SyntaxError => err
      assert_equal(5, err.sass_line)
    else
      assert(false, "Exception not raised for '#{to_render}'!")
    end
  end

  def test_imported_exception
    [1, 2].each do |i|
      i = nil if i == 1
      begin
        Sass::Engine.new("@import bork#{i}", :load_paths => [File.dirname(__FILE__) + '/templates/']).render
      rescue Sass::SyntaxError => err
        assert_equal(2, err.sass_line)
        assert_match(/bork#{i}\.sass$/, err.sass_filename)
      else
        assert(false, "Exception not raised for imported template: bork#{i}")
      end
    end
  end

  def test_css_import
    assert_equal("@import url(./fonts.css) screen;", render("@import url(./fonts.css) screen"))
    assert_equal("@import \"./fonts.css\" screen;", render("@import \"./fonts.css\" screen"))
  end

  def test_sass_import
    renders_correctly "import", { :style => :compact, :load_paths => [File.dirname(__FILE__) + "/templates"] }
  end

  def test_default_function
    assert_equal("foo {\n  bar: url(foo.png); }\n", render("foo\n  bar = url(foo.png)\n"));
    assert_equal("foo {\n  bar: url(); }\n", render("foo\n  bar = url()\n"));
  end

  def test_string_minus
    assert_equal("foo {\n  bar: baz-boom-bat; }\n", render("foo\n  bar = baz-boom-bat"))
    assert_equal("foo {\n  bar: -baz-boom; }\n", render("foo\n  bar = -baz-boom"))
  end

  def test_string_div
    assert_equal("foo {\n  bar: baz/boom/bat; }\n", render("foo\n  bar = baz/boom/bat"))
    assert_equal("foo {\n  bar: /baz/boom; }\n", render("foo\n  bar = /baz/boom"))
  end

  def test_basic_multiline_selector
    assert_equal("#foo #bar,\n#baz #boom {\n  foo: bar; }\n",
                 render("#foo #bar,\n#baz #boom\n  :foo bar"))
    assert_equal("#foo #bar,\n#foo #baz {\n  foo: bar; }\n",
                 render("#foo\n  #bar,\n  #baz\n    :foo bar"))
    assert_equal("#foo,\n#bar {\n  foo: bar; }\n  #foo #baz,\n  #bar #baz {\n    foo: bar; }\n",
                 render("#foo,\n#bar\n  :foo bar\n  #baz\n    :foo bar"))
    assert_equal("#foo #bar, #baz #boom { foo: bar; }\n",
                 render("#foo #bar,\n#baz #boom\n  :foo bar", :style => :compact))
                 
    assert_equal("#foo #bar,#baz #boom{foo:bar}\n",
                 render("#foo #bar,\n#baz #boom\n  :foo bar", :style => :compressed))
  end

  def test_complex_multiline_selector
    renders_correctly "multiline"
  end

  def test_colon_only
    begin
      render("a\n  b: c", :attribute_syntax => :normal)
    rescue Sass::SyntaxError => e
      assert_equal("Illegal attribute syntax: can't use alternate syntax when :attribute_syntax => :normal is set.",
                   e.message)
    else
      assert(false, "SyntaxError not raised for :attribute_syntax => :normal")
    end

    begin
      render("a\n  :b c", :attribute_syntax => :alternate)
    rescue Sass::SyntaxError => e
      assert_equal("Illegal attribute syntax: can't use normal syntax when :attribute_syntax => :alternate is set.",
                   e.message)
    else
      assert(false, "SyntaxError not raised for :attribute_syntax => :alternate")
    end
  end

  def test_directive
    assert_equal("@a b;", render("@a b"))

    assert_equal("@a {\n  b: c; }\n", render("@a\n  :b c"))
    assert_equal("@a { b: c; }\n", render("@a\n  :b c", :style => :compact))
    assert_equal("@a {\n  b: c;\n}\n", render("@a\n  :b c", :style => :expanded))
    assert_equal("@a{b:c}\n", render("@a\n  :b c", :style => :compressed))

    assert_equal("@a {\n  b: c;\n  d: e; }\n",
                 render("@a\n  :b c\n  :d e"))
    assert_equal("@a { b: c; d: e; }\n",
                 render("@a\n  :b c\n  :d e", :style => :compact))
    assert_equal("@a {\n  b: c;\n  d: e;\n}\n",
                 render("@a\n  :b c\n  :d e", :style => :expanded))
    assert_equal("@a{b:c;d:e}\n",
                 render("@a\n  :b c\n  :d e", :style => :compressed))

    assert_equal("@a {\n  #b {\n    c: d; } }\n",
                 render("@a\n  #b\n    :c d"))
    assert_equal("@a { #b { c: d; } }\n",
                 render("@a\n  #b\n    :c d", :style => :compact))
    assert_equal("@a {\n  #b {\n    c: d;\n  }\n}\n",
                 render("@a\n  #b\n    :c d", :style => :expanded))
    assert_equal("@a{#b{c:d}}\n",
                 render("@a\n  #b\n    :c d", :style => :compressed))

    assert_equal("@a {\n  #b {\n    a: b; }\n    #b #c {\n      d: e; } }\n",
                 render("@a\n  #b\n    :a b\n    #c\n      :d e"))
    assert_equal("@a { #b { a: b; }\n  #b #c { d: e; } }\n",
                 render("@a\n  #b\n    :a b\n    #c\n      :d e", :style => :compact))
    assert_equal("@a {\n  #b {\n    a: b;\n  }\n  #b #c {\n    d: e;\n  }\n}\n",
                 render("@a\n  #b\n    :a b\n    #c\n      :d e", :style => :expanded))
    assert_equal("@a{#b{a:b}#b #c{d:e}}\n",
                 render("@a\n  #b\n    :a b\n    #c\n      :d e", :style => :compressed))
                 
    assert_equal("@a {\n  #foo,\n  #bar {\n    b: c; } }\n",
                 render("@a\n  #foo, \n  #bar\n    :b c"))
    assert_equal("@a { #foo, #bar { b: c; } }\n",
                 render("@a\n  #foo, \n  #bar\n    :b c", :style => :compact))
    assert_equal("@a {\n  #foo,\n  #bar {\n    b: c;\n  }\n}\n",
                 render("@a\n  #foo, \n  #bar\n    :b c", :style => :expanded))
    assert_equal("@a{#foo,#bar{b:c}}\n",
                 render("@a\n  #foo, \n  #bar\n    :b c", :style => :compressed))

    to_render = <<END
@a
  :b c
  #d
    :e f
  :g h
END
    rendered = <<END
@a { b: c;
  #d { e: f; }
  g: h; }
END
    assert_equal(rendered, render(to_render, :style => :compact))
    
    assert_equal("@a{b:c;#d{e:f}g:h}\n", render(to_render, :style => :compressed))
  end

  def test_line_annotations
    assert_equal(<<CSS, render(<<SASS, :line_comments => true, :style => :compact))
/* line 2 */
foo bar { foo: bar; }
/* line 5 */
foo baz { blip: blop; }

/* line 9 */
floodle { flop: blop; }

/* line 18 */
bup { mix: on; }
/* line 15 */
bup mixin { moop: mup; }

/* line 22 */
bip hop, skip hop { a: b; }
CSS
foo
  bar
    foo: bar

  baz
    blip: blop


floodle

  flop: blop

=mxn
  mix: on
  mixin
    moop: mup

bup
  +mxn

bip, skip
  hop
    a: b
SASS
  end

  def test_line_annotations_with_filename
    renders_correctly "line_numbers", :line_comments => true, :load_paths => [File.dirname(__FILE__) + "/templates"]
  end

  def test_empty_first_line
    assert_equal("#a {\n  b: c; }\n", render("#a\n\n  b: c"))
  end

  def test_escaped_rule
    assert_equal(":focus {\n  a: b; }\n", render("\\:focus\n  a: b"))
    assert_equal("a {\n  b: c; }\n  a :focus {\n    d: e; }\n", render("\\a\n  b: c\n  \\:focus\n    d: e"))
  end

  def test_cr_newline
    assert_equal("foo {\n  a: b;\n  c: d;\n  e: f; }\n", render("foo\r  a: b\r\n  c: d\n\r  e: f"))
  end

  def test_or_eq
    assert_equal("foo {\n  a: b; }\n", render("!foo = b\n!foo ||= c\nfoo\n  a = !foo"))
    assert_equal("foo {\n  a: b; }\n", render("!foo ||= b\nfoo\n  a = !foo"))
  end
  
  def test_mixins
    renders_correctly "mixins", { :style => :expanded }
  end

  def test_mixins_dont_interfere_with_sibling_combinator
    assert_equal("foo + bar {\n  a: b; }\n", render("foo\n  + bar\n    a: b"))
    assert_equal("foo + bar {\n  a: b; }\nfoo + baz {\n  c: d; }\n",
                 render("foo\n  +\n    bar\n      a: b\n    baz\n      c: d"))
  end

  def test_mixin_args
    assert_equal("blat {\n  baz: hi; }\n", render(<<SASS))
=foo(!bar)
  baz = !bar
blat
  +foo(\"hi\")
SASS
    assert_equal("blat {\n  baz: 3; }\n", render(<<SASS))
=foo(!a, !b)
  baz = !a + !b
blat
  +foo(1, 2)
SASS
    assert_equal("blat {\n  baz: 4;\n  bang: 3; }\n", render(<<SASS))
=foo(!c)
  baz = !c
!c = 3
blat
  +foo(!c + 1)
  bang = !c
SASS
  end

  def test_default_values_for_mixin_arguments
    assert_equal("white {\n  color: #ffffff; }\n\nblack {\n  color: #000000; }\n", render(<<SASS))
=foo(!a = #FFF)
  :color= !a
white
  +foo
black
  +foo(#000)
SASS
    assert_equal(<<CSS, render(<<SASS))
one {
  color: #ffffff;
  padding: 1px;
  margin: 8px; }

two {
  color: #ffffff;
  padding: 2px;
  margin: 8px; }

three {
  color: #ffffff;
  padding: 2px;
  margin: 3px; }
CSS
!a = 5px
=foo(!a, !b = 1px, !c = 3px + !a)
  :color= !a
  :padding= !b
  :margin= !c
one
  +foo(#fff)
two
  +foo(#fff, 2px)
three
  +foo(#fff, 2px, 3px)
SASS
  end

  def test_interpolation
    assert_equal("a-1 {\n  b-2: c-3; }\n", render(<<SASS))
!a = 1
!b = 2
a-\#{!a}
  b-\#{!b}: c-\#{!a + !b}
SASS
  end

  def test_booleans
    assert_equal(<<CSS, render(<<SASS))
a {
  b: true;
  c: false;
  t1: true;
  t2: true;
  t3: true;
  t4: true;
  f1: false;
  f2: false;
  f3: false;
  f4: false; }
CSS
a
  b = true
  c = false
  t1 = true && true
  t2 = false || true
  t3 = true || false
  t4 = true || true
  f1 = false || false
  f2 = false && true
  f3 = true && false
  f4 = false && false
SASS
    assert_equal(<<CSS, render(<<SASS))
a {
  b: true;
  c: false; }
CSS
!var = true
a
  b = !!!var
  c = !!var
SASS
  end

  def test_boolean_ops
    assert_equal("a {\n  b: 1;\n  c: 2;\n  d: 3; }\n", render(<<SASS))
a
  b = false || 1
  c = 2 || 3
  d = 2 && 3
SASS
  end

  def test_functions
    assert_equal("a {\n  b: #80ff80; }\n", render("a\n  b = hsl(120, 100%, 75%)"))
    assert_equal("a {\n  b: #81ff81; }\n", render("a\n  b = hsl(120, 100%, 75%) + #010001"))
  end

  def test_if_directive
    assert_equal("a {\n  b: 1; }\n", render(<<SASS))
!var = true
a
  @if !var
    b: 1
  @if !!var
    b: 2
SASS
  end

  def test_equals
    assert_equal(<<CSS, render(<<SASS))
a {
  t1: true;
  t2: true;
  t3: true;
  f1: false;
  f2: false;
  f3: false; }
CSS
a
  t1 = "foo" == foo
  t2 = 1 == 1.0
  t3 = false != true
  f1 = foo == bar
  f2 = 1em == 1px
  f3 = 12 != 12
SASS
  end

  def test_for
    assert_equal(<<CSS, render(<<SASS))
a-0 {
  2i: 0; }

a-1 {
  2i: 2; }

a-2 {
  2i: 4; }

a-3 {
  2i: 6; }

b-1 {
  j-1: 0; }

b-2 {
  j-1: 1; }

b-3 {
  j-1: 2; }

b-4 {
  j-1: 3; }
CSS
!a = 3
@for !i from 0 to !a + 1
  a-\#{!i}
    2i = 2 * !i

@for !j from 1 through 4
  b-\#{!j}
    j-1 = !j - 1
SASS
  end

  def test_while
    assert_equal(<<CSS, render(<<SASS))
a-5 {
  blooble: gloop; }

a-4 {
  blooble: gloop; }

a-3 {
  blooble: gloop; }

a-2 {
  blooble: gloop; }

a-1 {
  blooble: gloop; }
CSS
!a = 5
@while !a != 0
  a-\#{!a}
    blooble: gloop
  !a = !a - 1
SASS
  end

  def test_argument_error
    assert_raise(Sass::SyntaxError) { render("a\n  b = hsl(1)") }
  end

  def test_inaccessible_functions
    assert_equal("a {\n  b: send(to_s); }\n", render("a\n  b = send(to_s)"))
    assert_equal("a {\n  b: public_instance_methods(); }\n", render("a\n  b = public_instance_methods()"))
  end

  private

  def render(sass, options = {})
    Sass::Engine.new(sass, options).render
  end

  def renders_correctly(name, options={})
    sass_file  = load_file(name, "sass")
    css_file   = load_file(name, "css")
    options[:filename] ||= filename(name, "sass")
    options[:css_filename] ||= filename(name, "css")
    css_result = Sass::Engine.new(sass_file, options).render
    assert_equal css_file, css_result
  end

  def load_file(name, type = "sass")
    @result = ''
    File.new(filename(name, type)).each_line { |l| @result += l }
    @result
  end

  def filename(name, type)
    File.dirname(__FILE__) + "/#{type == 'sass' ? 'templates' : 'results'}/#{name}.#{type}"
  end
end
