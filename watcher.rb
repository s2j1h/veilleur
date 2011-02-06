require 'sinatra'
require 'dm-core'
require 'appengine-apis/urlfetch'


# Make sure our template can use <%=h
helpers do
  include Rack::Utils
  alias_method :h, :escape_html
end

get '/' do  
  erb :index
end

get '/go' do
  url = "http://veilleur.zeneffy.fr/go"  
  AppEngine::URLFetch.fetch(url, :method => 'GET')
  return "done"
end

__END__

@@ index
<html>
  <head>
    <title>Veilleur-URL</title>
  </head>
  <body style="font-family: sans-serif;">

  </body>
</html>