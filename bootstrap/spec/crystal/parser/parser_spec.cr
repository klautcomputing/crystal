#!/usr/bin/env bin/crystal -run
require "../../spec_helper"

class Number
  def int32
    NumberLiteral.new to_s, :i32
  end

  def int64
    NumberLiteral.new to_s, :i64
  end

  def float32
    NumberLiteral.new to_f32.to_s, :f32
  end

  def float64
    NumberLiteral.new to_f64.to_s, :f64
  end
end

class Bool
  def bool
    BoolLiteral.new self
  end
end

class Array
  def array
    ArrayLiteral.new self
  end

  def array_of(type)
    ArrayLiteral.new self, type
  end

  def ident
    Ident.new self
  end
end

class String
  def var
    Var.new self
  end

  def arg
    Arg.new self
  end

  def call
    Call.new nil, self
  end

  def call(args)
    Call.new nil, self, args
  end

  def ident(global = false)
    Ident.new [self], global
  end

  def instance_var
    InstanceVar.new self
  end

  def string
    StringLiteral.new self
  end

  def float32
    NumberLiteral.new self, :f32
  end

  def float64
    NumberLiteral.new self, :f64
  end

  def symbol
    Crystal::SymbolLiteral.new self
  end
end

def it_parses(string, expected_node)
  it "parses #{string}" do
    node = Parser.parse(string)
    node.should eq(Expressions.from expected_node)
  end
end

include Crystal

describe "Parser" do
  it_parses "nil", NilLiteral.new

  it_parses "true", true.bool
  it_parses "false", false.bool

  it_parses "1", 1.int32
  it_parses "+1", 1.int32
  it_parses "-1", -1.int32

  it_parses "1_i64", 1.int64
  it_parses "+1_i64", 1.int64
  it_parses "-1_i64", -1.int64

  it_parses "1.0", 1.0.float64
  it_parses "+1.0", 1.0.float64
  it_parses "-1.0", -1.0.float64

  it_parses "1.0_f32", "1.0".float32
  it_parses "+1.0_f32", "+1.0".float32
  it_parses "-1.0_f32", "-1.0".float32

  it_parses "2.3_f32", 2.3.float32

  it_parses "'a'", CharLiteral.new("a")

  it_parses %("foo"), StringLiteral.new("foo")
  it_parses %(""), StringLiteral.new("")

  it_parses ":foo", SymbolLiteral.new("foo")

  it_parses "[1, 2]", ([1.int32, 2.int32] of ASTNode).array
  it_parses "[\n1, 2]", ([1.int32, 2.int32] of ASTNode).array
  it_parses "[1,\n 2,]", ([1.int32, 2.int32] of ASTNode).array

  it_parses "1 + 2", Call.new(1.int32, "+", [2.int32] of ASTNode)
  it_parses "1 +\n2", Call.new(1.int32, "+", [2.int32] of ASTNode)
  it_parses "1 +2", Call.new(1.int32, "+", [2.int32] of ASTNode)
  it_parses "1 -2", Call.new(1.int32, "-", [2.int32] of ASTNode)
  it_parses "1 +2.0", Call.new(1.int32, "+", [2.float64] of ASTNode)
  it_parses "1 -2.0", Call.new(1.int32, "-", [2.float64] of ASTNode)
  it_parses "1 +2_i64", Call.new(1.int32, "+", [2.int64] of ASTNode)
  it_parses "1 -2_i64", Call.new(1.int32, "-", [2.int64] of ASTNode)
  it_parses "1\n+2", [1.int32, 2.int32] of ASTNode
  it_parses "1;+2", [1.int32, 2.int32] of ASTNode
  it_parses "1 - 2", Call.new(1.int32, "-", [2.int32] of ASTNode)
  it_parses "1 -\n2", Call.new(1.int32, "-", [2.int32] of ASTNode)
  it_parses "1\n-2", [1.int32, -2.int32] of ASTNode
  it_parses "1;-2", [1.int32, -2.int32] of ASTNode
  it_parses "1 * 2", Call.new(1.int32, "*", [2.int32] of ASTNode)
  it_parses "1 * -2", Call.new(1.int32, "*", [-2.int32] of ASTNode)
  it_parses "2 * 3 + 4 * 5", Call.new(Call.new(2.int32, "*", [3.int32] of ASTNode), "+", [Call.new(4.int32, "*", [5.int32] of ASTNode)] of ASTNode)
  it_parses "1 / 2", Call.new(1.int32, "/", [2.int32] of ASTNode)
  it_parses "1 / -2", Call.new(1.int32, "/", [-2.int32] of ASTNode)
  it_parses "2 / 3 + 4 / 5", Call.new(Call.new(2.int32, "/", [3.int32] of ASTNode), "+", [Call.new(4.int32, "/", [5.int32] of ASTNode)] of ASTNode)
  it_parses "2 * (3 + 4)", Call.new(2.int32, "*", [Call.new(3.int32, "+", [4.int32] of ASTNode)] of ASTNode)

  it_parses "!1", Call.new(1.int32, "!@")
  it_parses "1 && 2", And.new(1.int32, 2.int32)
  it_parses "1 || 2", Or.new(1.int32, 2.int32)

  it_parses "1 <=> 2", Call.new(1.int32, "<=>", [2.int32] of ASTNode)

  it_parses "a = 1", Assign.new("a".var, 1.int32)
  it_parses "a = b = 2", Assign.new("a".var, Assign.new("b".var, 2.int32))

  it_parses "a, b = 1, 2", MultiAssign.new(["a".var, "b".var], [1.int32, 2.int32])
  it_parses "a, b = 1", MultiAssign.new(["a".var, "b".var], [1.int32])

  it_parses "def foo\n1\nend", Def.new("foo", [] of Arg, [1.int32] of ASTNode)
  it_parses "def downto(n)\n1\nend", Def.new("downto", ["n".arg], [1.int32] of ASTNode)
  it_parses "def foo ; 1 ; end", Def.new("foo", [] of Arg, [1.int32] of ASTNode)
  it_parses "def foo; end", Def.new("foo", [] of Arg, nil)
  it_parses "def foo(var); end", Def.new("foo", ["var".arg], nil)
  it_parses "def foo(\nvar); end", Def.new("foo", ["var".arg], nil)
  it_parses "def foo(\nvar\n); end", Def.new("foo", ["var".arg], nil)
  it_parses "def foo(var1, var2); end", Def.new("foo", ["var1".arg, "var2".arg], nil)
  it_parses "def foo(\nvar1\n,\nvar2\n)\n end", Def.new("foo", ["var1".arg, "var2".arg], nil)
  it_parses "def foo var; end", Def.new("foo", ["var".arg], nil)
  it_parses "def foo var\n end", Def.new("foo", ["var".arg], nil)
  it_parses "def foo var1, var2\n end", Def.new("foo", ["var1".arg, "var2".arg], nil)
  it_parses "def foo var1,\nvar2\n end", Def.new("foo", ["var1".arg, "var2".arg], nil)
  it_parses "def foo; 1; 2; end", Def.new("foo", [] of Arg, [1.int32, 2.int32] of ASTNode)
  it_parses "def foo=(value); end", Def.new("foo=", ["value".arg], [] of ASTNode)
  it_parses "def foo(n); foo(n -1); end", Def.new("foo", ["n".arg], "foo".call([Call.new("n".var, "-", [1.int32] of ASTNode)] of ASTNode))
  it_parses "def type(type); end", Def.new("type", ["type".arg], nil)

  it_parses "def self.foo\n1\nend", Def.new("foo", [] of Arg, 1.int32, "self".var)
  it_parses "def Foo.foo\n1\nend", Def.new("foo", [] of Arg, 1.int32, "Foo".ident)
  it_parses "def Foo::Bar.foo\n1\nend", Def.new("foo", [] of Arg, 1.int32, ["Foo", "Bar"].ident)

  it_parses "def foo; a; end", Def.new("foo", [] of Arg, "a".call)
  it_parses "def foo(a); a; end", Def.new("foo", ["a".arg], "a".var)
  it_parses "def foo; a = 1; a; end", Def.new("foo", [] of Arg, [Assign.new("a".var, 1.int32), "a".var])
  it_parses "def foo; a = 1; a {}; end", Def.new("foo", [] of Arg, [Assign.new("a".var, 1.int32), Call.new(nil, "a", [] of ASTNode, Block.new)])
  it_parses "def foo; a = 1; x { a }; end", Def.new("foo", [] of Arg, [Assign.new("a".var, 1.int32), Call.new(nil, "x", [] of ASTNode, Block.new([] of ASTNode, ["a".var]))])
  it_parses "def foo; x { |a| a }; end", Def.new("foo", [] of Arg, [Call.new(nil, "x", [] of ASTNode, Block.new(["a".var] of ASTNode, ["a".var] of ASTNode))])

  it_parses "def foo(var = 1); end", Def.new("foo", [Arg.new("var", 1.int32)], nil)
  it_parses "def foo var = 1; end", Def.new("foo", [Arg.new("var", 1.int32)], nil)
  it_parses "def foo(var : Int); end", Def.new("foo", [Arg.new("var", nil, "Int".ident)], nil)
  it_parses "def foo var : Int; end", Def.new("foo", [Arg.new("var", nil, "Int".ident)], nil)
  it_parses "def foo(var : self); end", Def.new("foo", [Arg.new("var", nil, SelfType.new)], nil)
  it_parses "def foo var : self; end", Def.new("foo", [Arg.new("var", nil, SelfType.new)], nil)
  it_parses "def foo(var : Int | Double); end", Def.new("foo", [Arg.new("var", nil, IdentUnion.new(["Int".ident, "Double".ident]))], nil)
  it_parses "def foo(var : Int?); end", Def.new("foo", [Arg.new("var", nil, IdentUnion.new(["Int".ident, "Nil".ident(true)]))], nil)
  it_parses "def foo; yield; end", Def.new("foo", [] of Arg, [Yield.new], nil, nil, 0)
  it_parses "def foo; yield 1; end", Def.new("foo", [] of Arg, [Yield.new([1.int32])], nil, nil, 1)
  it_parses "def foo; yield 1; yield; end", Def.new("foo", [] of Arg, [Yield.new([1.int32]), Yield.new], nil, nil, 1)
  it_parses "def foo(a, b = a); end", Def.new("foo", [Arg.new("a"), Arg.new("b", "a".var)], nil)
  it_parses "def foo(a, &block); end", Def.new("foo", [Arg.new("a")], nil, nil, BlockArg.new("block"))
  it_parses "def foo(a, &block : Int -> Double); end", Def.new("foo", [Arg.new("a")], nil, nil, BlockArg.new("block", ["Int".ident], "Double".ident))
  it_parses "def foo(a, &block : Int, Float -> Double); end", Def.new("foo", [Arg.new("a")], nil, nil, BlockArg.new("block", ["Int".ident, "Float".ident], "Double".ident))
  it_parses "def foo(a, &block : -> Double); end", Def.new("foo", [Arg.new("a")], nil, nil, BlockArg.new("block", nil, "Double".ident))
  it_parses "def foo(a, &block : Int -> ); end", Def.new("foo", [Arg.new("a")], nil, nil, BlockArg.new("block", ["Int".ident]))
  it_parses "def foo(a, &block : self -> self); end", Def.new("foo", [Arg.new("a")], nil, nil, BlockArg.new("block", [SelfType.new], SelfType.new))
  # it_parses "def foo; a.yield; end", Def.new("foo", [], [YieldWithScope.new("a".call)], nil, nil, 1)
  # it_parses "def foo; a.yield 1; end", Def.new("foo", [], [YieldWithScope.new("a".call, [1.int32])], nil, nil, 1)

  it_parses "foo", "foo".call
  it_parses "foo()", "foo".call
  it_parses "foo(1)", "foo".call([1.int32] of ASTNode)
  it_parses "foo 1", "foo".call([1.int32] of ASTNode)
  it_parses "foo 1\n", "foo".call([1.int32] of ASTNode)
  it_parses "foo 1;", "foo".call([1.int32] of ASTNode)
  it_parses "foo 1, 2", "foo".call([1.int32, 2.int32] of ASTNode)
  it_parses "foo (1 + 2), 3", "foo".call([Call.new(1.int32, "+", [2.int32] of ASTNode), 3.int32] of ASTNode)
  it_parses "foo(1 + 2)", "foo".call([Call.new(1.int32, "+", [2.int32] of ASTNode)] of ASTNode)
  it_parses "foo -1.0, -2.0", "foo".call([-1.float64, -2.float64] of ASTNode)
  it_parses "foo(\n1)", "foo".call([1.int32] of ASTNode)

  it_parses "foo + 1", Call.new("foo".call, "+", [1.int32] of ASTNode)
  it_parses "foo +1", Call.new(nil, "foo", [1.int32] of ASTNode)
  it_parses "foo +1.0", Call.new(nil, "foo", [1.float64] of ASTNode)
  it_parses "foo +1_i64", Call.new(nil, "foo", [1.int64] of ASTNode)
  it_parses "foo = 1; foo +1", [Assign.new("foo".var, 1.int32), Call.new("foo".var, "+", [1.int32] of ASTNode)]
  it_parses "foo = 1; foo -1", [Assign.new("foo".var, 1.int32), Call.new("foo".var, "-", [1.int32] of ASTNode)]

  it_parses "foo !false", Call.new(nil, "foo", [Call.new(false.bool, "!@")] of ASTNode)
  it_parses "!a && b", And.new(Call.new("a".call, "!@"), "b".call)

  it_parses "foo.bar.baz", Call.new(Call.new("foo".call, "bar"), "baz")
  it_parses "f.x Foo.new", Call.new("f".call, "x", [Call.new("Foo".ident, "new")] of ASTNode)
  it_parses "f.x = Foo.new", Call.new("f".call, "x=", [Call.new("Foo".ident, "new")] of ASTNode)
  it_parses "f.x = - 1", Call.new("f".call, "x=", [Call.new(1.int32, "-@")] of ASTNode)

  ["+", "-", "*", "/", "%", "|", "&", "^", "**", "<<", ">>"].each do |op|
    it_parses "f.x #{op}= 2", Call.new("f".call, "x=", [Call.new(Call.new("f".call, "x"), op, [2.int32] of ASTNode)] of ASTNode)
  end

  ["/", "<", "<=", "==", "!=", ">", ">=", "+", "-", "*", "/", "%", "&", "|", "^", "**", "+@", "-@", "~@", "!@", "==="].each do |op|
    it_parses "def #{op}; end;", Def.new(op, [] of Arg, nil)
  end

  ["<<", "<", "<=", "==", ">>", ">", ">=", "+", "-", "*", "/", "%", "|", "&", "^", "**", "==="].each do |op|
    it_parses "1 #{op} 2", Call.new(1.int32, op, [2.int32] of ASTNode)
    it_parses "n #{op} 2", Call.new("n".call, op, [2.int32] of ASTNode)
  end

  ["bar", "+", "-", "*", "/", "<", "<=", "==", ">", ">=", "%", "|", "&", "^", "**", "==="].each do |name|
    it_parses "foo.#{name}", Call.new("foo".call, name)
    it_parses "foo.#{name} 1, 2", Call.new("foo".call, name, [1.int32, 2.int32] of ASTNode)
  end

  ["+", "-", "*", "/", "%", "|", "&", "^", "**", "<<", ">>"].each do |op|
    it_parses "a = 1; a #{op}= 1", [Assign.new("a".var, 1.int32), Assign.new("a".var, Call.new("a".var, op, [1.int32] of ASTNode))]
  end

  it_parses "a = 1; a &&= 1", [Assign.new("a".var, 1.int32), And.new("a".var, Assign.new("a".var, 1.int32))]
  it_parses "a = 1; a ||= 1", [Assign.new("a".var, 1.int32), Or.new("a".var, Assign.new("a".var, 1.int32))]

  it_parses "if foo; 1; end", If.new("foo".call, 1.int32)
  it_parses "if foo\n1\nend", If.new("foo".call, 1.int32)
  it_parses "if foo; 1; else; 2; end", If.new("foo".call, 1.int32, 2.int32)
  it_parses "if foo\n1\nelse\n2\nend", If.new("foo".call, 1.int32, 2.int32)
  it_parses "if foo; 1; elsif bar; 2; else 3; end", If.new("foo".call, 1.int32, If.new("bar".call, 2.int32, 3.int32))

  it_parses "include Foo", Include.new("Foo".ident)
  it_parses "include Foo\nif true; end", [Include.new("Foo".ident), If.new(true.bool)]

  it_parses "unless foo; 1; end", Unless.new("foo".call, 1.int32)
  it_parses "unless foo; 1; else; 2; end", Unless.new("foo".call, 1.int32, 2.int32)

  it_parses "class Foo; end", ClassDef.new("Foo".ident)
  it_parses "class Foo\nend", ClassDef.new("Foo".ident)
  it_parses "class Foo\ndef foo; end; end", ClassDef.new("Foo".ident, [Def.new("foo", [] of Arg, nil)])
  it_parses "class Foo < Bar; end", ClassDef.new("Foo".ident, nil, "Bar".ident)
  it_parses "class Foo(T); end", ClassDef.new("Foo".ident, nil, nil, ["T"])
  it_parses "abstract class Foo; end", ClassDef.new("Foo".ident, nil, nil, nil, true)

  it_parses "Foo(T)", NewGenericClass.new("Foo".ident, ["T".ident])
  it_parses "Foo(T | U)", NewGenericClass.new("Foo".ident, [IdentUnion.new(["T".ident, "U".ident])])
  it_parses "Foo(Bar(T | U))", NewGenericClass.new("Foo".ident, [NewGenericClass.new("Bar".ident, [IdentUnion.new(["T".ident, "U".ident])])])
  it_parses "Foo(T?)", NewGenericClass.new("Foo".ident, [IdentUnion.new(["T".ident, Ident.new(["Nil"], true)])])

  it_parses "module Foo; end", ModuleDef.new("Foo".ident)
  it_parses "module Foo\ndef foo; end; end", ModuleDef.new("Foo".ident, [Def.new("foo", [] of Arg, nil)])
  it_parses "module Foo(T); end", ModuleDef.new("Foo".ident, nil, ["T"])

  it_parses "while true; end;", While.new(true.bool)
  it_parses "while true; 1; end;", While.new(true.bool, 1.int32)

  it_parses "foo do; 1; end", Call.new(nil, "foo", [] of ASTNode, Block.new([] of ASTNode, 1.int32))
  it_parses "foo do |a|; 1; end", Call.new(nil, "foo", [] of ASTNode, Block.new(["a".var], 1.int32))

  it_parses "foo { 1 }", Call.new(nil, "foo", [] of ASTNode, Block.new([] of ASTNode, 1.int32))
  it_parses "foo { |a| 1 }", Call.new(nil, "foo", [] of ASTNode, Block.new(["a".var], 1.int32))
  it_parses "foo { |a, b| 1 }", Call.new(nil, "foo", [] of ASTNode, Block.new(["a".var, "b".var], 1.int32))
  it_parses "1.foo do; 1; end", Call.new(1.int32, "foo", [] of ASTNode, Block.new([] of ASTNode, 1.int32))

  it_parses "1 ? 2 : 3", If.new(1.int32, 2.int32, 3.int32)
  it_parses "1 ? a : b", If.new(1.int32, "a".call, "b".call)

  it_parses "1 if 3", If.new(3.int32, 1.int32)
  it_parses "1 unless 3", Unless.new(3.int32, 1.int32)
  it_parses "1 while 3", While.new(3.int32, 1.int32, true)
  it_parses "a = 1; a += 10 if a += 20", [Assign.new("a".var, 1.int32), If.new(Assign.new("a".var, Call.new("a".var, "+", [20.int32] of ASTNode)), Assign.new("a".var, Call.new("a".var, "+", [10.int32] of ASTNode)))]
  it_parses "puts a if true", If.new(true.bool, Call.new(nil, "puts", ["a".call] of ASTNode))
  it_parses "puts a unless true", Unless.new(true.bool, Call.new(nil, "puts", ["a".call] of ASTNode))
  it_parses "puts a while true", While.new(true.bool, Call.new(nil, "puts", ["a".call] of ASTNode), true)

  it_parses "return", Return.new
  it_parses "return;", Return.new
  it_parses "return 1", Return.new([1.int32])
  it_parses "return 1 if true", If.new(true.bool, Return.new([1.int32]))
  it_parses "return if true", If.new(true.bool, Return.new)

  it_parses "break", Break.new
  it_parses "break;", Break.new
  it_parses "break 1", Break.new([1.int32])
  it_parses "break 1 if true", If.new(true.bool, Break.new([1.int32]))
  it_parses "break if true", If.new(true.bool, Break.new)

  it_parses "next", Next.new
  it_parses "next;", Next.new
  it_parses "next 1", Next.new([1.int32])
  it_parses "next 1 if true", If.new(true.bool, Next.new([1.int32]))
  it_parses "next if true", If.new(true.bool, Next.new)

  it_parses "yield", Yield.new
  it_parses "yield;", Yield.new
  it_parses "yield 1", Yield.new([1.int32])
  it_parses "yield 1 if true", If.new(true.bool, Yield.new([1.int32]))
  it_parses "yield if true", If.new(true.bool, Yield.new)

  it_parses "Int", "Int".ident

  it_parses "Int[]", Call.new("Int".ident, "[]")
  it_parses "def []; end", Def.new("[]", [] of Arg, nil)
  it_parses "def []=(value); end", Def.new("[]=", ["value".arg], nil)
  it_parses "def self.[]; end", Def.new("[]", [] of Arg, nil, "self".var)

  it_parses "Int[8]", Call.new("Int".ident, "[]", [8.int32] of ASTNode)
  it_parses "Int[8, 4]", Call.new("Int".ident, "[]", [8.int32, 4.int32] of ASTNode)
  it_parses "Int[8, 4,]", Call.new("Int".ident, "[]", [8.int32, 4.int32] of ASTNode)

  it_parses "def [](x); end", Def.new("[]", ["x".arg], nil)

  it_parses "foo[0] = 1", Call.new("foo".call, "[]=", [0.int32, 1.int32] of ASTNode)

  it_parses "begin; 1; 2; 3; end;", Expressions.new([1.int32, 2.int32, 3.int32])

  it_parses "self", "self".var

  it_parses "@foo", "@foo".instance_var
  it_parses "@foo = 1", Assign.new("@foo".instance_var, 1.int32)

  it_parses "call @foo.bar", Call.new(nil, "call", [Call.new("@foo".instance_var, "bar")] of ASTNode)
  it_parses "call \"foo\"", Call.new(nil, "call", ["foo".string] of ASTNode)

  it_parses "def foo; end; if false; 1; else; 2; end", [Def.new("foo", [] of Arg), If.new(false.bool, 1.int32, 2.int32)]

  it_parses "A.new(\"x\", B.new(\"y\"))", Call.new("A".ident, "new", ["x".string, Call.new("B".ident, "new", ["y".string] of ASTNode)] of ASTNode)

  it_parses "foo [1]", Call.new(nil, "foo", [([1.int32] of ASTNode).array] of ASTNode)
  it_parses "foo.bar [1]", Call.new("foo".call, "bar", [([1.int32] of ASTNode).array] of ASTNode)

  it_parses "class Foo; end\nwhile true; end", [ClassDef.new("Foo".ident), While.new(true.bool)]
  it_parses "while true; end\nif true; end", [While.new(true.bool), If.new(true.bool)]
  it_parses "(1)\nif true; end", [1.int32, If.new(true.bool)]
  it_parses "begin\n1\nend\nif true; end", [1.int32, If.new(true.bool)]

  it_parses "Foo::Bar", ["Foo", "Bar"].ident

  it_parses "lib C\nend", LibDef.new("C")
  it_parses "lib C(\"libc\")\nend", LibDef.new("C", "libc")
  it_parses "lib C\nfun getchar\nend", LibDef.new("C", nil, [FunDef.new("getchar")])
  it_parses "lib C\nfun getchar(...)\nend", LibDef.new("C", nil, [FunDef.new("getchar", [] of ASTNode, nil, 0, true)])
  it_parses "lib C\nfun getchar : Int\nend", LibDef.new("C", nil, [FunDef.new("getchar", [] of ASTNode, "Int".ident)])
  it_parses "lib C\nfun getchar(a : Int, b : Float)\nend", LibDef.new("C", nil, [FunDef.new("getchar", [FunDefArg.new("a", "Int".ident), FunDefArg.new("b", "Float".ident)])])
  it_parses "lib C\nfun getchar(a : Int)\nend", LibDef.new("C", nil, [FunDef.new("getchar", [FunDefArg.new("a", "Int".ident, 0)])])
  it_parses "lib C\nfun getchar(a : Int, b : Float) : Int\nend", LibDef.new("C", nil, [FunDef.new("getchar", [FunDefArg.new("a", "Int".ident), FunDefArg.new("b", "Float".ident)], "Int".ident)])
  it_parses "lib C; fun getchar(a : Int, b : Float) : Int; end", LibDef.new("C", nil, [FunDef.new("getchar", [FunDefArg.new("a", "Int".ident), FunDefArg.new("b", "Float".ident)], "Int".ident)])
  it_parses "lib C; fun foo(a : Int*); end", LibDef.new("C", nil, [FunDef.new("foo", [FunDefArg.new("a", "Int".ident, 1)])])
  it_parses "lib C; fun foo(a : Int**); end", LibDef.new("C", nil, [FunDef.new("foo", [FunDefArg.new("a", "Int".ident, 2)])])
  it_parses "lib C; fun foo : Int*; end", LibDef.new("C", nil, [FunDef.new("foo", [] of ASTNode, "Int".ident, 1)])
  it_parses "lib C; fun foo : Int**; end", LibDef.new("C", nil, [FunDef.new("foo", [] of ASTNode, "Int".ident, 2)])
  it_parses "lib C; type A : B; end", LibDef.new("C", nil, [TypeDef.new("A", "B".ident)])
  it_parses "lib C; type A : B*; end", LibDef.new("C", nil, [TypeDef.new("A", "B".ident, 1)])
  it_parses "lib C; type A : B**; end", LibDef.new("C", nil, [TypeDef.new("A", "B".ident, 2)])
  it_parses "lib C; struct Foo; end end", LibDef.new("C", nil, [StructDef.new("Foo")])
  it_parses "lib C; struct Foo; x : Int; y : Float; end end", LibDef.new("C", nil, [StructDef.new("Foo", [FunDefArg.new("x", "Int".ident), FunDefArg.new("y", "Float".ident)])])
  it_parses "lib C; struct Foo; x : Int*; end end", LibDef.new("C", nil, [StructDef.new("Foo", [FunDefArg.new("x", "Int".ident, 1)])])
  it_parses "lib C; struct Foo; x : Int**; end end", LibDef.new("C", nil, [StructDef.new("Foo", [FunDefArg.new("x", "Int".ident, 2)])])
  it_parses "lib C; struct Foo; x, y, z : Int; end end", LibDef.new("C", nil, [StructDef.new("Foo", [FunDefArg.new("x", "Int".ident), FunDefArg.new("y", "Int".ident), FunDefArg.new("z", "Int".ident)])])
  it_parses "lib C; union Foo; end end", LibDef.new("C", nil, [UnionDef.new("Foo")])
  it_parses "lib C; enum Foo; A\nB, C\nD = 1; end end", LibDef.new("C", nil, [EnumDef.new("Foo", [Arg.new("A"), Arg.new("B"), Arg.new("C"), Arg.new("D", 1.int32)])])
  it_parses "lib C; enum Foo; A = 1, B; end end", LibDef.new("C", nil, [EnumDef.new("Foo", [Arg.new("A", 1.int32), Arg.new("B")])])
  it_parses "lib C; Foo = 1; end", LibDef.new("C", nil, [Assign.new("Foo".ident, 1.int32)])
  it_parses "lib C\nfun getch = GetChar\nend", LibDef.new("C", nil, [FunDef.new("getch", [] of ASTNode, nil, 0, false, "GetChar")])

  it_parses "1 .. 2", RangeLiteral.new(1.int32, 2.int32, false)
  it_parses "1 ... 2", RangeLiteral.new(1.int32, 2.int32, true)

  it_parses "A = 1", Assign.new("A".ident, 1.int32)

  it_parses "puts %w(one two)", Call.new(nil, "puts", [["one".string, "two".string].array] of ASTNode)

  it_parses "[] of Int", ([] of ASTNode).array_of("Int".ident)
  it_parses "[1, 2] of Int", ([1.int32, 2.int32] of ASTNode).array_of("Int".ident)

  it_parses "::A::B", Ident.new(["A", "B"], true)

  it_parses "$foo", Global.new("$foo")

  it_parses "macro foo;end", Crystal::Macro.new("foo", [] of Arg)

  it_parses "a = 1; a.ptr", [Assign.new("a".var, 1.int32), PointerOf.new("a".var)]
  it_parses "@a.ptr", PointerOf.new("@a".instance_var)

  it_parses "foo.is_a?(Const)", IsA.new("foo".call, "Const".ident)

  it_parses "/foo/", RegexpLiteral.new("foo")

  it_parses "1 =~ 2", Call.new(1.int32, "=~", [2.int32] of ASTNode)
  it_parses "1.=~(2)", Call.new(1.int32, "=~", [2.int32] of ASTNode)
  it_parses "def =~; end", Def.new("=~", [] of Arg)

  it_parses "foo $a", Call.new(nil, "foo", [Global.new("$a")] of ASTNode)

  it_parses "$1", Call.new(Global.new("$~"), "[]", [1.int32] of ASTNode)
  it_parses "foo $1", Call.new(nil, "foo", [Call.new(Global.new("$~"), "[]", [1.int32] of ASTNode)] of ASTNode)
  it_parses "foo /a/", Call.new(nil, "foo", [RegexpLiteral.new("a")] of ASTNode)

  it_parses "foo out x; x", [Call.new(nil, "foo", [(v = Var.new("x"); v.out = true; v)] of ASTNode), Var.new("x")]
  it_parses "foo(out x); x", [Call.new(nil, "foo", [(v = Var.new("x"); v.out = true; v)] of ASTNode), Var.new("x")]

  it_parses "{1 => 2, 3 => 4}", HashLiteral.new([1.int32, 3.int32] of ASTNode, [2.int32, 4.int32] of ASTNode)
  it_parses "{a: 1, b: 2}", HashLiteral.new(["a".symbol, "b".symbol] of ASTNode, [1.int32, 2.int32] of ASTNode)
  it_parses "{a: 1, 3 => 4, b: 2}", HashLiteral.new(["a".symbol, 3.int32, "b".symbol] of ASTNode, [1.int32, 4.int32, 2.int32] of ASTNode)

  it_parses "{} of Int => Double", HashLiteral.new([] of ASTNode, [] of ASTNode, "Int".ident, "Double".ident)

  it_parses "require \"foo\"", Require.new("foo")
  it_parses "require \"foo\"; [1]", [Require.new("foo"), [1.int32].array]
  it_parses "require \"foo\"\nif true; end", [Require.new("foo"), If.new(true.bool)]

  it_parses "case 1; when 1; 2; else; 3; end", Case.new(1.int32, [When.new([1.int32] of ASTNode, 2.int32)], 3.int32)
  it_parses "case 1; when 0, 1; 2; else; 3; end", Case.new(1.int32, [When.new([0.int32, 1.int32] of ASTNode, 2.int32)], 3.int32)
  it_parses "case 1\nwhen 1\n2\nelse\n3\nend", Case.new(1.int32, [When.new([1.int32] of ASTNode, 2.int32)], 3.int32)
  it_parses "case 1\nwhen 1\n2\nend", Case.new(1.int32, [When.new([1.int32] of ASTNode, 2.int32)])

  it_parses "case 1; when 1 then 2; else; 3; end", Case.new(1.int32, [When.new([1.int32] of ASTNode, 2.int32)], 3.int32)
  it_parses "case 1\nwhen 1\n2\nend\nif a\nend", [Case.new(1.int32, [When.new([1.int32] of ASTNode, 2.int32)]), If.new("a".call)]

  it_parses "def foo(x); end; x", [Def.new("foo", ["x".arg]), "x".call]

  it_parses "\"foo\#{bar}baz\"", StringInterpolation.new([StringLiteral.new("foo"), "bar".call, StringLiteral.new("baz")])

  it_parses "lib Foo\nend\nif true\nend", [LibDef.new("Foo"), If.new(true.bool)]

  it_parses "foo(\n1\n)", Call.new(nil, "foo", [1.int32] of ASTNode)

  it_parses "a = 1\nfoo - a", [Assign.new("a".var, 1.int32), Call.new("foo".call, "-", ["a".var] of ASTNode)]
  it_parses "a = 1\nfoo -a", [Assign.new("a".var, 1.int32), Call.new(nil, "foo", [Call.new("a".var, "-@")] of ASTNode)]

  it_parses "()", NilLiteral.new
  it_parses "(1; 2; 3)", [1.int32, 2.int32, 3.int32]

  it_parses "begin; rescue; end", ExceptionHandler.new(Nop.new, [Rescue.new])
  it_parses "begin; 1; rescue; 2; end", ExceptionHandler.new(1.int32, [Rescue.new(2.int32)])
  it_parses "begin; 1; ensure; 2; end", ExceptionHandler.new(1.int32, nil, nil, 2.int32)
  it_parses "begin\n1\nensure\n2\nend", ExceptionHandler.new(1.int32, nil, nil, 2.int32)
  it_parses "begin; 1; rescue Foo; 2; end", ExceptionHandler.new(1.int32, [Rescue.new(2.int32, ["Foo".ident])])
  it_parses "begin; 1; rescue Foo | Bar; 2; end", ExceptionHandler.new(1.int32, [Rescue.new(2.int32, ["Foo".ident, "Bar".ident])])
  it_parses "begin; 1; rescue ex : Foo | Bar; 2; end", ExceptionHandler.new(1.int32, [Rescue.new(2.int32, ["Foo".ident, "Bar".ident], "ex")])
  it_parses "begin; 1; rescue ex; 2; end", ExceptionHandler.new(1.int32, [Rescue.new(2.int32, nil, "ex")])
  it_parses "begin; 1; rescue; 2; else; 3; end", ExceptionHandler.new(1.int32, [Rescue.new(2.int32)], 3.int32)

  it_parses "def foo(); 1; rescue; 2; end", Def.new("foo", [] of Arg, ExceptionHandler.new(1.int32, [Rescue.new(2.int32)]))

  it_parses "1 rescue 2", ExceptionHandler.new(1.int32, [Rescue.new(2.int32)])

  it "keeps instance variables declared in def" do
    node = Parser.parse("def foo; @x = 1; @y = 2; @x = 3; @z; end")
    if node.is_a?(Def)
      node.instance_vars.should eq(Set.new(["@x", "@y", "@z"]))
    else
      raise "Expected node to be a Def"
    end
  end
end
