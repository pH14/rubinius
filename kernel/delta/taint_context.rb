class TaintContext
    attr_accessor :tainted

    @@simple_methods =
            ["b", 
            	"byteslice", 
            	"capitalize", "center", 

                # Rails, SafeBuffer
                "concat",
                "safe_concat",
                "initialize_copy",

             "chomp", "chop", "clone", "crypt", "delete", 
             "downcase", "dump", 
             "dup", 
             "element_set",
             "encode", 
             # These find_* methods are potentially problematic with hooks...
             # they are also rbx-specific. are they necessary here?
             "find_character",  
             # "find_string",
             # "find_string_reverse", 
             "gsub", "insert", 
             "ljust", "lstrip", "modulo", "multiply", 
             "plus", "prepend", "reverse", "rjust", 
             "rstrip", 
             # "slice", 
             # "slice!", 
             # "substring",
             "squeeze",
             "strip", "sub", 
             # "substring", 
             "succ", "next", 
             "swapcase", "tr", "tr_s", "transform", 
             "upcase", 
             #regexp
             # "search_region",
             "match_start",
             "search_from",
             "last_match",
             "to_f",
             "to_a",
             "to_s",
             "to_str",
             # "inspect"
             #array
             # "pack"

             # regexp
             "match",
             # "pre_match",
             # "post_match",
             # "StringValue",
         	]

    @@multiparam_methods = ["split"]#, "subpattern"]

    @@operator_methods   = ["multiply", # *
                            "divide",   # /
                            "plus",     # +
                            "minus",    # -
                            "modulo",   # %
                            "not",      # !
                            "gt",       # >
                            "lt",       # <
                            "gte",      # >=
                            "lte",      # <=
                            "backtick", # `
                            "invert",   # ~
                            # "equals",   # ==
                            "not_equals", # !=
                            "similar",  # ===
                            "match",    # =~
                            "comparison", # <=>
                            "lshift",   # <<
                            "rshift",   # >>
                            "index",    # []
                            "element_assignment", # []=
                            "bitwise_and", # &
                            "bitwise_or",  # |
                            "bitwise_xor", # ^
                            "exponent",    # **
                            "uplus",       # +@
                            "uminus"]      # -@

    def initialize(tainted)
        @tainted = tainted

        if @tainted
            # This doesn't yet cover when slice returns several arguments, not just one
            define_singleton_method("after_slice") do |obj, arg, method_args|
              case method_args[0]
              when String
                if method_args[0].tainted? and not arg.nil?
                  arg.taint
                end
              else
                arg.taint
              end

              return arg
            end

            @@simple_methods.each do |meth|
                define_singleton_method("after_#{meth}") do |obj, arg, method_args|
                    if obj.is_a? Array
                        if obj.empty?
                            return arg
                        end
                    end

                    # Range should not pass on taint to its to_s, unless the
                    # begin or ending strings of it are tainted. The Range object
                    # itself shouldn't pass it on.
                    if meth == "to_s"
                      if obj.is_a? Range and not arg.tainted?
                        return arg
                      end

                      if obj.is_a? Hash and obj.empty?
                        return arg
                      end
                    end

                    arg.taint
                end
            end

            @@multiparam_methods.each do |meth|
                define_singleton_method("after_#{meth}") do |obj, args, method_args|
              		unless obj.is_a? Enumerable
              		  	if args.is_a? Enumerable
  		                    args.each do |arg|
  		                        arg.taint
  		                    end
  		                else
  		                	args.taint
  		                end
	                end

                  return args
                end
            end

            @@operator_methods.each do |meth|
                define_singleton_method("after_op__#{meth}") do |obj, args, method_args|
            		if not obj.is_a? Enumerable
            			if args.is_a? Enumerable
		                    args.each do |arg|
		                        arg.taint
		                    end
		                else
		                	args.taint
		                end
	                end

                    return args
                end
            end
        end
    end

    def infect(other)
        other.taint 
    end
end

module Kernel
    def taint
        if is_a? TrueClass or is_a? FalseClass or is_a? NilClass
            return self
        end

        if tainted? or frozen? or nil?
            return self
        end

        self.secure_context = SecurityManager::TaintedContext
        self
    end

    def tainted?
        if not secure_context?
            return false
        end

        self.secure_context == SecurityManager::TaintedContext
    end

    def untaint
        if is_a? TrueClass or is_a? FalseClass or is_a? NilClass
            return self
        end

        if frozen?
            return self
        end

        self.secure_context = nil
        self
    end

    module SecurityManager
        TaintedContext = TaintContext.new(tainted=true)
    end
end

class String
    alias_method :old_modulo, :%

    def %(*args)
        ret = old_modulo *args

        unless %w(%e %E %f %g %G).include? self
          if self.eql? '%p'
            args.each do |arg|
              Rubinius::Type.infect ret, arg.inspect
            end
          else
            args.each do |arg|
              Rubinius::Type.infect ret, arg
            end
          end
        end

        ret
    end
end

class Array
	alias_method :old_pack, :pack

	def pack(directives)
		ret = old_pack directives

		self.each do |a|
			Rubinius::Type.infect ret, a
		end

		Rubinius::Type.infect ret, directives

		ret
	end
end

module Rubinius
    module Type
        class << self
            alias_method :old_infect, :infect

            def infect(host, source)
                if source.respond_to? :secure_context? and source.secure_context?
                    source.secure_context.infect host
                end

                old_infect(host, source)
            end
        end
    end
end