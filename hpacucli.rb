require 'pp'
require 'facter'

def clean_fact(fact)
  fact.gsub!(" ", "_")
  fact.downcase!
  fact.sub(/smart_array_.*?_in_slot_[0-9]+_\(embedded\)/) {|match| return "hparray#{match.scan(/[0-9]+/).last}"}
  fact.sub(/array:_./) { |match| id = match.slice!(-1); return "array#{id-97}" }
  fact.sub(/logical_drive:_./) { |match| id = match.slice(-1);return "ld#{id-49}" }
  fact.sub(/physicaldrive_(\d:\d|\d.:\d:\d)+/) { |match| match = $1;return "pd#{@pd_array.index(match.upcase)}"}
  fact
end

def path(h, f_path = [] )
  cohort = get_siblings(h)
  cohort.each do |key|
    if h[key].kind_of?(Hash)
      h[key].each do |k,v|
        if v.kind_of?(Hash)
          f_path.push(key)
          path(h[key], f_path)
          f_path.pop
        elsif v.kind_of?(String)
          terminal_path = f_path.dup
          terminal_path << key unless terminal_path.include?(key)
          terminal_path << k unless terminal_path.include?(k)
          terminal_path.collect! { |fact| clean_fact(fact.dup)}
          terminal_path = terminal_path.join('_')
          Facter.add(terminal_path) do setcode do v end end
        end
      end
    end
  end
end

def get_siblings(h)
  siblings = []
  h = h.reject{|k,v| !v.kind_of?(Hash)}
  h.each_key {|k| siblings << k }
  siblings.sort
  return siblings
end

if File.exists?("/usr/sbin/hpacucli")

  p = %x{/usr/sbin/hpacucli controller all show config detail}
  p_array, p_hash = [], {}
  @pd_array = []
  p.each{|line| p_array << [line.chomp.lstrip, line =~ /\S/] unless line.match(/^\s+$/)}

  hash_stack = [p_hash]
  (0..p_array.length).each do |i|
    if i < p_array.length-1
      new_key = p_array[i][0].split(/:/).first
      new_value = p_array[i][0].split(/:/).last.squeeze(" ").strip

      if p_array[i][0] =~ /physicaldrive .*$/
        @pd_array << p_array[i][0].split(/\s/).last
      end

      if p_array[i+1][1] > p_array[i][1]
        hash_new = {}
        hash_stack[-1][p_array[i][0]] = hash_new
        hash_stack.push hash_new
      elsif p_array[i+1][1] < p_array[i][1]
        hash_stack[-1][new_key] = new_value
        hash_stack.pop
      elsif p_array[i+1][1] == p_array[i][1]
        hash_stack[-1][new_key] = new_value
      end
    elsif i == p_array.length-1
      hash_stack[-1][new_key] = new_value
    end
  end

  hash_stack = hash_stack.first
  path(hash_stack)
end
