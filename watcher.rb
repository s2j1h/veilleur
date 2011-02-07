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
  
  belongs_to :test  # defaults to :required => true
end

class Test
  include DataMapper::Resource
  property :id,     Serial
  property :url,    String
  
  has n, :results
end


# Make sure our template can use <%=h
helpers do
  include Rack::Utils
  alias_method :h, :escape_html
end

get '/' do  
  @tests = Test.all
  erb :index
end

post '/new' do
  # Create a new shout and redirect back to the list.
  test = Test.create(:url => params[:url])
  redirect '/'
end

#delete tests
get '/:id/delete' do
  test = Test.get(params[:id])
  test.results.destroy
  test.destroy
  redirect '/'
end

get '/:id/list' do
  test = Test.get(params[:id])
  @results = test.results.all(:order => [:date.asc])
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