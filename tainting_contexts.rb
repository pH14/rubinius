class TaintContext
    attr_accessor :tainted

    @@simple_methods =  
            ["b", "byteslice", "capitalize", "center", 
             "chomp", "chop", "clone", "crypt", "delete", 
             "downcase", "dump", "dup", "element_set",
             "encode", "find_character", "find_string",
             "find_string_reverse", "gsub", "insert", 
             "ljust", "lstrip", "modulo", "multiply", 
             "plus", "prepend", "reverse", "rjust", 
             "rstrip", "slice", "slice!", "squeeze",
             "strip", "sub", "substring", "succ", "next", 
             "swapcase", "tr", "tr_s", "transform", 
             "upcase", "search_region"]

    @@multiparam_methods = ["split"]

    @@operator_methods = ["multiply", "plus", "index", "modulo"]

    def initialize(tainted)
        @tainted = tainted

        if @tainted
            @@simple_methods.each do |meth|
                define_singleton_method("after_#{meth}") do |obj, new_string|
                    if new_string.is_a? TrueClass or new_string.is_a? FalseClass
                        return new_string
                    end

                    new_string.taint if not new_string.nil? and not new_string.frozen?
                end
            end

            @@multiparam_methods.each do |meth|
                define_singleton_method("after_#{meth}") do |obj, *args, &block|
                    args.each do |arg|
                        if arg.is_a? TrueClass or arg.is_a? FalseClass
                            next
                        end
                        arg.taint if not arg.nil? and not arg.frozen?
                    end

                    if not block.nil?
                        block.hooked_block
                        return *args, block
                    else
                        return *args
                    end
                end
            end

            @@operator_methods.each do |meth|
                define_singleton_method("after_op__#{meth}") do |obj, *args, &block|
                    # ::Kernel.puts "Trying to taint #{new_string}"
                    args.each do |arg|
                        if arg.is_a? TrueClass or arg.is_a? FalseClass
                            return arg
                        end

                        arg.taint if not arg.nil? and not arg.frozen?
                    end

                    if not block.nil?
                        block.hooked_block
                        return *args, block
                    else
                        return *args
                    end
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


# class SecureContextMiddleware
#     def initialize(app)
#         @app = app
#     end

#     def call(env)
#         # puts "SC Middleware called, env is #{env}"
#         env.taint
#         @app.call(env)
#     end
# end

# puts "middleware file has been read"