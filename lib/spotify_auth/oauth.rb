require 'net/http'
require 'uri'
require 'cgi'
require 'securerandom'
require 'launchy'
require 'json'

module OAuth
  extend self
  CLIENT_ID  = ENV['SPOTIFY_CLIENT_ID']  || `security find-generic-password -s 'spotify-tools-client-id'  -w 2>/dev/null`.chomp
  APP_SECRET = ENV['SPOTIFY_APP_SECRET'] || `security find-generic-password -s 'spotify-tools-app-secret' -w 2>/dev/null`.chomp
  CREDENTIALS_SNAPSHOT = {'credentials' => nil}
  PORT = 8000
  ROOT_URI = "http://localhost:#{PORT}"
  REDIRECT_URI = "#{ROOT_URI}/callback"
  SCOPES = 'playlist-modify-public playlist-modify-private user-library-read'

  @logger = Logger.new(STDOUT)
  @response = nil

  def perform_oauth(user_id)
    if !CREDENTIALS_SNAPSHOT['credentials'].nil?
      @logger.info("Detected cached access token for user: #{user_id}")
      return CREDENTIALS_SNAPSHOT
    end
    @logger.info("Performing OAuth for user: #{user_id}")
    
    root = File.expand_path './oauth-public'
    server = WEBrick::HTTPServer.new :Port => PORT, :DocumentRoot => root

    server.mount_proc '/' do |req, res|
      perform_callback(req, res)
      binding.pry
    end

    server.mount_proc '/callback' do |req, res|
      res_uri = res.request_uri
      res_params = CGI.parse(res_uri.query)
      uri = URI.parse('https://accounts.spotify.com/api/token')
      params = {
        'grant_type' => 'authorization_code',
        'code' => res_params['code'],
        'redirect_uri' => REDIRECT_URI,
        'client_id' => CLIENT_ID,
        'client_secret' => APP_SECRET
      }
      res2 = Net::HTTP.post_form(uri, params)
      res2_json = JSON.parse(res2.body)
      @response = res2_json
    end

    # start server
    trap('INT') { server.shutdown; @response = 'done' }
    server_thread = Thread.new do
      server.start
    end

    # open web browser for auth
    Launchy.open(ROOT_URI)

    # wait for response
    while @response.nil?
      sleep(0.3)
    end

    server.shutdown
    server_thread.join
    
    
    CREDENTIALS_SNAPSHOT['credentials'] = @response
    
    CREDENTIALS_SNAPSHOT # TODO: validate state
  end

  def perform_callback(req, res)
    # generate initial auth uri
    state = SecureRandom.uuid
    uri_str = get_auth_uri(CLIENT_ID, REDIRECT_URI, SCOPES, state)
    uri = URI.parse(uri_str)

    # redirect to Spotify auth
    res.set_redirect(WEBrick::HTTPStatus::TemporaryRedirect, uri)
  end

  def get_auth_uri(client_id, redirect_uri, scopes, state)
    params = [
      ['client_id', client_id],
      ['response_type', 'code'],
      ['redirect_uri', redirect_uri],
      ['scope', scopes],
      ['state', state]
    ]
    encoded_params = params.map { |k, v| k + '=' + CGI::escape(v.to_s) }.join('&')

    "https://accounts.spotify.com/authorize?#{encoded_params}"
  end
end
