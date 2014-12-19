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
require 'sinatra/config_file'
require 'sinatra/assetpack'
require_relative 'app/heatman'

class App < Sinatra::Base
	register Sinatra::AssetPack
	register Sinatra::ConfigFile
	helpers Heatman

	# Asset pipeline configuration
	assets do
		js :app, [ '/js/*.js' ]

		css :app, [ '/css/*.css' ]

		js_compression  :jsmin    # :jsmin | :yui | :closure | :uglify
		css_compression :simple   # :simple | :sass | :yui | :sqwish
	end 

	# Application configuration
	config_file "config/config.yml"

	get '/' do
		erb :index
	end

	# TODO use a POST instead (+ param permanent)
	get '/switch/:mode' do |mode|
		switch(mode)
	end

	# Get the current status
	get '/switch/?' do
		get_status()
	end

end

# vim: ts=4:sw=4:ai:noet
