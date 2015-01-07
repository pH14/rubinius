require File.expand_path('../../../spec_helper', __FILE__)
require File.expand_path('../fixtures/classes', __FILE__)

describe "Secure context" do
	it "hooks methods that take no arguments" do
		x = SecureContextSpecs::TestObject.new
		x.secure_context = SecureContextSpecs::SecureContext.new "wasn't called"

		x.secure_context.define_singleton_method(:before_no_args_method) do |obj|
			@return_args = "was called"	
		end

		x.no_args_method
		x.secure_context.return_args.should == "was called"
	end

	it "hooks methods that takes no arguments but gives a block" do
		x = SecureContextSpecs::TestObject.new
		x.secure_context = SecureContextSpecs::SecureContext.new

		x.secure_context.define_singleton_method(:before_no_args_method_with_block) do |obj|
			return_proc = Proc.new { 10 }
			return_proc.hook_block
		end

		x.no_args_method_with_block.should == 10
	end

	it "returns just one value without splat" do 
		x = SecureContextSpecs::TestObject.new
		x.secure_context = SecureContextSpecs::SecureContext.new "world"

		x.method_no_splat("hello").should == "world"
	end

	it "returns array of one value with splat" do 
		x = SecureContextSpecs::TestObject.new
		x.secure_context = SecureContextSpecs::SecureContext.new "world"

		x.method_with_splat("hello").should == ["world"]
	end

	it "returns array of values with splat and several arguments" do
		x = SecureContextSpecs::TestObject.new
		x.secure_context = SecureContextSpecs::SecureContext.new 'should', 'be', 'returned'

		x.method_with_splat('hello').should == ['should', 'be', 'returned']
		x.method_with_splat('hello', 'world').should == ['should', 'be', 'returned']
		x.method_with_splat('hello', 'world', 'rbx').should == ['should', 'be', 'returned']
	end

	it "uses multiple return values as arguments to a method" do
		x = SecureContextSpecs::TestObject.new
		x.secure_context = SecureContextSpecs::SecureContext.new
		x.secure_context.define_singleton_method(:before_add) { |obj, x, y| return 10, 20 }

		x.add(1, 2).should == 30
	end

	it "throws an ArgumentError when too few arguments are returned" do
		x = SecureContextSpecs::TestObject.new
		x.secure_context = SecureContextSpecs::SecureContext.new
		x.secure_context.define_singleton_method(:before_add) { |obj, x, y| return }

		lambda{x.add(1, 2)}.should raise_error(ArgumentError)
	end

	it "throws an ArgumentError when too many args are returned without it being a splat" do
		x = SecureContextSpecs::TestObject.new
		x.secure_context = SecureContextSpecs::SecureContext.new
		x.secure_context.define_singleton_method(:before_add) { |obj, x, y| return 10, 20, 30 }

		lambda{x.add(1, 2)}.should raise_error(ArgumentError)
	end

	it "hooks methods with just a block, and context returns a new block" do
		x = SecureContextSpecs::TestObject.new
		x.secure_context = SecureContextSpecs::SecureContext.new

		x.secure_context.define_singleton_method(:before_block_method) do |obj|
			return_proc = Proc.new { 10 }
			return_proc.hook_block
		end

		x.block_method { 5 }.should == 10
	end

	it "throws a LocalJumpError when just a block is passed, but context returns nothing" do
		x = SecureContextSpecs::TestObject.new
		x.secure_context = SecureContextSpecs::SecureContext.new
		x.secure_context.define_singleton_method(:before_block_method) { |obj| }

		lambda{x.block_method { false }}.should raise_error(LocalJumpError)
	end

	it "hooks methods with an argument and block" do
		x = SecureContextSpecs::TestObject.new
		x.secure_context = SecureContextSpecs::SecureContext.new
		x.method_block_and_argument(4) { |n| n % 2 == 0 }.should == true

		x.secure_context.define_singleton_method(:before_method_block_and_argument) do |*args, &block|
			block.hook_block
			return 5, block
		end

		x.method_block_and_argument(4) { |n| n % 2 == 0 }.should == false
	end

	it "hooks methods with an argument and block passed with & operator" do
		x = SecureContextSpecs::TestObject.new
		x.secure_context = SecureContextSpecs::SecureContext.new

		is_even = Proc.new { |n| n % 2 == 0 }
		is_odd = Proc.new { |n| n % 2 == 0 }
		x.method_block_and_argument(4, &is_even).should == true

		x.secure_context.define_singleton_method(:before_method_block_and_argument) do |*args, &block|
			block.hook_block
			return 5, block
		end

		x.method_block_and_argument(4) { |n| n % 2 == 0 }.should == false
	end

	it "hooks methods with an argument and block, context returns new args and new block" do 
		x = SecureContextSpecs::TestObject.new
		x.secure_context = SecureContextSpecs::SecureContext.new

		product = Proc.new { |x| x.inject(:*) }
		x.method_block_and_argument_splat(4, &product).should == 4

		x.secure_context.define_singleton_method(:before_method_block_and_argument_splat) do |obj, arg, &block|
			sum = Proc.new { |x| x.inject(:+) }
			sum.hook_block
			return 1, 10, 100, sum
		end

		x.method_block_and_argument_splat(4, &product).should == 111
	end

	# TODO: This error should be more informative and pertain to the secure context class specifically
	it "throws an error when it returns a value that cannot be a block" do
		x = SecureContextSpecs::TestObject.new
		x.secure_context = SecureContextSpecs::SecureContext.new

		x.secure_context.define_singleton_method(:before_block_method) do |obj, &block|
			"abc"
		end

		lambda{x.block_method { 5 }}.should raise_error
	end

	it "can use lambdas and Procs as returned blocks" do
		x = SecureContextSpecs::TestObject.new
		x.secure_context = SecureContextSpecs::SecureContext.new

		x.secure_context.define_singleton_method(:before_block_method) do |obj, &block|
			lambda = ->{ 10 }
			lambda.hook_block
		end

		x.block_method { 5 }.should == 10

		x.secure_context.define_singleton_method(:before_block_method) do |obj, &block|
			return_proc = Proc.new { 10 }
			return_proc.hook_block
		end

		x.block_method { 5 }.should == 10
	end

	it "does not use implicitly returned values incorrectly as arguments" do
		x = SecureContextSpecs::TestObject.new
		x.secure_context = SecureContextSpecs::SecureContext.new

		x.secure_context.define_singleton_method(:before_no_args_method) do |obj|
			"hello!!!"
		end

		x.no_args_method.should == 10
	end

	# Note : make sure to test cases where the hooked method is a runtime defined method, since it's
	# a BlockEnvironment rather than CompiledCode, and the VM hooks depend on Compiled at the moment..

	it "passes args and blocks straight through" do
		class TestObject
			def check_all_args_and_block_method(*args, &block)
				args.each_with_index do |i, arg|
					arg.should == i
					::Kernel.puts "Yay it matched! #{i} == #{arg}"
				end

				block.call == "great success!"
			end
		end

		x = TestObject.new

		x.secure_context = SecureContextSpecs::SecureContext.new
		x.secure_context.define_singleton_method(:before_check_all_args_and_block_method) do |obj, *args, &block|
			block.hook_block
			return *args, block
		end

		random_block = Proc.new { "great success!" }
		x.check_all_args_and_block_method(0, 1, 2, 3, 4, 5, 6, 7, 8, &random_block).should == true
	end
end