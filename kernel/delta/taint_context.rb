class TaintContext# < BasicObject
	attr_accessor :tainted

	# How to best manage aliased methods? E.g. [] vs slice

	@@simple_methods = 	
			["b", 
			"byteslice",
			"capitalize", "center", "chomp", "chop", 
			"clone",
			"crypt", "delete", "downcase", "dump", 
			"dup",
			"each", # from array
			"element_set", 
			"encode",
			"find_character",
			"find_string",
			"find_string_reverse",
			"gsub", "insert", "ljust", 
			"lstrip", "modulo", "multiply", "plus",
			"prepend", "reverse", "rjust", "rstrip", 
			"slice", 
			"slice!",
			"split",
			"squeeze",
			"strip", "lstrip", "rstrip",
			"sub",
			"substring",
			"succ", "next",
			"swapcase",
			"tr", "tr_s",
			"transform",
			"upcase",

			"search_region",

			# regexp methods
			# "captures",
			# "pre_match",
			# "pre_match_from",
			# "post_match",
		]

	@@operator_methods = ["multiply", "plus", "index", "modulo"]

	def initialize(tainted)
		@tainted = tainted

		if @tainted
			@@simple_methods.each do |meth|
				define_singleton_method("after_#{meth}") do |obj, new_string|
					new_string.taint if not new_string.nil? and not new_string.frozen?
				end
			end

			@@operator_methods.each do |meth|
				define_singleton_method("after_op__#{meth}") do |obj, new_string|
					new_string.taint if not new_string.nil? and not new_string.frozen?
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
