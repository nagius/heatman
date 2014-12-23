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

# Sinatra helper for Heatman
module Heatman

	def halt_if_bad(channel)
		if not settings.channels.has_key?(channel)
			halt 405, "Method not allowed"
		end
	end

	def get_status(channel)
		apply(channel, "status")
	end

	def switch(channel, mode)
		if not settings.channels[channel]['modes'].include? mode
			halt 405, "Method not allowed"
		end

		apply(channel, mode)
	end

	def apply(channel, action)
		# TODO addJSON output and error message from the command

		output = `#{settings.channels[channel]['command']} #{action}`
		if $?.exitstatus != 0
			halt 500, "External script failed"
		end

		output
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
end

# vim: ts=4:sw=4:ai:noet
