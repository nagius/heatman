#
# Heatman - Heat manager system
# Copyleft 2014 - Nicolas AGIUS <nicolas.agius@lps-it.fr>
#
###########################################################################
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


require 'sinatra'
require 'sinatra/config_file'
require 'sinatra/assetpack'


class App < Sinatra::Base
	register Sinatra::AssetPack
	register Sinatra::ConfigFile

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

	# TODO use a POST instead
	get '/switch/:mode' do |mode|
		if %w(on off eco).include? mode
			if not system("#{settings.pilot_cmd} #{mode}")
				halt 500, "Pilot script failed"
			end
		else
			halt 405, "Method not allowed"
		end
	end

	# Get the current status
	get '/switch/?' do
		# TODO build a nice function with JSON output and error message from the command
		status=`#{settings.pilot_cmd} status`
		if $?.exitstatus != 0
			halt 500, "Pilot script failed"
		end
		status
	end

end

# vim: ts=4:sw=4:ai:noet
