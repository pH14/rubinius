require File.expand_path('../../../spec_helper', __FILE__)
require File.expand_path('../fixtures/classes', __FILE__)

describe "Secure context" do
	it "hooks simple method's argument and return value" do
		x = SecureContextSpecs::TestObject.new
		x.secure_context = SecureContextSpecs::SecureContext.new

		x.secure_context.define_singleton_method(:before_one_arg_one_return) do |obj, arg|
			# ::Kernel.puts obj.class
			arg.should == "hello, world!"
			return "pre-hook string"
		end

		x.secure_context.define_singleton_method(:after_one_arg_one_return) do |obj, arg|
			arg.should == "pre-hook string"
			return "post-hook string"
		end

		x.one_arg_one_return("hello, world!").should == "post-hook string"
	end

	it "hooks block argument, returns modified value" do
		x = SecureContextSpecs::TestObject.new
		x.secure_context = SecureContextSpecs::SecureContext.new

		x.secure_context.define_singleton_method(:before_block_method) do |*args, &block|
			::Kernel.puts "args are #{args}, block is #{block}, #{::Kernel.block_given?}"
			begin
				args.each { |y| ::Kernel.puts y }
			rescue => e
				::Kernel.puts "error #{e}"
			end
			block.call.should == 10

			return_block = -> { block.call + 1 }
			return_block.hook_block
		end

		x.secure_context.define_singleton_method(:after_block_method) do |obj, arg|
			obj.should == x
			arg.should == 11
			arg + 1
		end

		x.block_method { 10 }.should == 12
		x.block_method(5, 6) { 10 }.should == 12
	end

	# block_given? is defined by the VariableScope class, which grabs the variables off of the call_frame.
	# Because the context is built around fairly janky operations on the call_frame... it's likely to not
	# work out how you want it to. However, that issue is separate from &block being passed in, so &block
	# and block.call are still going to work the way they are intended to work.
	# it "hooks block argument, returns modified value using yield" do
	# 	x = SecureContextSpecs::TestObject.new
	# 	x.secure_context = SecureContextSpecs::SecureContext.new

	# 	x.secure_context.define_singleton_method(:before_block_method) do
	# 		if block_given?
	# 			puts "Block has been given"
	# 		else
	# 			puts "Block has not been given"
	# 		end
	# 		begin
	# 			yield.should == 10
	# 		rescue => e
	# 			::Kernel.puts "hit with exception #{e}"
	# 		end

	# 		return_block = -> { yield + 1 }
	# 		return_block.hook_block
	# 	end

	# 	x.secure_context.define_singleton_method(:after_block_method) do |arg|
	# 		arg.should == 11
	# 		arg + 1
	# 	end

	# 	x.block_method { 10 }.should == 12
	# end
end