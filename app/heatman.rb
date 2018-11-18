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

require 'chronic_between'
require 'RRD'
require 'json'

# Sinatra helper for Heatman
module Heatman
	# Store timestamp of lastest state change for each channel
	@@timestamps = Hash.new(0)

	def sanitize_channel!(channel)
		if not settings.channels.has_key?(channel)
			raise Forbidden, "Channel not allowed"
		end
	end

	def sanitize_mode!(channel, mode)
		if not settings.channels[channel]['modes'].include? mode
			raise InternalError, "Unknown mode #{mode}"
		end
	end

	def sanitize_sensor!(sensor)
		if not settings.sensors.has_key?(sensor)
			raise Forbidden, "Sensor not allowed"
		end
	end

	def switch(channel, mode)
		sanitize_mode!(channel, mode)
		if get_current_mode(channel) != mode
			logger.info "Mode changed to #{mode} for channel #{channel}"
			apply(channel, mode)
			@@timestamps[channel] = Time.now.to_i
			status 200
		else
			status 204
		end
	end

	def apply(channel, action)
		cmd = settings.channels[channel]['command']

		output = `#{cmd} #{action}`
		if not $?.success?
			raise InternalError, "External script failed : exitcode #{$?.exitstatus} from #{cmd}"
		end

		output
	end

	def get_current_mode(channel)
		mode=apply(channel, "status").strip
		sanitize_mode!(channel, mode)
		return mode
	end

	def get_last_change(channel)
		return @@timestamps[channel]
	end

	def get_scheduled_mode(channel)
		settings.channels[channel]['schedules'].each do |mode, schedule|
			if ChronicBetween.new(schedule).within? DateTime.now
				return mode
			end
		end

		# default
		return settings.channels[channel]["default"]
	end

	def get_sensor_value(sensor)
		options=settings.sensors[sensor]

		if options.has_key?("rrd")
			# Get value from RRD file
			begin
				value = RRD.info(options['rrd'])["ds[#{options['dsname']}].last_ds"]
				if value.nil?
					raise InternalError, "Bad RRD dsname for #{options['rrd']}: #{options['dsname']}"
				end
			rescue Exception => e
				raise InternalError, "Can't read RRD value: #{e}"
			end

			return value
		elsif options.has_key?("command")
			# Get value from script
			output = `#{options['command']}`
			if not $?.success?
				raise InternalError, "External script failed : exitcode #{$?.exitstatus} from #{options['command']}"
			end

			return output.strip
		else
			raise InternalError, "No data source found for #{sensor}"
		end

	end

	def save(filename, data)
		begin
			Dir.mkdir(settings.datadir) unless File.directory?(settings.datadir)

			File.open(File.join(settings.datadir, filename), 'w') do |f| 
				f.write(data.to_json)
			end
		rescue StandardError => e
			logger.error "Can't save #{filename}: #{e}"
		end
	end

	def load(filename)
		logger.info "Loading #{filename}"
		begin
			data=JSON.parse(File.read(File.join(settings.datadir, filename)), :symbolize_names => true)
		rescue StandardError => e
			logger.warn "Can't load #{filename}: #{e}, using empty values."
			data=Hash.new
		end
		
		# Expand time string with time object
		deep_replace!(data, :time) {|v| Time.parse(v) }
		return data
	end

	def save_overrides(overrides)
		save("overrides.json", overrides)	
	end
	
	def save_schedules(schedules)
		save("schedules.json", schedules)
	end

	def load_overrides()
		# Overrides' primary key are strings, everything else is symbol
		load("overrides.json").stringify_keys
	end

	def load_schedules()
		load("schedules.json")
	end

	# Replace the value of the given key by the block's return value
	# Apply to all nested hash
	def deep_replace!(hash, key, &block)
		hash.each_pair do |k,v|
			if k.eql?(key)
				hash[key] = block.call v
			elsif v.is_a?(Hash)
				deep_replace!(v, key, &block)
			end
		end
	end

	# Customs exceptions
	class Forbidden < StandardError
	end

	class InternalError < StandardError
	end
end

# Active record import
class Hash
  def stringify_keys
    inject({}) do |options, (key, value)|
      options[key.to_s] = value
      options
    end
  end
end

# vim: ts=4:sw=4:ai:noet
