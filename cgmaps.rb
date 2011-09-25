require 'rubygems'
require 'net/http'
require 'RMagick'
require 'mapper'
raise 'You need to install jp2a! See http://jp2a.sf.net' if `command -v jp2a &>/dev/null`.empty?

def map_url(opts={}, with_host=false, with_path=true)
  u  = with_host ? 'http://maps.googleapis.com' : '' 
  u += '/maps/api/staticmap?' if with_path
  u += opts.reduce(''){|s,e| s+"#{e[0]}="+[e[1]].join("&#{e[0]}=")+'&'}
end

def download_map(opts={}, filename='map.png')
  Net::HTTP.start('maps.googleapis.com') do |http|
    resp = http.get(map_url(opts))
    open(filename,'wb'){ |f| f.write resp.body }
  end
end

def find_markers(img)
  magenta      = Magick::Pixel.new(0xFFFF,0x0000,0xFFFF)
  outer_pixels = [[1,1],[5,1],[1,6],[5,6],[2,7],[4,7],[3,9],[3,11]]
  inner_pixels = [[1,2],[2,1],[4,1],[5,2],[1,4],[2,5],[4,5],[5,4],[3,3],[3,6],[3,7]]
  offset       = [3,11]
  markers      = []
  (0..img.rows).each{ |y|
    (0..img.columns).each{ |x|
      markers << [x+offset[0], y+offset[1]] if !(
        inner_pixels.any?{ |p| img.pixel_color(x+p[0],y+p[1]) != magenta } ||
        outer_pixels.any?{ |p| img.pixel_color(x+p[0],y+p[1]) == magenta } )
    }
  }
  markers
end
  
def draw_circle(img, cx, cy, radius=10, color='#ff0000')
  gc = Magick::Draw.new
  gc.fill color
  gc.circle cx, cy, cx+radius, cy+radius
  gc.draw img
end

#cologne
lat1=50.941582
lon1=6.958497
#munich
lat2=48.119126
lon2=11.560186

map_opts = {
  :center  => 'Germany',
  :zoom    => '6',
  :size    => '640x640',
  :maptype => 'roadmap', #roadmap, satellite, hybrid, terrain
  :format  => 'png',
  :sensor  => 'false',
  :style   => [
    'feature:all|visibility:off',
    'feature:administrative.country|saturation:100|hue:#FF0000|visibility:simplified',
    'feature:water|visibility:simplified'
  ],
  :markers => "size:tiny|color:0xFF00FF|#{lat1},#{lon1}|#{lat2},#{lon2}"
}

show_status = true

puts 'Downloading map' if show_status
download_map map_opts

puts 'Reading map' if show_status
img = Magick::Image::read('map.png').first

puts 'Searching special markers on map' if show_status
markers = find_markers(img)

puts 'Calculating projection' if show_status
mapper = Mapper.new({:lat=>lat1,:lon=>lon1,:x=>markers[0][0],:y=>markers[0][1]},
                    {:lat=>lat2,:lon=>lon2,:x=>markers[1][0],:y=>markers[1][1]})

puts 'Drawing a coordinate on the map .. e.g. Berlin' if show_status
c = mapper.get_coords :lat=>52.5166, :lon=>13.4000
draw_circle img, c[:x], c[:y], 20, '#00FF00'

puts 'Saving as temporary jpg' if show_status
img.write('tmp.jpg')

puts 'Displaying ASCII map' if show_status
puts `jp2a --clear --invert --colors tmp.jpg`

