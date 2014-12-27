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

	# Global variable 
	@@overrides = Hash.new

	get '/' do
		erb :index
	end
	
	# Get list of available channels
	get '/switch/?' do 
		json settings.channels.keys
	end

	# Get the current mode
	get '/switch/:channel/?' do |channel|
		halt_if_bad(channel)
		get_current_mode(channel)
		# TODO display if overrided
	end

	# Reset override
	post '/switch/:channel/auto' do |channel|
		@@overrides.delete(channel)
		logger.info "Manual override deleted for channel #{channel}"
		status 204
	end

	# Override scheduled mode
	post '/switch/:channel/:mode' do |channel, mode|
		halt_if_bad(channel)

		# Remember if we have a manual override
		@@overrides[channel] = {
			:mode => mode,
			:persistent => params['persistent'] == "true"
		}

		logger.info "Manual override set for channel #{channel} : #{params['persistent'] == "true"?"persistent ":"" }#{mode}"
		switch(channel, mode)
	end

	# Route used by the timer (crontab)
	post '/tictac/' do
		settings.channels.each do |channel, options|
			if @@overrides.has_key?(channel)
				if not @@overrides[channel][:persistent] and @@overrides[channel][:mode] == get_scheduled_mode(channel)
					# Reset temporary override
					@@overrides.delete(channel)
					logger.info "Manual override expired for channel #{channel}"
				end
			else
				# Set the scheduled mode only if no override
				switch(channel, get_scheduled_mode(channel))
			end
		end
		status 204
	end
end

# vim: ts=4:sw=4:ai:noet
