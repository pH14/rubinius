#puts "#{'hello'}#{', world'.taint}".tainted?
puts (("a".taint)..."c").to_s.tainted?
puts (("a".taint)..."c").to_s

class Range
  attr_reader :begin
  attr_reader :end

  def initialize(first, last)
    @begin = first
    @end = last
  end

  def to_s
    "#{@begin}...#{@end}"
  end
end

x = Range.new 'a'.taint, 'c'
#puts x.to_s.tainted?
