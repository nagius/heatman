#!/usr/bin/env ruby

# This script is desiged to connect a Neotrellis keypad to Heatman
# See https://github.com/nagius/neotrellis for more information
# It needs to be run as a daemon on the same machine than heatman (uses UNIX socket)

require 'neotrellis'
require 'net_x/http_unix' # gem install net_http_unix
require 'json'
require 'fiddle'

class Pad

	HOST = 'unix:///var/run/thin/heatman.0.sock'
	URL = '/api/channel/'
	DEBOUNCE = 200 # ms

	def initialize
		seesaw = Neotrellis::Seesaw.new(device: "/dev/i2c-2", addr: 0x2E)
		@keypad = Neotrellis::Keypad.new(seesaw, interrupt_pin: 22)
		@pixels = Neotrellis::Neopixel.new(seesaw, brightness: 0.3)

		@mode = :standby
		@timestamp = 0

		@lines = ['living' ,'bedroom2', 'bedroom1', 'bathroom']
		@columns = ['on', 'eco', 'off', 'auto']

		libc = Fiddle.dlopen('/lib/arm-linux-gnueabihf/libc.so.6')
		@alarm = Fiddle::Function.new(libc['alarm'], [Fiddle::TYPE_INT], Fiddle::TYPE_INT)

		@pixels.fill_random
		alarm(3)

		Thread.abort_on_exception = true

		trap('ALRM') do
			Thread.new do
				@pixels.off
				@mode = :standby
			end
		end

		Neotrellis::Neopixel::DEFAULT_PIXEL_NUMBER.times do |key|
			@keypad.set_event(key, event: Neotrellis::Keypad::KEY_PRESSED) do |event|
				if !debounce
					Thread.new do
						process_event(event.key, event.edge)
					end
				end
			end
		end
		@keypad.wait_for_event
	end

	def alarm(delay)
		@alarm.call(delay)
	end

	def update_channel(channel)
			x = @lines.find_index(channel)
			begin
				res = get(URL + channel)
				raise unless res.code == '200'
				body = JSON.parse(res.body)

				@columns.size.times { |y|
					@pixels.set((x*4)+y, Neotrellis::Neopixel::OFF)
				}

				case body['mode']
				when 'on'
					@pixels.set(x*4, Neotrellis::Neopixel::BLUE)
				when 'eco'
					@pixels.set((x*4)+1, Neotrellis::Neopixel::BLUE)
				when 'off'
					@pixels.set((x*4)+2, Neotrellis::Neopixel::BLUE)
				end
				@pixels.set((x*4)+3, Neotrellis::Neopixel::BLUE) unless body['override']
			rescue  StandardError => e  
				@columns.size.times { |y|
					@pixels.set((x*4)+y, Neotrellis::Neopixel::RED)
				}
			end
			@pixels.show
	end

	def update_status
		@pixels.autoshow = false

		threads = []
		@lines.each { |channel|
			threads << Thread.new do
				update_channel(channel)
			end
		}
		threads.each { |thr| thr.join }
	
		@pixels.autoshow = true
	end

	def process_event(key, edge)
		case @mode
		when :standby
			# Get current status
			@pixels.fill(Neotrellis::Neopixel::GREEN)

			update_status

			@mode = :select
			alarm(6) 
		when :select
			@pixels.set(key, Neotrellis::Neopixel::YELLOW)

			# Apply change
			channel = @lines[key / 4]
			mode = @columns[key % 4]

			begin
				res = post(URL + channel + '/' + mode)
			rescue  StandardError => e  
				@pixels.set(key, Neotrellis::Neopixel::RED)
			end

			update_channel(channel)

			alarm(6)
		else
			# Error
			@pixels.set(key, Neotrellis::Neopixel::RED)
			alarm(2)
		end
	end

	private

	def get(url)
		http = NetX::HTTPUnix.new(HOST)
		http.open_timeout = 5
		http.read_timeout = 5

		http.request(NetX::HTTPUnix::Get.new(url))
	end

	def post(url)
		http = NetX::HTTPUnix.new(HOST)
		http.open_timeout = 5
		http.read_timeout = 5

		http.request(NetX::HTTPUnix::Post.new(url))
	end

	def debounce
		now = (Time.now.to_f * 1000).to_i

		# Discard event if too soon
		debounce = (now - @timestamp) <= DEBOUNCE
		@timestamp = now
		debounce
	end
end

Pad.new

# vim: ts=4:sw=4:ai
