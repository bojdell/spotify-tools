#!/usr/bin/env ruby

require_relative 'lib/spotify_auth/base_auth.rb'

PLAYLIST_NAME = "Recently Added"

def find_playlist(user, playlist_name, offset = 0, limit = 50)
  playlists = user.playlists(limit: limit, offset: offset)

  detected = playlists.detect { |p| p.name == PLAYLIST_NAME }
  if !detected.nil? && playlists.length == limit
    find_playlist(user, playlist_name, offset + limit)
  else
    detected
  end
end

@logger = Logger.new(STDOUT)
USER_ID = `security find-generic-password -s 'spotify-tools-user-id'  -w 2>/dev/null`.chomp

user = Spotify.spotify_user(USER_ID)
playlist = find_playlist(user, PLAYLIST_NAME)

if playlist.nil?
  @logger.info("Did not find any playlists named '#{PLAYLIST_NAME}' for user #{USER_ID}, creating a new playlist called '#{PLAYLIST_NAME}'")
  playlist = user.create_playlist!(PLAYLIST_NAME) # TODO: how to get public: false to work when searching?
else
  @logger.info("Playlist '#{PLAYLIST_NAME}' already exists for user #{USER_ID}, will not re-create.")
end

desired_tracks = user.saved_tracks(limit: 50)
existing_tracks = playlist.tracks

tracks_to_remove = existing_tracks - existing_tracks
tracks_to_add = desired_tracks - existing_tracks

@logger.info("Found #{tracks_to_remove.length} extra tracks in '#{PLAYLIST_NAME}'")
@logger.info("Found #{tracks_to_add.length} missing tracks in '#{PLAYLIST_NAME}'")
@logger.info("Updating '#{PLAYLIST_NAME}'...")

unless tracks_to_remove.empty?
  playlist.remove_tracks!(tracks_to_remove)
end
unless tracks_to_add.empty?
  playlist.add_tracks!(tracks_to_add)
end

@logger.info("Succesfully updated '#{PLAYLIST_NAME}' for user #{USER_ID}")
