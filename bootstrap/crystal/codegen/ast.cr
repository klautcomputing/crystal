require "../ast"

class Crystal::Def
  def mangled_name(self_type)
    arg_types = args.map &.type

    String.build do |str|
      if owner = @owner
        # if owner.metaclass?
        #   str << owner.instance_type.llvm_name
        #   str << '::'
        # els
        if !owner.is_a?(Crystal::Program)
          str << owner.llvm_name
          str << '#'
        end
      end
      str << name.to_s.replace('@', '.')
      str << '<'
      if self_type
        str << self_type.llvm_name
      end
      if arg_types.length > 0
        str << ", " if self_type
        str << arg_types.map(&.llvm_name).join(", ")
      end
      str << '>'
      if return_type = @return_type
        str << ':'
        str << return_type.llvm_name
      end
    end
  end
end
