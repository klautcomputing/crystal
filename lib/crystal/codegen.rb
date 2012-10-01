require 'llvm/core'
require 'llvm/execution_engine'
require 'llvm/transforms/scalar'

LLVM.init_x86

module Crystal
  class ASTNode
    def llvm_type
      type.llvm_type
    end
  end

  class Def
    def mangled_name
      self.class.mangled_name(owner, name, args.map(&:type))
    end

    def self.mangled_name(owner, name, arg_types)
      str = ''
      if owner
        str << owner.to_s
        str << '#'
      end
      str << name.to_s
      if arg_types.length > 0
        str << '<'
        str << arg_types.map(&:name).join(', ')
        str << '>'
      end
      str
    end
  end

  def run(code)
    node = parse code
    mod = infer_type node
    llvm_mod = build node, mod

    engine = LLVM::JITCompiler.new(llvm_mod)
    engine.run_function llvm_mod.functions["crystal_main"]
  end

  def build(node, mod)

    visitor = CodeGenVisitor.new(mod, node.type)
    node.accept visitor

    visitor.finish

    visitor.llvm_mod.verify

    visitor.llvm_mod.dump if ENV['DUMP']

    visitor.llvm_mod
  end

  class CodeGenVisitor < Visitor
    attr_reader :llvm_mod

    def initialize(mod, return_type)
      @mod = mod
      @return_type = return_type
      @llvm_mod = LLVM::Module.new("Crystal")
      @fun = @llvm_mod.functions.add("crystal_main", [], return_type.llvm_type)
      entry = @fun.basic_blocks.append("entry")
      @builder = LLVM::Builder.new
      @builder.position_at_end(entry)

      @funs = {}
      @vars = {}
      @type = @mod
    end

    def main
      @fun
    end

    def finish
      @builder.ret(@return_type == @mod.void ? nil : @last)
    end

    def visit_bool(node)
      @last = LLVM::Int1.from_i(node.value ? 1 : 0)
    end

    def visit_int(node)
      @last = LLVM::Int(node.value)
    end

    def visit_float(node)
      @last = LLVM::Float(node.value)
    end

    def visit_char(node)
      @last = LLVM::Int8.from_i(node.value)
    end

    def visit_assign(node)
      node.value.accept self

      if node.target.is_a?(InstanceVar)
        index = @type.index_of_instance_var(node.target.name)
        ptr = @builder.gep(@fun.params[0], [LLVM::Int(0), LLVM::Int(index)], node.target.name)
      else
        var = @vars[node.target.name]
        unless var && var[:type] == node.type
          var = @vars[node.target.name] = {
            ptr: @builder.alloca(node.llvm_type, node.target.name),
            type: node.type
          }
        end
        ptr = var[:ptr]
      end

      @builder.store @last, ptr

      false
    end

    def visit_var(node)
      var = @vars[node.name]
      if var[:is_arg]
        @last = var[:ptr]
      else
        @last = @builder.load var[:ptr], node.name
      end
    end

    def visit_instance_var(node)
      index = @type.index_of_instance_var(node.name)
      struct = @builder.load @fun.params[0]
      @last = @builder.extract_value struct, index, node.name
    end

    def visit_if(node)
      has_else = !node.else.empty?

      then_block = @fun.basic_blocks.append("then")
      exit_block = @fun.basic_blocks.append("exit")

      if has_else
        else_block = @fun.basic_blocks.append("else")
      end

      node.cond.accept self

      @builder.cond(@last, then_block, has_else ? else_block : exit_block)

      @builder.position_at_end then_block
      node.then.accept self
      then_value = @last
      @builder.br exit_block

      if has_else
        @builder.position_at_end else_block
        node.else.accept self
        else_value = @last
        @builder.br exit_block

        @builder.position_at_end exit_block
        @last = @builder.phi node.llvm_type, {then_block => then_value, else_block => else_value}
      else
        @builder.position_at_end exit_block
      end

      false
    end

    def visit_while(node)
      while_block = @fun.basic_blocks.append("while")
      body_block = @fun.basic_blocks.append("body")
      exit_block = @fun.basic_blocks.append("exit")

      @builder.br while_block

      @builder.position_at_end while_block
      node.cond.accept self

      @builder.cond(@last, body_block, exit_block)

      @builder.position_at_end body_block
      node.body.accept self
      @builder.br while_block

      @builder.position_at_end exit_block

      false
    end

    def visit_def(node)
      false
    end

    def visit_class_def(node)
      false
    end

    def visit_primitive_body(node)
      @last = node.block.call(@builder, @fun)
    end

    def visit_call(node)
      if node.obj.is_a?(Const) && node.name == 'new'
        @last = @builder.malloc(node.type.llvm_struct_type)
        return false
      end

      mangled_name = node.target_def.mangled_name

      call_args = []
      if node.obj
        node.obj.accept self
        call_args << @last
      end
      node.args.each do |arg|
        arg.accept self
        call_args << @last
      end

      old_fun = @fun
      unless @fun = @funs[mangled_name]
        old_position = @builder.insert_block
        old_vars = @vars
        old_type = @type

        @vars = {}

        args = []
        if node.obj
          @type = node.obj.type
          args << Var.new("self", node.obj.type)
        end
        args += node.target_def.args

        @fun = @funs[mangled_name] = @llvm_mod.functions.add(
          mangled_name,
          args.map(&:llvm_type),
          node.target_def.body.llvm_type
        )

        args.each_with_index do |arg, i|
          @fun.params[i].name = arg.name
        end

        unless node.target_def.is_a? External
          @fun.linkage = :internal
          entry = @fun.basic_blocks.append("entry")
          @builder.position_at_end(entry)

          args.each_with_index do |arg, i|
            if node.obj && i == 0 || node.target_def.body.is_a?(PrimitiveBody)
              @vars[arg.name] = { ptr: @fun.params[i], type: arg.type, is_arg: true }
            else
              ptr = @builder.alloca(arg.llvm_type, arg.name)
              @vars[arg.name] = { ptr: ptr, type: arg.type }
              @builder.store @fun.params[i], ptr
            end
          end

          node.target_def.body.accept self
          @builder.ret(node.target_def.body.type == @mod.void ? nil : @last)
          @builder.position_at_end old_position
        end

        @vars = old_vars
        @type = old_type
      end

      @last = @builder.call @fun, *call_args
      @fun = old_fun

      false
    end
  end
end