require "erb"
require "nokogiri"

# Parse the XML file
doc = File.open(ARGV[0]) { |f| Nokogiri::XML(f) }
placemarks = doc.xpath("//xmlns:Placemark")
points = placemarks.map do |placemark|
  placemark.children.select { |child| child.name == "Point" }.map do |point|
    point.children.select { |child| child.name == "coordinates" }.first.content
  end
end.flatten
coordinates = points.map { |point| point.split(",").map(&:to_f) }
puts "Before:\t#{coordinates.size}"

# GIS
def earth_distance(lng1, lat1, lng2, lat2)
  rad_lng1 = lng1 * Math::PI / 180
  rad_lat1 = lat1 * Math::PI / 180
  rad_lng2 = lng2 * Math::PI / 180
  rad_lat2 = lat2 * Math::PI / 180
  earth_radius = 6378137
  earth_radius * Math.acos(Math.sin(rad_lat1) * Math.sin(rad_lat2) + Math.cos(rad_lat1) * Math.cos(rad_lat2) * Math.cos(rad_lng2 - rad_lng1))
end

last_coordinate = coordinates.first
fitted_coordinates = []

while coordinates.length > 0
  distance = earth_distance(last_coordinate[0], last_coordinate[1], coordinates[0][0], coordinates[0][1])
  if distance > 50000 # 50km
    fitted_coordinates.push(coordinates[0])
    last_coordinate = coordinates.shift
  elsif distance > 1000 # fit middle point
    coordinates.unshift([(last_coordinate[0] + coordinates[0][0]) / 2.0, (last_coordinate[1] + coordinates[0][1]) / 2.0, (last_coordinate[2] + coordinates[0][2]) / 2.0])
  else
    fitted_coordinates.push(coordinates[0])
    last_coordinate = coordinates.shift
  end
end

puts "After:\t#{fitted_coordinates.size}"

# Write to file
template = ERB.new(File.read("#{__dir__}/output.xml.erb"))
result = template.result(binding)
File.write("#{__dir__}/output.kml", result)
