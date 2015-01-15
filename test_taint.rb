require 'pp'

# class TaintBit < BasicObject
# 	attr_accessor :tainted

# 	def eigenclass
# 		(class << self; self end).class
# 	end

# 	def initialize
# 		@defined_methods = []
# 	end

# 	def method_missing(method_sym, *call_args, &call_block)
# 		# ::Kernel.puts "Defining method #{method_sym}."

# 		# NOTE: Errors within a hooked BasicObject will be suppressed, causing very strange things
# 		# @defined_methods.inclajsdfalskdjfa;lsdfjkasdf

# 		# begin
# 		# 	@defined_methods.includes? :hi
# 		# rescue ::Object::Exception => e
# 		# 	::Kernel.puts "Caught error in BasicObject #{e}"
# 		# end

# 		begin
# 			if not @defined_methods.include? method_sym
# 				# ::Kernel.puts "Eigenclass has #{eigenclass.methods.sort!}"
# 				generic_hook = ::Object::Proc.new do |*args, &block|
# 					::Kernel.puts "Defined method: #{method_sym} args are #{args}, block is #{block}"

# 					if not block.nil?#block_given?
# 						if args.empty?
# 							::Kernel.puts "Returning just block"
# 							return block
# 						end

# 						::Kernel.puts "Returning both"
# 						return args, block
# 					else
# 						if not block.nil?
# 							::Kernel.puts "WTF Alert: Block not given, but block is not nil"
# 						end
# 						::Kernel.puts "Returning args #{args} because block_given is #{block_given?}"
# 						return args
# 					end
# 				end

# 				::Kernel.puts "Defining #{method_sym} for the first time!"
# 				eigenclass.__send__(:define_singleton_method, :method_sym, generic_hook)

# 				@defined_methods.push method_sym
# 			end

# 			eigenclass.__send__(:method_sym, *call_args, &call_block)
# 		rescue ::Object::Exception => e
# 			::Kernel.puts "Caught error in BasicObject #{e}"
# 		end
# 	end

# 	def respond_to(method_sym, include_all=false)
# 		@defined_method.include? method_sym
# 	end

# 	# def intercept_arguments(*args)
# 	# 	puts "Hello, World!"
# 	# 	args
# 	# end

# 	def secure_context
# 	end

# 	def equal?(*args)
# 		args
# 	end
# end

# # x = "hello, world"
# y = "hello, pwh"

# # puts x.methods.include? :freeze
# # puts BasicObject.class
# y.secure_context = TaintBit.new

# # puts y.replace "rawrarwawr!"
# # puts y.insert 5, "LOL"
# # puts y.to_upper!
# # puts y.secure_context.inspect

# # y.upcase!

# y.each_char do |c|
# 	puts c.upcase!
# end

# y.each_char do |c|
# 	c.upcase!
# end

# puts y

# # y.each_char do |c|
# # 	puts c.upcase!
# # end

# # puts y
class String
	def self.interpolate_join(*s)
		return s.join ''
	end
end

x = "key"
y = "hello, world".taint
z = %(#{x}="#{y}")

puts z, z.class
puts z.tainted? == true