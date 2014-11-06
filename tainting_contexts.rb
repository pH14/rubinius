require "pp"

# class TaintSecureContext# < BasicObject
# 	attr_accessor :tainted

# 	def initialize(tainted)
# 		@tainted = tainted
# 	end

# 	private

# 	simple_methods = ["capitalize", "center", "chomp", "chop", 
# 		"crypt", "delete", "downcase", "dump", 
# 		"element_set", "gsub", "insert", "ljust", 
# 		"lstrip", "modulo", "multiply", "plus", 
# 		"prepend", "reverse", "rjust", "rstrip"]

# 	simple_methods.each do |meth|
# 		define_method("after_#{meth}") do |obj, new_string|
# 			new_string.taint
# 		end
# 	end

# end

# module Kernel
# 	def taint
# 		puts "Hey, what's up"
# 		self.secure_context = SecurityManager::TaintedContext if not tainted?
# 		self
# 	end

# 	def tainted?
# 		if not secure_context?
# 			return false
# 		end

# 		self.secure_context == SecurityManager::TaintedContext
# 	end

# 	def untaint
# 		self.secure_context = SecurityManager::UntaintedContext
# 		self
# 	end

# 	module SecurityManager
# 		TaintedContext = TaintSecureContext.new(tainted=true)
# 		UntaintedContext = TaintSecureContext.new(tainted=false)
# 	end
# end

# module Rubinius
# 	module Type
# 		# class << self
# 		# 	alias_method :old_infect, :infect

# 		# 	def infect(host, source)
# 		# 		# puts "calling old infect host: #{sourcsource | #{}"
# 		# 		# puts source == source
# 		# 		# if source.trusted?
# 		# 		# 	puts "true"
# 		# 		# end
# 		# 		# puts old_infect(host, source)
# 		# 		old_infect(host, source)
# 		# 		# puts "\t>> #{host} | #{source}"
# 		# 	end

# 		# end
# 		def self.infect(host, source)
# 			# puts "infect(host : #{host}, source : #{source})"
# 			# if source.tainted?
# 			# 	host.taint
# 			# 	return
# 			# end
# 			# return source
# 		end
# 	end
# end

describe "Taint context" do
	it "works" do
		x = "hello, world"

		x.secure_context?.should == false

		x.taint

		x.secure_context?.should == true
		x.tainted?.should == true

		y = "rawr"

		y.tainted?.should == false

		y = x.upcase

		y.tainted?.should == true

		y.untaint

		y.tainted?.should == false

		z = y.upcase

		z.tainted?.should == false

		z.taint

		z.tainted?.should == true

		y = z.downcase

		y.tainted?.should == true
	end

	it "works both ways with arrays" do
		x = "hello"
		y = ", world"

		y.taint

		x << y

		x.tainted?.should == true
	end
	
end
