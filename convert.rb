require 'csv'

# Converts semi-colon separated values to comma separated values (real csv)

data = CSV.read(ARGV[0], :col_sep => ';', :row_sep => :auto, :encoding => 'utf-8')
CSV.open(ARGV[0], "wb", :encoding => 'utf-8') do |csv|
  data.each do |row|
    new_row = row.map do |cell|
      cell ||= ""
      cell.gsub(',', ';')
      cell.empty? ? nil : cell
    end
    csv << new_row
  end
end

puts "Written #{data.count} rows."