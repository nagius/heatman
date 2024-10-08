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
require 'rufus/scheduler'
require 'logger'
require_relative 'app/heatman'
require_relative 'app/logs'

class App < Sinatra::Base
	register Sinatra::ConfigFile
	helpers Sinatra::JSON
	helpers Heatman

	# Framework configuration
	configure :production do
		enable :logging
		set :logging, Logger::DEBUG
	end

	configure :development do
		set :show_exceptions, :after_handler
		enable :logging
		set :logging, Logger::DEBUG
	end

	# Application configuration
	config_file "config/config.yml"

	before do
		# Load saved status at startup
		@@overrides ||= load_overrides()
		@@schedules ||= load_schedules()

		# Logging configuration
		logger.formatter = CustomFormatter.new request.env
	end

	# Error handling
	error Heatman::Forbidden do |e|
		halt 405, json(:err => e.message)
	end

	error Heatman::InternalError do |e|
		halt 500, json(:err => e.message)
	end

	# Global variable (to be initialized at first request)
	@@overrides = nil
	@@schedules = nil

	# Setup the timer
	if settings.respond_to? :timer
		Rufus::Scheduler.new.every(settings.timer, :first_in => "1s") do
			call(
				'REQUEST_METHOD' => 'POST',
				'PATH_INFO' => '/api/tictac',
				'rack.input' => StringIO.new,
				'rack.errors' => $stderr
			)
		end
	end

	## Application routes
	
	# Main page
	get '/' do
		erb :index
	end
	
	# Get the list of available channels
	get '/api/channels' do 
		channels = Hash.new
		settings.channels.each do |channel, options|
			# Filter only wanted keys
			channels[channel]=options.select do |k,v|
				%w[label modes].include? k
			end
		end
		json channels
	end

	# Get the current mode
	get '/api/channel/:channel/?' do |channel|
		sanitize_channel!(channel)

		json(
			:mode => get_current_mode(channel),
			:time => get_last_change(channel),
			:override => @@overrides.has_key?(channel),
			:persistent => @@overrides[channel].nil? ? false : @@overrides[channel][:persistent])
	end

	# Reset override
	post '/api/channel/:channel/auto' do |channel|
		sanitize_channel!(channel)

		@@overrides.delete(channel)
		save_overrides(@@overrides)

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
		save_overrides(@@overrides)

		logger.info "Manual override set for channel #{channel} : #{params['persistent'] == "true"?"persistent ":"" }#{mode}"
		switch(channel, mode)
	end

	# Schedule a mode override
	post '/api/channel/:channel/schedule/:mode' do |channel, mode|
		sanitize_channel!(channel)
		if mode != "auto"
			begin
				sanitize_mode!(channel, mode)
			rescue Heatman::InternalError
				raise Heatman::Forbidden, "Mode not allowed"
			end
		end

		# Convert timestamp string to Time object
		time = Time.at(params['timestamp'].to_i)

		# Remember this schedule with a random ID
		@@schedules[rand(36**8).to_s(36).to_sym] = {
			:channel => channel,
			:mode => mode,
			:time => time
		}
		save_schedules(@@schedules)

		logger.info "Scheduled override saved for channel #{channel} : #{mode} at #{time.rfc2822}"
		status 200
	end
	
	# Get the list of current schedules
	get '/api/schedules' do
		# Return nested hash with time as timestamp instead of string
		json Hash[@@schedules.map {|id,sched| [id, Hash[sched.map {|k,v| [k, k.eql?(:time) ? v.to_i : v]}]]}] 
	end

	# Cancel specified schedule
	delete '/api/schedule/:id' do |id|
		id=id.to_sym
		if @@schedules.has_key? id
			logger.info "Scheduled override cancelled for channel #{@@schedules[id][:channel]} : #{@@schedules[id][:mode]} at #{@@schedules[id][:time].rfc2822}"
			@@schedules.delete(id)
			save_schedules(@@schedules)
		end

		status 204
	end

	# Route used by the timer (crontab)
	post '/api/tictac' do
		# Execute scheduled overrides
		@@schedules.each do |id, schedule|
			if schedule[:time] <= Time.now
				if schedule[:mode] == "auto"
					@@overrides.delete(schedule[:channel])
				else
					@@overrides[schedule[:channel]] = {
						:mode => schedule[:mode],
						:persistent => false
					}
				end

				logger.info "Scheduled override set for channel #{schedule[:channel]} : #{schedule[:mode]}"
				@@schedules.delete(id)

				save_schedules(@@schedules)
				save_overrides(@@overrides)
			end
		end

		# Switch to requested mode
		settings.channels.each do |channel, options|
			begin
				if @@overrides.has_key?(channel)
					if not @@overrides[channel][:persistent] and @@overrides[channel][:mode] == get_scheduled_mode(channel)
						# Reset temporary override
						@@overrides.delete(channel)
						save_overrides(@@overrides)

						logger.info "Manual override expired for channel #{channel}"
						status 200
					else
						# Ensure requested mode is enabled (in case of external modification)
						switch(channel, @@overrides[channel][:mode])
					end
				else
					# Set the scheduled mode only if no override
					switch(channel, get_scheduled_mode(channel))
				end
			rescue Heatman::InternalError => e
				logger.error "Failed to switch channel #{channel}: #{e.message}"
				status 500
			end
		end

		# Clear any body that may be populated by an exception
		body ""
	end

	# Get the list of available sensors 
	get '/api/sensors' do 
		sensors = Hash.new
		settings.sensors.each do |sensor, options|
			# Filter only wanted keys
			sensors[sensor]=options.select do |k,v|
				%w[label unit].include? k
			end
			sensors[sensor][:history]=options.has_key?("rrd")
		end
		json sensors
	end

	# Get the current value of the specified sensor
	get '/api/sensor/:sensor/?' do |sensor|
		sanitize_sensor!(sensor)
		json( :name => sensor, :value => get_sensor_value(sensor) )
	end

end

# vim: ts=4:sw=4:ai:noet
