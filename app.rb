require 'sinatra'

get '/' do
  'Minimialist web app'
end

get '/launch' do
  File.read(File.join('public', 'launch.rb'))
end
