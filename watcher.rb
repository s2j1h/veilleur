require 'sinatra'
require 'dm-core'
require 'appengine-apis/urlfetch'

# Configure DataMapper to use the App Engine datastore 
DataMapper.setup(:default, "appengine://auto")

# Create your model class
class Result
  include DataMapper::Resource
  property :id,     Serial
  property :date,   Time
  property :value,  Float
  
  property :test_id,   Integer, :key => true, :min => 1
  belongs_to :test, :key => true  # defaults to :required => true
end

class Test
  include DataMapper::Resource
  property :id,     Serial
  property :url,    String
  
  has n, :results
  has n, :archives
end

class Archive
  include DataMapper::Resource
  property :id,     Serial
  property :type,   String
  property :date,   Time
  property :mean,   Float
  property :max,    Float
  property :min,    Float
  property :uptime, Float
  property :nbValues, Integer
  
  property :test_id,   Integer, :key => true, :min => 1
  belongs_to :test, :key => true  # defaults to :required => true
end

# Make sure our template can use <%=h
helpers do
  include Rack::Utils
  alias_method :h, :escape_html
end

get '/' do
  tests = Test.all
  today = Time.now
  todayL = Time.local(today.year,today.month,today.day) #00:00
  todayB = todayL - 604800
  @array = Array.new(tests.count+1) {Hash.new}
  #fill with dates
  (0..6).each do |i|
    myDate = todayL - (6-i)*86400
    @array[0][myDate] = myDate.strftime("%d/%m")

  end
  line = 1 #line0 = line with dates
  tests.each do |test|
    @array[line]["url"] = test.url
    @array[line]["id"] = test.id
    archives = test.archives.all(:type => "day",:date.gte => todayB,:date.lte => todayL,:order => [:date.asc])
    archives.each do |archive|
      puts "------- #{archive} #{archive.date}"
      @array[line][archive.date] = archive
    end
    line = line + 1
  end

  @array[0].values.each do |day|
    puts "#### #{day}"
  end
  (1..@array.count-1).each do |i| 
    puts "url #{@array[i]["url"]}"
    @array[0].keys.each do |day|
      puts "=>=> #{@array[i][day]}"
    end
    puts "id #{@array[i]["id"]}"
  end
  erb :index
end

#display new form
get '/new' do
  erb :new
end

#add a new test
post '/new' do
  # Create a new shout and redirect back to the list.
  if params[:url] != nil and params[:url] != ""
    test = Test.create(:url => params[:url])
  end  
  redirect '/'
end

#delete tests
get '/:id/delete' do
  test = Test.get(params[:id])
  test.results.destroy
  test.archives.destroy
  test.destroy
  redirect '/'
end

#TODO
def archives(type, dateB, dateL)
end


#in cron tab
get '/archives/day' do
  tests = Test.all
  today = Time.now - 86400 #yesterday
  todayB = Time.local(today.year,today.month,today.day) #00:00
  todayL = Time.local(today.year,today.month,today.day,23,59) #23:59
  tests.each do |test|
    results = test.results.all(:date.gte => todayB,:date.lte => todayL)
    max,min,mean,nb,uptime = 0,0,0,0,0
    results.each do |result|
      value = result.value      
      if value > 0
        mean = mean + value
        if value > max
          max = value
        end
        if value < min
          min = value
        end
        uptime = uptime + 1
      end
      nb = nb+1      
    end
    if nb != 0
      mean = mean / nb
      uptime = uptime / nb
    end
    test.archives.create(:type => "day",:date => todayB,:max => max, :min => min, :mean => mean, :uptime => uptime, :nbValues => nb)
  end    
  return "Done"  
end

get '/:id/list' do
  @test = Test.get(params[:id])
  @results = @test.results.all(:order => [:date.asc])
  erb :list
end


get '/go' do
  tests = Test.all
  tests.each do |test|
    begin
      url = test.url      
      before = Time.new
      AppEngine::URLFetch.fetch(url, :method => 'GET')
      after = Time.new
      test.results.create(:value => (after - before),:date => before)
    rescue
      test.results.create(:value => -1,:date => before)         
    end 
  end
  return "Done"  
end