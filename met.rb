#!/usr/bin/env ruby
# -*- coding: binary -*-

require 'macho'

stager_file = ARGV[0]
data = File.binread(stager_file)
macho = MachO::MachOFile.new_from_bin(data)
main_func = macho[:LC_MAIN].first
entry_offset = main_func.entryoff

start = -1
min = -1
max = 0
for segment in macho.segments
  next if segment.segname == MachO::LoadCommands::SEGMENT_NAMES[:SEG_PAGEZERO]
  puts "segment: #{segment.segname} #{segment.vmaddr.to_s(16)}"
  if min == -1 or min > segment.vmaddr
    min = segment.vmaddr
  end
  if max < segment.vmaddr + segment.vmsize
    max = segment.vmaddr + segment.vmsize
  end
end

puts "data: #{min.to_s(16)} -> #{max.to_s(16)} #{(max - min).to_s(16)}"
output_data = "\x00" * (max - min)

for segment in macho.segments
  next if segment.segname == MachO::LoadCommands::SEGMENT_NAMES[:SEG_PAGEZERO]
  puts "segment: #{segment.segname} off: #{segment.offset.to_s(16)} vmaddr: #{segment.vmaddr.to_s(16)} fileoff: #{segment.fileoff.to_s(16)}"
  for section in segment.sections
    puts "section: #{section.sectname} off: #{section.offset.to_s(16)} addr: #{section.addr.to_s(16)} size: #{section.size.to_s(16)}"
    flat_addr = section.addr - min
    section_data = data[section.offset, section.size]
    puts "flat_addr: #{flat_addr.to_s(16)}"
    #file_section = section.offset
    #puts "info: #{segment.fileoff.to_s(16)} #{segment.offset.to_s(16)} #{section.size.to_s(16)} #{file_section.to_s(16)}"
    #puts "?: #{data.size.to_s(16)} #{file_section.to_s(16)}"
    if section_data
      if start == -1 or start > flat_addr
        start = flat_addr
      end
      output_data[flat_addr, section_data.size] = section_data
    end
  end
end

puts "start: #{start.to_s(16)}"
output_data = output_data[start..-1]
File.binwrite(stager_file + ".bin", output_data)

