module SecureContextSpecs
	class SecureContext
		attr_accessor :tainted
		attr_accessor :return_args
		attr_accessor :return_block

		def initialize(*args, &block)
			@return_args = args

			if ::Kernel::block_given?
				@return_block = block
			else
				@return_block = ::Kernel::lambda { |n| i % 2 == 1 }
			end

			@return_block.hook_block
		end

		def before_args_and_block(*args, &block)
			block.hook_block
			return args, block
		end

		def before_method_with_splat(*args)
			@return_args
		end

		def before_method_no_splat(obj, arg)
			@return_args
		end

		def before_method_block_as_argument(&block)
			return @return_block
		end

		def before_method_block_and_argument(obj, arg1, &block)
			block.hook_block
			return arg1, block
		end

		# def puts(*args)
		# 	args
		# end
	end

	class TestObject
		def args_and_block(*args, &block)
			yield
		end

		def block_method(&block)
			yield
		end

		def method_with_splat(*args)
			args
		end

		def method_no_splat(arg)
			return arg
		end

		def method_block_as_argument(&block)
			block.call
		end

		def method_block_and_argument(arg1, &block)
			block.call(arg1)
		end

		def method_block_and_argument_splat(*args, &block)
			yield args
		end

		def add(x, y)
			x + y
		end

		def one_arg_one_return(arg)
			puts arg
			arg
		end

		def no_args_method
			10
		end

		def returns_nothing
		end

		def returns_one_value
			10
		end

		def returns_many_values
			return 10, "hello", 20, "world", 30
		end

		def no_args_method_with_block
			yield
		end
	end
end
