require 'ostruct'
module HashToOpenstruct
  def to_ostruct
    o = OpenStruct.new(self)
    each.with_object(o) do |(k,v), o|
      o.send(:"#{k}=", v.to_ostruct) if v.respond_to? :to_ostruct
    end
    o
  end
end

Hash.send(:include, HashToOpenstruct)
