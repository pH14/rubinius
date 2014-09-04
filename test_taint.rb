require 'pp'

class TaintBit < BasicObject
	attr_accessor :tainted

	def eigenclass
		(class << self; self end).class
	end

	def initialize
		@defined_methods = []
	end

	def method_missing(method_sym, *call_args, &call_block)
		# ::Kernel.puts "Defining method #{method_sym}."

		# NOTE: Errors within a hooked BasicObject will be suppressed, causing very strange things
		# @defined_methods.inclajsdfalskdjfa;lsdfjkasdf

		# begin
		# 	@defined_methods.includes? :hi
		# rescue ::Object::Exception => e
		# 	::Kernel.puts "Caught error in BasicObject #{e}"
		# end

		begin
			if not @defined_methods.include? method_sym
				# ::Kernel.puts "Eigenclass has #{eigenclass.methods.sort!}"
				generic_hook = ::Object::Proc.new do |*args, &block|
					puts "My args are #{args}"
					if block_given?
						if args[0].empty?
							return block
						end

						return args, block
					else
						# puts "Args are #{args}"
						return args[0]
					end
				end

				eigenclass.__send__(:define_singleton_method, :method_sym, generic_hook)

				@defined_methods.push method_sym
			end

			eigenclass.__send__(:method_sym, call_args, call_block)
		rescue ::Object::Exception => e
			::Kernel.puts "Caught error in BasicObject #{e}"
		end
	end

	def respond_to(method_sym, include_all=false)
		@defined_method.include? method_sym
	end

	# def intercept_arguments(*args)
	# 	puts "Hello, World!"
	# 	args
	# end

	def secure_context
	end

	def equal?(*args)
		args
	end
end

# x = "hello, world"
y = "hello, pwh"

# puts x.methods.include? :freeze
# puts BasicObject.class
y.secure_context = TaintBit.new

# puts y.replace "rawrarwawr!"
# puts y.insert 5, "LOL"
# puts y.to_upper!
# puts y.secure_context.inspect

y.each_char do |c|
	puts c.upcase!
end

# puts y