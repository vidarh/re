unless Comparable.instance_methods.include?(:clamp)
  class Fixnum
    def clamp(min, max)
      return min if self <= min
      return max if self >= max

      self
    end
  end
end

require 'date'

class DateTime
  def to_i
    to_time.to_i
  end
end
