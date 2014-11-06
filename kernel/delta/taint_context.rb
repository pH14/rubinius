class TaintContext < BasicObject
	attr_accessor :tainted

	def initialize(tainted)
		@tainted = tainted

		if @tainted
			["capitalize", "center", "chomp", "chop", 
			"crypt", "delete", "downcase", "dump", 
			"element_set", "gsub", "insert", "ljust", 
			"lstrip", "modulo", "multiply", "plus", "+", "*",
			"prepend", "reverse", "rjust", "rstrip",
			"upcase"].each do |meth|
				::Kernel.puts "Defining method after_#{meth}"
				::Kernel.define_singleton_method("after_#{meth}") do |obj, new_string|
					new_string.taint
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
