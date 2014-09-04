require 'pp'

class SecureContext# < BasicObject
	attr_accessor :tainted
	attr_accessor :return_args

	def initialize(*args)
		@return_args = args
	end

	def args_with_splat(*args)
		pp "Hi! About to return #{args}"
		return ['el oh el']
	end

	def args_and_block(*args, &block)
		pp "Hi! About to return #{args}"
		return args, block
	end

	def args(*args)
		pp "Hi! About to return #{args}"
		@return_args
	end

	def block_method

	end

	def method_takes_2_args(x, y)
		return 10, 100, 1000
	end

	# def respond_to?
	# 	if 

	# def pp(*args)
	# 	args
	# end
	def basic_object
		::Kernel.puts "in SecureContext"
		"hi"
	end
end

class TestObject
	def args_and_block(*args, &block)
		# pp "Number of args_and_block is #{args.length}"
		return yield
	end

	def args_with_splat(*args)
		pp "[TestObject] Number of args_with_splat is #{args.length}"
		args
	end

	def args_no_splat(args)
		args
	end

	def block_method
		yield
	end

	def method_takes_2_args(x, y)
		return x + y
	end

	def basic_object
		puts "in TestObject"
	end

	def foo
		"rawr"
	end
end

class TestBasicObject < BasicObject
	def say_hi
		"hello!"
	end
end

x = TestObject.new
x.secure_context = SecureContext.new 10

# puts x.args_with_splat(1, 2, 3)
x.basic_object
x.foo

# x.secure_context.basic_object

# y = TestBasicObject.new
# puts y.say_hi

# pp [(x.args_with_splat 10).class, x.args_with_splat(10)]
# pp [(x.args_no_splat 10).class, x.args_no_splat(10)]

# pp [(x.args_with_splat [1, 2, 3]).class, x.args_with_splat([1, 2, 3])]
# pp [(x.args_no_splat [1, 2, 3]).class, x.args_no_splat([1, 2, 3])]

# pp x.args_and_block(1, 2, 3) { |i| i }
# pp x.args_with_splat(1, 2, 3) { |i| i }

# pp x.method_takes_2_args(10, 15, 25)
