class TaintContext
    attr_accessor :tainted

    @@simple_methods =
            ["b", 
            	"byteslice", 
            	"capitalize", "center", 
             "chomp", "chop", "clone", "crypt", "delete", 
             "downcase", "dump", "dup", "element_set",
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
             "substring",
             "squeeze",
             "strip", "sub", "substring", "succ", "next", 
             "swapcase", "tr", "tr_s", "transform", 
             "upcase", 
             "search_region",
             "match_start",
             "search_from",
             "last_match"
         	]

    @@multiparam_methods = ["split"]

    @@operator_methods = ["multiply", "plus", "index", "modulo", "concat"]

    def initialize(tainted)
        @tainted = tainted

        if @tainted
            @@simple_methods.each do |meth|
                define_singleton_method("after_#{meth}") do |obj, arg|
                    if arg.is_a? TrueClass or arg.is_a? FalseClass
                        return arg
                    end

                    arg.taint if not arg.nil? and not arg.frozen?
                end
            end

            @@multiparam_methods.each do |meth|
                define_singleton_method("after_#{meth}") do |obj, *args|
                	# puts "Trying to deal with post-hook for #{args}"

                    args.each do |arg|
                    	# puts "Post-hook for #{meth} with arg #{arg}"
                        if arg.is_a? TrueClass or arg.is_a? FalseClass
                            next
                        end

                        arg.taint if not arg.nil? and not arg.frozen?
                    end

                    # ::Kernel.puts "Handling the post-hook for object #{args}"

                	# args.taint if not args.frozen?

                    if args.count == 1
                    	return args#0]
                    else
                    	return args
                    end
                end
            end

            @@operator_methods.each do |meth|
                define_singleton_method("after_op__#{meth}") do |obj, arg|
                    if arg.is_a? TrueClass or arg.is_a? FalseClass
                        return arg
                    end

                    arg.taint if not arg.nil? and not arg.frozen?
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
        if self.is_a? TrueClass or self.is_a? FalseClass
            return self
        end

        self.secure_context = SecurityManager::TaintedContext if not tainted?
        self
    end

    def tainted?
        if not secure_context?
            return false
        end

        self.secure_context == SecurityManager::TaintedContext
    end

    def untaint
        self.secure_context = SecurityManager::UntaintedContext
        self
    end

    module SecurityManager
        TaintedContext = TaintContext.new(tainted=true)
        UntaintedContext = TaintContext.new(tainted=false)
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

    alias_method :old_slice, :slice
    def slice(one, two=undefined)
    	if one.is_a? String and one.tainted?
	    	ret = old_slice(one, two)

    		if !ret.nil?
	    		Rubinius::Type.infect ret, one
	    	end

	    	ret
	    elsif one.is_a? Regexp
	    	ret = old_slice(one, two)	

	    	if self.tainted? or one.tainted? and !ret.nil?
	    		ret.taint
	    	end

	    	ret
    	else
    		old_slice(one, two)
    	end
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
