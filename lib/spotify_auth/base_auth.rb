require 'rspotify'
require 'pry'
require 'webrick'

require_relative 'oauth.rb'

module Spotify
  @spotify_user = nil

  def self.spotify_user(user_id)
    if @spotify_user.nil?
      # initialize spotify client
      RSpotify.authenticate(OAuth::CLIENT_ID, OAuth::APP_SECRET)

      creds = OAuth.perform_oauth(user_id)
      
      user_hash = RSpotify::User.find(user_id).to_hash
      merged_hash = user_hash.merge(creds)
      @spotify_user = RSpotify::User.new(merged_hash)
    end
    @spotify_user
  end
end
