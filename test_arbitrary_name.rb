class SecureContext
	def before_upcase!(*args)
		puts "\nwassup??\n"
		return args
	end

	def after_upcase!(*args)
		puts "\nbye!!\n"
		return args
	end

	def before_foo(*args)
	end

	def after_foo(*args)
		return args
	end
end

class RandomObject
	attr_accessor :foo

	def initialize 
		@foo = "cool"
	end
end

# x = "\nrandom string\n"

# x.secure_context = SecureContext.new

# puts x.upcase!


y = RandomObject.new
y.secure_context = SecureContext.new
puts y.foo
