require 'pathname'
require 'bigdecimal'

# Cribbed from Unicorn Worker Killer, thanks!
class GetProcessMem
  KB_TO_BYTE = 1024          # 2**10   = 1024
  MB_TO_BYTE = 1_048_576     # 1024**2 = 1_048_576
  GB_TO_BYTE = 1_073_741_824 # 1024**3 = 1_073_741_824
  CONVERSION = { "kb" => KB_TO_BYTE, "mb" => MB_TO_BYTE, "gb" => GB_TO_BYTE }

  attr_reader :pid, :mem_type

  def initialize(*args)
    options = args.last.is_a?(::Hash) ? args.pop : {}
    @pid    = args.first || Process.pid

    @status_file  = Pathname.new "/proc/#{@pid}/status"
    @linux        = @status_file.exist?
    @mem_type     = (options[:mem_type] || "rss").downcase
  end

  def linux?
    @linux
  end

  def bytes
    memory = (linux? && linux_status_memory)
    memory ||= ps_memory
  end

  def kb(b = bytes)
    (b/BigDecimal.new(KB_TO_BYTE)).to_f
  end

  def mb(b = bytes)
    (b/BigDecimal.new(MB_TO_BYTE)).to_f
  end

  def gb(b = bytes)
    (b/BigDecimal.new(GB_TO_BYTE)).to_f
  end

  def inspect
    b = bytes
    "#<#{self.class}:0x%08x @mb=#{ mb b } @gb=#{ gb b } @kb=#{ kb b } @bytes=#{b}>" % (object_id * 2)
  end

  def mem_type=(mem_type)
    @mem_type = mem_type.downcase
  end

  # linux stores memory info in a file "/proc/#{pid}/status"
  # If it's available it uses less resources than shelling out to ps
  def linux_status_memory(file = @status_file)
    line = file.each_line.find { |l|
      match_line = l.downcase
      match_line.start_with?(self.mem_type).freeze || match_line.start_with?("vm#{self.mem_type}").freeze
    }
    return unless line
    return unless (_name, value, unit = line.split(nil)).length == 3
    CONVERSION[unit.downcase!] * value.to_i
  rescue Errno::EACCES, Errno::ENOENT
  end

  # Pull memory from `ps` command, takes more resources and can freeze
  # in low memory situations
  def ps_memory
    KB_TO_BYTE * BigDecimal.new(`ps -o #{self.mem_type}= -p #{self.pid}`)
  end

end
