#
# Heatman - Heat manager system
# Copyleft 2014 - Nicolas AGIUS <nicolas.agius@lps-it.fr>
#
###########################################################################
#
# This file is part of Heatman.
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program. If not, see <http://www.gnu.org/licenses/>.
#
###########################################################################


require 'sinatra/base'
require 'sinatra/json'
require 'sinatra/config_file'
require 'sinatra/assetpack'
require_relative 'app/heatman'

class App < Sinatra::Base
	register Sinatra::AssetPack
	register Sinatra::ConfigFile
	helpers Sinatra::JSON
	helpers Heatman

	# Framework configuration
	configure :production, :development do
		set :show_exceptions, :after_handler
		enable :logging
	end

	# Asset pipeline configuration
	assets do
		js :app, [ '/js/*.js' ]

		css :app, [ '/css/*.css' ]

		js_compression  :jsmin    # :jsmin | :yui | :closure | :uglify
		css_compression :simple   # :simple | :sass | :yui | :sqwish
	end 

	# Application configuration
	config_file "config/config.yml"

	# Error handling
	error Heatman::Forbidden do |e|
		halt 405, json(:err => e.message)
	end

	error Heatman::InternalError do |e|
		halt 500, json(:err => e.message)
	end

	# Global variable 
	@@overrides = Hash.new

	get '/' do
		erb :index
	end
	
	# Get list of available channels
	get '/api/channels' do 
		json settings.channels.keys
	end

	# Get the current mode
	get '/api/channel/:channel/?' do |channel|
		sanitize_channel!(channel)

		json(
			:mode => get_current_mode(channel),
			:override => @@overrides.has_key?(channel),
			:persistent => @@overrides[channel].nil? ? false : @@overrides[channel][:persistent])
	end

	# Reset override
	post '/api/channel/:channel/auto' do |channel|
		sanitize_channel!(channel)

		@@overrides.delete(channel)
		logger.info "Manual override deleted for channel #{channel}"
		switch(channel, get_scheduled_mode(channel))
	end

	# Override scheduled mode
	post '/api/channel/:channel/:mode' do |channel, mode|
		sanitize_channel!(channel)
		begin
			sanitize_mode!(channel, mode)
		rescue Heatman::InternalError
			raise Heatman::Forbidden, "Mode not allowed"
		end

		# Remember if we have a manual override
		@@overrides[channel] = {
			:mode => mode,
			:persistent => params['persistent'] == "true"
		}

		logger.info "Manual override set for channel #{channel} : #{params['persistent'] == "true"?"persistent ":"" }#{mode}"
		switch(channel, mode)
	end

	# Route used by the timer (crontab)
	post '/api/tictac' do
		settings.channels.each do |channel, options|
			if @@overrides.has_key?(channel)
				if not @@overrides[channel][:persistent] and @@overrides[channel][:mode] == get_scheduled_mode(channel)
					# Reset temporary override
					@@overrides.delete(channel)
					logger.info "Manual override expired for channel #{channel}"
				end
				status 204
			else
				# Set the scheduled mode only if no override
				switch(channel, get_scheduled_mode(channel))
			end
		end
	end
end

# vim: ts=4:sw=4:ai:noet
