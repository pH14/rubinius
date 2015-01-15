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
             "slice", 
             # "slice!", 
             # "substring",
             "squeeze",
             "strip", "sub", 
             # "substring", 
             "succ", "next", 
             "swapcase", "tr", "tr_s", "transform", 
             "upcase", 
             #regexp
             "search_region",
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
         	]

    @@multiparam_methods = ["split"]

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
            # define_singleton_method("before_slice") do |obj, one, two|
            #     if one.nil?
            # end
            # define_singleton_method("after_slice") do |obj, arg|
            #     if not arg.nil?
            #         arg
            #     else
            #         arg.taint
            #     end
            # end
            define_singleton_method("before_join") do |obj, *params|
                params.each do |p|
                    if p.tainted?
                        puts "******** TAINTING FROM JOIN HOOK"
                        obj.taint
                        break
                    end
                end

                return params
            end

            @@simple_methods.each do |meth|
                define_singleton_method("after_#{meth}") do |obj, arg|
                    if obj.is_a? Array
                        if obj.empty?
                            return arg
                        end
                    end

                    arg.taint if not arg.nil? and not arg.frozen?
                end
            end

            @@multiparam_methods.each do |meth|
                define_singleton_method("after_#{meth}") do |obj, args|
                	# if args.is_a? Enumerable
	                #     args.each do |arg|
	                #         arg.taint if not arg.nil? and not arg.frozen?
	                #     end

	                #     return args
                	# else
                	# 	args.taint
                	# end
            		unless obj.is_a? Enumerable
            			if args.is_a? Enumerable
		                    args.each do |arg|
		                        arg.taint if not arg.nil? and not arg.frozen?
		                    end
		                else
		                	args.taint if not args.nil? and not args.frozen?
		                end
	                end

                    return args
                end
            end

            @@operator_methods.each do |meth|
                define_singleton_method("after_op__#{meth}") do |obj, args|
                	# puts "after_op__#{meth}: Args has elements. #{args.tainted?}"
            		unless obj.is_a? Enumerable
            			if args.is_a? Enumerable
		                    args.each do |arg|
		                        arg.taint if not arg.nil? and not arg.frozen?
		                    end
		                else
		                	args.taint if not args.nil? and not args.frozen?
		                end
	                end

                    return args
                end
            end
        end
    end

    def infect(other)
    	# puts "Want to infect #{other}!!!!!!!!!!!!!!!!!!!"
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

        # puts "Tainting #{self}. Class : #{self.class} Nil? : #{nil?}"
        # puts "Tainting a #{self.class}, #{self}"
        self.secure_context = SecurityManager::TaintedContext

        # puts "Tainting a #{self.class}. Is tainted now? #{self.tainted?}"

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

        self.secure_context = nil#SecurityManager::UntaintedContext
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

    # alias_method :old_slice, :slice
    # alias_method :old_slice, :[]
    # def [](one, two=undefined)
    # 	# puts "NEW SLICE GETTING CALLED #########################################################################"
    # 	if one.is_a? String and one.tainted?
	   #  	ret = old_slice(one, two)

    # 		if !ret.nil?
	   #  		Rubinius::Type.infect ret, one
	   #  	end

	   #  	ret
	   #  elsif one.is_a? Regexp
	   #  	ret = old_slice(one, two)	

	   #  	if self.tainted? or one.tainted? and !ret.nil?
	   #  		ret.taint
	   #  	end

	   #  	ret
    # 	else
    # 		old_slice(one, two)
    # 	end
    # end
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
                if source.secure_context?
                    source.secure_context.infect host
                end

                old_infect(host, source)
            end
        end
    end
end
