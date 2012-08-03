require 'pp'
require 'facter'

array_counter = 0
ld_counter = 0
pd_counter = 0

def clean_fact(fact)
  fact.gsub!(" ", "_")
  fact.downcase!
  fact.sub(/smart_array_.*?_in_slot_[0-9]+_\(embedded\)/) {|match| return "hparray#{match.scan(/[0-9]+/).last}"}
  fact.sub(/array:_./) { |match| id = match.slice!(-1); return "array#{id-97}" }
  fact.sub(/logical_drive:_./) { |match| id = match.slice(-1); return "ld#{id-49}" }
  fact
end

def path(h, path = [] )
  cohort = get_siblings(h)
  cohort.each do |key|
    if h[key].kind_of?(Hash)
      h[key].each do |k,v|
        if v.kind_of?(Hash)
          path << key
          path(h[key], path)
          return path
        elsif v.kind_of?(String)
          terminal_path = path.dup << key
          terminal_path << k
          terminal_path = terminal_path.join('_')
          ## insert facts into facter
          # Facter.add(terminal_path) do setcode do v end end
          ## print facts to stdout
          # pp "#{terminal_path} => #{v}"
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

p=%x{cat /modules/examples/controller400i.txt}
p_array, p_hash = [], {}
$pd_array = []
p.each {|line| p_array << [line.chomp.lstrip, line =~ /\S/]}
p_array.reject! { |line| line[0] == "" }
hash_stack = [p_hash]
(0..p_array.length).each do |i|
  if i < p_array.length-1
    new_key = clean_fact(p_array[i][0].split(/:/).first)
    new_value = p_array[i][0].split(/:/).last.squeeze(" ").strip
    if clean_fact(p_array[i][0].split(/:/).first) =~ /physicaldrive/
      $pd_array << p_array[i][0].split(/\s/).last
    end

    if p_array[i+1][1] > p_array[i][1]
      hash_new = {}
      hash_stack[-1][clean_fact(p_array[i][0])] = hash_new
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
pp $pd_array.sort

hash_stack = hash_stack.first
path(hash_stack)
