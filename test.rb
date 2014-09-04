require 'pp'

class TestObject
	@@foo = "foo"
	attr_accessor :cookies

	def initialize(num_cookies=10)
		@cookies = num_cookies
	end

	def foo(*args, &b)
		pp "Inside TestObject#foo"
		pp b.call 3
		# pp yield
		pp args
	end

	def take_cookie!
		@cookies = @cookies - 1000
	end

	def take_cookie(n = 5, p = 10)
		@cookies -= n
		p += 1
	end

	def test_object_exclusive x, y
		pp x, y
		yield
	end
end

class SecurityContext
  @@foo = "bar"

  attr_accessor :cookies

  def initialize(num_cookies=10)
  	@cookies = num_cookies
  end

  def foo(*args, &b)
  	p "Inside SecurityContext#foo"
  	p b.call 5
  	return 1, 2, 3, 4, 5, "hello, world!", b
  end

  def take_cookie!
  	@cookies -= 1
  end

  def take_cookie(n = 5, p = 10)
	@cookies -= n
	p += 1
  end

  def pp(*args)
  	args
  end

  def puts(*args)
  	args
  end
end

x = TestObject.new
y = TestObject.new

pp [x.secure_context?, false]
pp [y.secure_context?, false]

# pp x.methods.sort

x.secure_context = SecurityContext.new
y.secure_context = SecurityContext.new 15

# x.foo 10, 11, 12

# pp x.secure_context?
# pp x.foo
# pp x.cookies
# pp x.take_cookie 1, 2
# pp x.secure_context?

# pp [x.secure_context?, true]
# pp [y.secure_context?, true]

# pp [x.secure_context, y.secure_context]

# pp [x.secure_context.cookies, y.secure_context.cookies]
# pp [x.secure_context.take_cookie!, y.secure_context.take_cookie!]

x.test_object_exclusive(5, 10) do |n|
	pp "I'm a block! I'm a block!"
end

# x.foo 10, 20, 30, 40
# q = 5

x.foo(1, 20, 3) do |n|
	"I'm a block that gets passed around!"
end
# pp [x.take_cookie!, y.take_cookie!]