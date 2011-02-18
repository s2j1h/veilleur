require 'sinatra'
require 'dm-core'
require 'appengine-apis/urlfetch'
require 'appengine-apis/users'

# Configure DataMapper to use the App Engine datastore 
DataMapper.setup(:default, "appengine://auto")

# Create your model class
class Test
  include DataMapper::Resource
  property :id,     Serial
  property :url,    String
  property :user,   User
  
  has n, :results
  has n, :archives
end

class Result
  include DataMapper::Resource
  property :id,     Serial
  property :date,   Time
  property :value,  Float
    
  belongs_to :test, :child_key => [:test_id]  # defaults to :required => true
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

  belongs_to :test, :child_key => [:test_id]  # defaults to :required => true
end


# Make sure our template can use <%=h
helpers do
  include Rack::Utils
  alias_method :h, :escape_html
end

get '/' do
  user = AppEngine::Users.current_user
  if user
    tests = Test.all(:user => user)
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
        @array[line][archive.date] = archive
      end
      line = line + 1
    end
    
    erb :index
  else
    redirect AppEngine::Users.create_login_url('/') 
  end
end

#display new form
get '/new' do
  user = AppEngine::Users.current_user
  if user
    erb :new
  else
    redirect AppEngine::Users.create_login_url('/') 
  end  
end

#add a new test
post '/new' do
  user = AppEngine::Users.current_user
  if user
    if params[:url] != nil and params[:url] != ""
      test = Test.create(:url => params[:url], :user => user)
      redirect '/'
    end  
  else
    redirect AppEngine::Users.create_login_url('/') 
  end 
end

#delete tests
get '/:id/delete' do
  test = Test.get(params[:id])
  test.results.destroy
  test.archives.destroy
  test.destroy
  redirect '/'
end


def archives(value,date,test,type)
  if type == "day"
    todayB = Time.local(date.year,date.month,date.day) #00:00
  elsif type == "week"
    todayB = Time.local(date.year,date.month,date.day) #00:00
    todayB = todayB - (6-todayB.wday)*86400 # Always on sundy    
  end
  archive = test.archives.first(:date => todayB, :type => type)
  if archive != nil
    max,min,mean,uptime,nbValues = archive.max,archive.min,archive.mean,archive.uptime,archive.nbValues
    if archive.uptime == 0 and nbValues > 0 #first measures were KO
      #no change but nb of values
      nbValues = nbValues + 1
    else
      if value > 0 #OK
        if value > max
          max = value
        end
        if value < min
          min = value
        end
        #uptime = nbvalues OK
        mean = (mean*uptime + value) / (uptime+1)
        uptime = uptime + 1
        nbValues = nbValues + 1
      else #KO
        nbValues = nbValues + 1
      end
    end
    archive.update(:max => max, :min => min, :mean => mean, :uptime => uptime, :nbValues => nbValues)
  else #First Measure
    max,min,mean,uptime,nbValues = 0,0,0,0,0
    if value == -1 #KO
      nbValues = 1
    else #OK
      max,min,mean,uptime,nbValues = value,value,value,1,1
    end
    test.archives.create(:type => type,:date => todayB,:max => max, :min => min, :mean => mean, :uptime => uptime, :nbValues => nbValues)  
  end
  
  
end

get '/:id/view/:type' do
  user = AppEngine::Users.current_user
  if user    
    @test = Test.first(:id => params[:id], :user => user)
    if @test
      if params[:type] == "day"
        todayL = Time.new
        todayB = Time.local(todayL.year,todayL.month,todayL.day) #00:00
        @results = @test.results.all(:date.gte => todayB,:date.lte => todayL,:order => [:date.asc])
        @type = "day" #display graph by hour/day
      elsif params[:type] == "week"
        today = Time.now
        todayL = Time.local(today.year,today.month,today.day) #00:00
        todayB = todayL - 604800
        @results = @test.archives.all(:type => "day",:date.gte => todayB,:date.lte => todayL,:order => [:date.asc])
        @type = "week" #display graph by hour/day
      elsif params[:type] == "month"
        today = Time.now
        todayL = Time.local(today.year,today.month,today.day) #00:00
        todayB = todayL - 2678400
        @results = @test.archives.all(:type => "day",:date.gte => todayB,:date.lte => todayL,:order => [:date.asc])
        @type = "month" #display graph by month
      else
        today = Time.now
        todayL = Time.local(today.year,today.month,today.day) #00:00
        todayB = Time.local(today.year,1,1)
        @results = @test.archives.all(:type => "week",:date.gte => todayB,:date.lte => todayL,:order => [:date.asc])
        @type = "year" #display graph by hour/day
      end
      erb :list
    else      
      redirect '/'
    end
  else
    redirect AppEngine::Users.create_login_url('/') 
  end
end

get '/logout' do
  redirect AppEngine::Users.create_logout_url('/') 
end

get '/go' do
  tests = Test.all
  tests.each do |test|
    date, value = Time.new, 0
    begin
      url = test.url            
      AppEngine::URLFetch.fetch(url, :method => 'GET')
      after = Time.new
      value = after - date
      test.results.create(:value => value,:date => date)
    rescue
      value = -1
      test.results.create(:value => value,:date => date)         
    end
    archives(value,date,test,"day")
    archives(value,date,test,"week")
  end
  return "Done"  
end